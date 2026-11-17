// MỞ KÉT TIỀN (KiotViet) qua máy in hóa đơn KV804 cắm USB vào laptop — MÃ MỞ KÉT DÙNG 1 LẦN.
//
// Laptop chạy phần mềm "Trạm Mở Két" (repo webquanlychamcong: tools/tram-mo-ket) ở cổng 8787. App gọi
// http://<IP LAN laptop>:8787/open (điện thoại CÙNG wifi với laptop).
// Quy trình:
//  - Quản lý (QL1 / QL2) tạo YÊU CẦU (stores/{id}/cash_drawer_requests, nonce = "<id>.<thời điểm ms>") → thông báo cho Chủ.
//  - Chủ thấy MÃ 6 SỐ = HMAC-SHA256(khóa bí mật của Chủ, nonce) trên app / web → gửi quản lý → quản lý nhập mã.
//  - Laptop tự kiểm tra mã (biết khóa bí mật), mỗi mã mở 1 lần, hết hạn 15 phút. Chủ tự mở không cần nhập mã.
// Khóa bí mật: stores/{id}/owner_private/cash_drawer (chỉ Chủ đọc). Cấu hình chung: stores/{id}/private/cash_drawer.
// Nhật ký: stores/{id}/cash_drawer_logs. Bản web song song: webquanlychamcong lib/cashDrawer.ts.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class CashDrawerConfig {
  final String token;
  final int port;
  final List<String> lanIps;
  final String printer;
  final String computer;

  const CashDrawerConfig({
    required this.token,
    required this.port,
    required this.lanIps,
    required this.printer,
    required this.computer,
  });

  bool get isPaired => token.isNotEmpty;

  factory CashDrawerConfig.fromMap(Map<String, dynamic>? m) {
    final raw = m ?? const <String, dynamic>{};
    final ips = raw['lanIps'];
    return CashDrawerConfig(
      token: raw['token']?.toString() ?? '',
      port: (raw['port'] as num?)?.toInt() ?? CashDrawerService.defaultPort,
      lanIps: ips is List
          ? [for (final e in ips) if (e != null && e.toString().isNotEmpty) e.toString()]
          : (ips is String && ips.isNotEmpty ? [ips] : const []),
      printer: raw['printer']?.toString() ?? '',
      computer: raw['computer']?.toString() ?? '',
    );
  }
}

class CashDrawerRequest {
  final String id;
  final String uid;
  final String name;
  final String reason;
  final String nonce;
  final int createdAtMs;
  final String status; // pending | opened | cancelled

  const CashDrawerRequest({
    required this.id,
    required this.uid,
    required this.name,
    required this.reason,
    required this.nonce,
    required this.createdAtMs,
    required this.status,
  });

  factory CashDrawerRequest.fromMap(String id, Map<String, dynamic> m) => CashDrawerRequest(
        id: id,
        uid: m['uid']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        reason: m['reason']?.toString() ?? '',
        nonce: m['nonce']?.toString() ?? '',
        createdAtMs: (m['createdAtMs'] as num?)?.toInt() ?? 0,
        status: m['status']?.toString() ?? 'pending',
      );

  /// Còn hạn dùng mã (15 phút kể từ lúc tạo)
  bool isAlive([int? nowMs]) =>
      status == 'pending' && (nowMs ?? DateTime.now().millisecondsSinceEpoch) - createdAtMs < CashDrawerService.otpTtlMs;

  int minutesLeft([int? nowMs]) {
    final left = createdAtMs + CashDrawerService.otpTtlMs - (nowMs ?? DateTime.now().millisecondsSinceEpoch);
    return left <= 0 ? 0 : (left / 60000).ceil();
  }
}

class CashDrawerService {
  CashDrawerService({FirebaseFirestore? db, http.Client? client})
      : _db = db,
        _client = client;

  static const int defaultPort = 8787;
  static const int otpTtlMs = 15 * 60 * 1000;
  static const reasons = ['Đổi tiền lẻ', 'Thối tiền cho khách', 'Nộp tiền vào két', 'Kiểm két / giao ca', 'Khác'];

  final FirebaseFirestore? _db;
  final http.Client? _client;
  FirebaseFirestore get _fs => _db ?? FirebaseFirestore.instance;

  // ---------- Logic thuần (có test) ----------

  /// Mã 6 số dùng 1 lần: HMAC-SHA256(khóa = UTF8(secret), dữ liệu = UTF8(nonce)) → 4 byte đầu (big-endian),
  /// bỏ bit dấu, chia dư 1.000.000. Khớp phần mềm trên laptop (Get-Otp) và web (otpFor).
  static String otpFor(String secret, String nonce) {
    final h = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(nonce)).bytes;
    final v = ((h[0] << 24) | (h[1] << 16) | (h[2] << 8) | h[3]) & 0x7fffffff;
    return (v % 1000000).toString().padLeft(6, '0');
  }

  static bool isValidOtp(String otp) => RegExp(r'^\d{6}$').hasMatch(otp);

  /// Địa chỉ phần mềm trên laptop theo IP LAN đã ghép nối
  static List<String> agentUrls(CashDrawerConfig cfg) =>
      {for (final ip in cfg.lanIps) 'http://$ip:${cfg.port}'}.toList();

  static String fullReason(String reason, String note) {
    final n = note.trim();
    if (reason == 'Khác') return n.isEmpty ? 'Khác' : n;
    return n.isEmpty ? reason : '$reason — $n';
  }

  // ---------- Firestore ----------

  DocumentReference<Map<String, dynamic>> _store(String storeId) => _fs.collection('stores').doc(storeId);

  Future<CashDrawerConfig> loadConfig(String storeId) async {
    final snap = await _store(storeId).collection('private').doc('cash_drawer').get();
    return CashDrawerConfig.fromMap(snap.data());
  }

  /// Khóa bí mật (chỉ Chủ đọc được). null = chưa ghép nối / không có quyền
  Future<String?> loadOwnerSecret(String storeId) async {
    try {
      final snap = await _store(storeId).collection('owner_private').doc('cash_drawer').get();
      final v = snap.data()?['secret'];
      return v is String && v.isNotEmpty ? v : null;
    } catch (_) {
      return null;
    }
  }

  Stream<List<CashDrawerRequest>> watchRequests(String storeId) => _store(storeId)
      .collection('cash_drawer_requests')
      .orderBy('createdAtMs', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => [for (final d in s.docs) CashDrawerRequest.fromMap(d.id, d.data())]);

  /// Tạo yêu cầu mở két. Quản lý: kèm thông báo cho Chủ (thông báo KHÔNG chứa mã)
  Future<CashDrawerRequest> createRequest(
    String storeId, {
    required String uid,
    required String name,
    required String role,
    required String reason,
    required bool notifyOwner,
  }) async {
    final ref = _store(storeId).collection('cash_drawer_requests').doc();
    final createdAtMs = DateTime.now().millisecondsSinceEpoch;
    final nonce = '${ref.id}.$createdAtMs';
    await ref.set({
      'uid': uid,
      'name': name,
      'role': role,
      'reason': reason,
      'nonce': nonce,
      'createdAtMs': createdAtMs,
      'status': 'pending',
      'source': 'app',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (notifyOwner) {
      try {
        await _store(storeId).collection('notifications').add({
          'storeId': storeId,
          'title': 'Yêu cầu mở két',
          'body': '$name xin mở két: $reason. Mở app (biểu tượng két) để xem mã gửi cho quản lý.',
          'type': 'cash_drawer_request',
          'createdAt': FieldValue.serverTimestamp(),
          'targetRoles': ['owner'],
          'readBy': [uid],
          'routePath': '/cash-drawer',
          'routeExtra': {'requestId': ref.id},
        });
      } catch (_) {}
    }
    return CashDrawerRequest(
        id: ref.id, uid: uid, name: name, reason: reason, nonce: nonce, createdAtMs: createdAtMs, status: 'pending');
  }

  Future<void> setRequestStatus(String storeId, String id, String status) =>
      _store(storeId).collection('cash_drawer_requests').doc(id).update({
        'status': status,
        if (status == 'opened') 'openedAt': FieldValue.serverTimestamp(),
      });

  Future<void> log(
    String storeId, {
    required String uid,
    required String name,
    required String role,
    required String reason,
    required bool ok,
    String? error,
    String? requestId,
  }) async {
    await _store(storeId).collection('cash_drawer_logs').add({
      'uid': uid,
      'name': name,
      'role': role,
      'reason': reason,
      'ok': ok,
      'error': error,
      'requestId': requestId,
      'source': 'app',
      'at': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Gửi lệnh tới laptop ----------

  /// Trả về null nếu mở được, ngược lại là thông báo lỗi
  Future<String?> sendOpen(CashDrawerConfig cfg, {required String nonce, required String otp, required String byName}) async {
    if (!cfg.isPaired) return 'Chưa ghép nối laptop mở két (Chủ vào web trên laptop → Két tiền → Ghép nối)';
    final urls = agentUrls(cfg);
    if (urls.isEmpty) return 'Chưa có IP của laptop — Chủ ghép nối lại trên web (mở trên laptop)';
    final client = _client ?? http.Client();
    try {
      for (final base in urls) {
        try {
          final res = await client
              .post(
                Uri.parse('$base/open'),
                headers: {'Content-Type': 'application/json', 'X-Drawer-Token': cfg.token},
                body: jsonEncode({'nonce': nonce, 'otp': otp, 'by': byName, 'source': 'app'}),
              )
              .timeout(const Duration(seconds: 5));
          Map<String, dynamic> body = const {};
          try {
            final d = jsonDecode(utf8.decode(res.bodyBytes));
            if (d is Map<String, dynamic>) body = d;
          } catch (_) {}
          if (res.statusCode == 200 && body['ok'] == true) return null;
          // Laptop trả lời nhưng từ chối (sai / hết hạn mã, lỗi máy in) → không thử IP khác
          return body['error']?.toString() ?? 'Laptop báo lỗi (${res.statusCode})';
        } catch (_) {
          // thử IP tiếp theo
        }
      }
      return 'Không kết nối được laptop mở két (${cfg.computer.isEmpty ? urls.join(', ') : cfg.computer}). '
          'Kiểm tra: điện thoại cùng wifi với laptop, laptop đang bật và chạy Trạm Mở Két; IP laptop đổi thì Chủ ghép nối lại trên web.';
    } finally {
      if (_client == null) client.close();
    }
  }
}

// MỞ KÉT TIỀN (KiotViet) qua máy in hóa đơn KV804 cắm USB vào laptop.
//
// Laptop chạy phần mềm "Trạm Mở Két" (repo webquanlychamcong: tools/tram-mo-ket) ở cổng 8787. App gọi
// http://<IP LAN laptop>:8787/open (điện thoại phải CÙNG wifi với laptop) với mã ghép nối.
// Ghép nối làm trên web (mở trên chính laptop): lưu mã + IP vào stores/{storeId}/private/cash_drawer
// (chỉ Chủ / Quản lý 1 đọc được). Mỗi Chủ / Quản lý 1 có PIN riêng (băm SHA-256, trường pins.{uid}).
// Mỗi lần mở ghi stores/{storeId}/cash_drawer_logs. Bản web song song: webquanlychamcong lib/cashDrawer.ts.
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
  final Map<String, String> pins;

  const CashDrawerConfig({
    required this.token,
    required this.port,
    required this.lanIps,
    required this.printer,
    required this.computer,
    required this.pins,
  });

  bool get isPaired => token.isNotEmpty;

  factory CashDrawerConfig.fromMap(Map<String, dynamic>? m) {
    final raw = m ?? const <String, dynamic>{};
    final ips = raw['lanIps'];
    final pins = raw['pins'];
    return CashDrawerConfig(
      token: raw['token']?.toString() ?? '',
      port: (raw['port'] as num?)?.toInt() ?? CashDrawerService.defaultPort,
      lanIps: ips is List
          ? [for (final e in ips) if (e != null && e.toString().isNotEmpty) e.toString()]
          : (ips is String && ips.isNotEmpty ? [ips] : const []),
      printer: raw['printer']?.toString() ?? '',
      computer: raw['computer']?.toString() ?? '',
      pins: pins is Map ? {for (final e in pins.entries) e.key.toString(): e.value.toString()} : const {},
    );
  }
}

class CashDrawerService {
  CashDrawerService({FirebaseFirestore? db, http.Client? client})
      : _db = db,
        _client = client;

  static const int defaultPort = 8787;
  static const reasons = ['Đổi tiền lẻ', 'Thối tiền cho khách', 'Nộp tiền vào két', 'Kiểm két / giao ca', 'Khác'];

  final FirebaseFirestore? _db;
  final http.Client? _client;
  FirebaseFirestore get _fs => _db ?? FirebaseFirestore.instance;

  // ---------- Logic thuần (có test) ----------

  static bool isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  /// Băm PIN gắn với cửa hàng + người dùng (khớp pinHash bên web)
  static String pinHash(String storeId, String uid, String pin) =>
      sha256.convert(utf8.encode('tram-mo-ket|$storeId|$uid|$pin')).toString();

  static bool checkPin(CashDrawerConfig cfg, String storeId, String uid, String pin) {
    final saved = cfg.pins[uid];
    if (saved == null || saved.isEmpty || !isValidPin(pin)) return false;
    return saved == pinHash(storeId, uid, pin);
  }

  /// Địa chỉ phần mềm trên laptop theo IP LAN đã ghép nối
  static List<String> agentUrls(CashDrawerConfig cfg) =>
      {for (final ip in cfg.lanIps) 'http://$ip:${cfg.port}'}.toList();

  static String fullReason(String reason, String note) {
    final n = note.trim();
    if (reason == 'Khác') return n.isEmpty ? 'Khác' : n;
    return n.isEmpty ? reason : '$reason — $n';
  }

  // ---------- Firestore ----------

  DocumentReference<Map<String, dynamic>> _configRef(String storeId) =>
      _fs.collection('stores').doc(storeId).collection('private').doc('cash_drawer');

  Future<CashDrawerConfig> loadConfig(String storeId) async {
    final snap = await _configRef(storeId).get();
    return CashDrawerConfig.fromMap(snap.data());
  }

  Future<void> setPin(String storeId, String uid, String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('PIN gồm 4–6 chữ số');
    await _configRef(storeId).set({
      'pins': {uid: pinHash(storeId, uid, pin)},
    }, SetOptions(merge: true));
  }

  Future<void> log(
    String storeId, {
    required String uid,
    required String name,
    required String role,
    required String reason,
    required bool ok,
    String? error,
  }) async {
    await _fs.collection('stores').doc(storeId).collection('cash_drawer_logs').add({
      'uid': uid,
      'name': name,
      'role': role,
      'reason': reason,
      'ok': ok,
      'error': error,
      'source': 'app',
      'at': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Gửi lệnh tới laptop ----------

  /// Trả về null nếu mở được, ngược lại là thông báo lỗi
  Future<String?> sendOpen(CashDrawerConfig cfg, String byName) async {
    if (!cfg.isPaired) return 'Chưa ghép nối laptop mở két (web trên laptop → Két tiền → Ghép nối)';
    final urls = agentUrls(cfg);
    if (urls.isEmpty) return 'Chưa có IP của laptop — ghép nối lại trên web (mở trên laptop)';
    final client = _client ?? http.Client();
    try {
      for (final base in urls) {
        try {
          final res = await client
              .post(
                Uri.parse('$base/open'),
                headers: {'Content-Type': 'application/json', 'X-Drawer-Token': cfg.token},
                body: jsonEncode({'by': byName, 'source': 'app'}),
              )
              .timeout(const Duration(seconds: 5));
          Map<String, dynamic> body = const {};
          try {
            final d = jsonDecode(utf8.decode(res.bodyBytes));
            if (d is Map<String, dynamic>) body = d;
          } catch (_) {}
          if (res.statusCode == 200 && body['ok'] == true) return null;
          // Laptop trả lời nhưng báo lỗi (sai mã ghép nối, lỗi máy in) → không thử IP khác
          return body['error']?.toString() ?? 'Laptop báo lỗi (${res.statusCode})';
        } catch (_) {
          // thử IP tiếp theo
        }
      }
      return 'Không kết nối được laptop mở két (${cfg.computer.isEmpty ? urls.join(', ') : cfg.computer}). '
          'Kiểm tra: điện thoại cùng wifi với laptop, laptop đang bật và chạy Trạm Mở Két; IP laptop đổi thì ghép nối lại trên web.';
    } finally {
      if (_client == null) client.close();
    }
  }
}

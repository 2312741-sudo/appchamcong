// Đặt hàng hóa / bao bì cho ngày hôm sau và checklist "Đã soạn" khi vào ca.
//
// Firestore:
//   stores/{storeId}/supply_items/{itemId}     — danh mục hàng (Chủ, QL1, QL2 sửa)
//   stores/{storeId}/supply_orders/{yyyy-MM-dd} — MỘT phiếu cho mỗi ngày nhận hàng; nhiều người cùng thêm vào
//     lines.{itemId} = { code, name, unit, group, qty, contributors[], prepared, preparedBy, preparedByName, preparedAt, note }
//   Cộng dồn số lượng bằng FieldValue.increment + arrayUnion nên nhiều người đặt cùng lúc không ghi đè nhau.
import 'package:cloud_firestore/cloud_firestore.dart';

int? _ms(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.millisecondsSinceEpoch;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
  return 0;
}

/// Một mặt hàng trong danh mục đặt hàng
class SupplyItem {
  final String id;
  /// Mã hàng (VD: BB001) — tuỳ chọn, không trùng trong cửa hàng; dùng để tìm nhanh, xuất Excel và nối kho POS sau này
  final String code;
  final String name;
  final String unit;
  final String group;
  final int order;
  final bool active;

  const SupplyItem({
    required this.id,
    this.code = '',
    required this.name,
    this.unit = '',
    this.group = '',
    this.order = 0,
    this.active = true,
  });

  factory SupplyItem.fromJson(Map<String, dynamic> json, String id) => SupplyItem(
        id: id,
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        unit: (json['unit'] ?? '').toString(),
        group: (json['group'] ?? '').toString(),
        order: _num(json['order']).toInt(),
        active: json['active'] != false,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'unit': unit,
        'group': group,
        'order': order,
        'active': active,
      };
}

/// Một lần ai đó thêm số lượng vào phiếu
class SupplyContribution {
  final String uid;
  final String name;
  final double qty;
  final int at;

  const SupplyContribution({required this.uid, required this.name, required this.qty, required this.at});

  factory SupplyContribution.fromJson(Map<String, dynamic> json) => SupplyContribution(
        uid: (json['uid'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        qty: _num(json['qty']),
        at: _ms(json['at']) ?? 0,
      );

  Map<String, dynamic> toJson() => {'uid': uid, 'name': name, 'qty': qty, 'at': at};
}

/// Một dòng hàng trong phiếu ngày
class SupplyOrderLine {
  final String itemId;
  final String code;
  final String name;
  final String unit;
  final String group;
  final double qty;
  final String note;
  final List<SupplyContribution> contributors;
  final bool prepared;
  final String preparedBy;
  final String preparedByName;
  final int? preparedAt;

  const SupplyOrderLine({
    required this.itemId,
    this.code = '',
    required this.name,
    this.unit = '',
    this.group = '',
    this.qty = 0,
    this.note = '',
    this.contributors = const [],
    this.prepared = false,
    this.preparedBy = '',
    this.preparedByName = '',
    this.preparedAt,
  });

  factory SupplyOrderLine.fromJson(String itemId, Map<String, dynamic> json) {
    final raw = json['contributors'];
    return SupplyOrderLine(
      itemId: itemId,
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      group: (json['group'] ?? '').toString(),
      qty: _num(json['qty']),
      note: (json['note'] ?? '').toString(),
      contributors: raw is List
          ? raw.whereType<Map>().map((e) => SupplyContribution.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
      prepared: json['prepared'] == true,
      preparedBy: (json['preparedBy'] ?? '').toString(),
      preparedByName: (json['preparedByName'] ?? '').toString(),
      preparedAt: _ms(json['preparedAt']),
    );
  }

  /// Tên những người đã đặt dòng này (không trùng, theo thứ tự đặt)
  List<String> get contributorNames {
    final seen = <String>{};
    final out = <String>[];
    for (final c in contributors) {
      final n = c.name.isNotEmpty ? c.name : c.uid;
      if (seen.add(n)) out.add(n);
    }
    return out;
  }
}

/// Phiếu đặt hàng của một ngày nhận hàng (mã phiếu = ngày yyyy-MM-dd)
class SupplyOrder {
  final String date;
  final List<SupplyOrderLine> lines;
  final int? updatedAt;

  const SupplyOrder({required this.date, this.lines = const [], this.updatedAt});

  factory SupplyOrder.fromJson(String date, Map<String, dynamic>? json) {
    final raw = json?['lines'];
    final lines = <SupplyOrderLine>[];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) {
          final line = SupplyOrderLine.fromJson(k.toString(), Map<String, dynamic>.from(v));
          if (line.qty > 0 || line.name.isNotEmpty) lines.add(line);
        }
      });
    }
    lines.sort((a, b) {
      final g = a.group.toLowerCase().compareTo(b.group.toLowerCase());
      return g != 0 ? g : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return SupplyOrder(date: date, lines: lines, updatedAt: _ms(json?['updatedAt']));
  }

  int get preparedCount => lines.where((l) => l.prepared).length;
  bool get isEmpty => lines.isEmpty;
  bool get isAllPrepared => lines.isNotEmpty && preparedCount == lines.length;
}

/// Cài đặt đặt & soạn hàng của cửa hàng: stores/{storeId}/supply_settings/config (Chủ, QL1, QL2 sửa)
class SupplySettings {
  /// Giờ chốt đặt hàng "HH:mm" cho phiếu NGÀY HÔM SAU (vd. "21:00" → phiếu ngày 30 khóa lúc 21:00 ngày 29).
  /// null = không chốt.
  final String? cutoffTime;

  /// Bộ phận (id trong store.departments) được xếp lịch hôm nay sẽ là người soạn hàng.
  /// Rỗng = mọi người trong ca đều soạn được.
  final List<String> preparerDepartmentIds;

  const SupplySettings({this.cutoffTime, this.preparerDepartmentIds = const []});

  factory SupplySettings.fromJson(Map<String, dynamic>? json) {
    final cut = (json?['cutoffTime'] ?? '').toString().trim();
    final deps = json?['preparerDepartmentIds'];
    return SupplySettings(
      cutoffTime: RegExp(r'^\d{1,2}:\d{2}$').hasMatch(cut) ? cut : null,
      preparerDepartmentIds: deps is List ? deps.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'cutoffTime': cutoffTime,
        'preparerDepartmentIds': preparerDepartmentIds,
      };
}

/// Chuẩn hoá mã hàng: bỏ khoảng trắng thừa, viết hoa (BB 001 → BB001)
String normalizeSupplyCode(String raw) => raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

/// Kiểm tra mã hàng: rỗng là được (không bắt buộc); có thì chỉ chữ, số, - _ . tối đa 20 ký tự và không trùng mặt hàng khác.
/// Trả về câu báo lỗi, hoặc null nếu hợp lệ.
String? validateSupplyCode(String code, List<SupplyItem> items, {String? exceptId}) {
  final c = normalizeSupplyCode(code);
  if (c.isEmpty) return null;
  if (c.length > 20) return 'Mã hàng tối đa 20 ký tự';
  if (!RegExp(r'^[A-Z0-9._-]+$').hasMatch(c)) return 'Mã hàng chỉ gồm chữ không dấu, số và - _ .';
  final dup = items.where((i) => i.id != exceptId && normalizeSupplyCode(i.code) == c).toList();
  if (dup.isNotEmpty) return 'Mã "$c" đã dùng cho "${dup.first.name}"';
  return null;
}

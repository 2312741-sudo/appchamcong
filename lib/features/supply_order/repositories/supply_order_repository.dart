import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/supply_order_model.dart';

/// Đặt hàng ngày mai & soạn hàng khi vào ca (xem models/supply_order_model.dart)
class SupplyOrderRepository {
  final FirebaseFirestore _firestore;

  SupplyOrderRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _itemsRef(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('supply_items');

  CollectionReference<Map<String, dynamic>> _ordersRef(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('supply_orders');

  // ==================== DANH MỤC HÀNG ====================

  Stream<List<SupplyItem>> watchItems(String storeId, {bool includeInactive = false}) {
    return _itemsRef(storeId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => SupplyItem.fromJson(d.data(), d.id))
          .where((i) => includeInactive || i.active)
          .toList();
      list.sort((a, b) {
        final g = a.group.toLowerCase().compareTo(b.group.toLowerCase());
        if (g != 0) return g;
        final o = a.order.compareTo(b.order);
        return o != 0 ? o : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  Future<void> saveItem(String storeId, SupplyItem item) async {
    final data = {...item.toJson(), 'updatedAt': FieldValue.serverTimestamp()};
    if (item.id.isEmpty) {
      await _itemsRef(storeId).add({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _itemsRef(storeId).doc(item.id).set(data, SetOptions(merge: true));
    }
  }

  /// Ẩn mặt hàng (không xóa hẳn để phiếu cũ vẫn đọc được tên)
  Future<void> setItemActive(String storeId, String itemId, bool active) =>
      _itemsRef(storeId).doc(itemId).update({'active': active, 'updatedAt': FieldValue.serverTimestamp()});

  // ==================== PHIẾU THEO NGÀY ====================

  Stream<SupplyOrder> watchOrder(String storeId, String date) {
    return _ordersRef(storeId).doc(date).snapshots().map((d) => SupplyOrder.fromJson(date, d.data()));
  }

  /// Phiếu gần đây (lịch sử), mới nhất trước
  Stream<List<SupplyOrder>> watchRecentOrders(String storeId, {int limit = 30}) {
    return _ordersRef(storeId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SupplyOrder.fromJson(d.id, d.data())).toList());
  }

  /// Thêm [qty] một mặt hàng vào phiếu ngày [date]. Nhiều người cùng thêm: số lượng CỘNG DỒN
  /// (FieldValue.increment) và ghi lại từng người đặt (arrayUnion) — không ghi đè nhau.
  Future<void> addToOrder(
    String storeId,
    String date, {
    required SupplyItem item,
    required double qty,
    required String uid,
    required String userName,
    String note = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final line = <String, dynamic>{
      'name': item.name,
      'unit': item.unit,
      'group': item.group,
      'qty': FieldValue.increment(qty),
      'contributors': FieldValue.arrayUnion([
        SupplyContribution(uid: uid, name: userName, qty: qty, at: now).toJson(),
      ]),
      // Thêm hàng sau khi đã soạn → cần soạn lại
      'prepared': false,
    };
    if (note.trim().isNotEmpty) line['note'] = note.trim();
    await _ordersRef(storeId).doc(date).set({
      'date': date,
      'updatedAt': FieldValue.serverTimestamp(),
      'lines': {item.id: line},
    }, SetOptions(merge: true));
  }

  /// Sửa tổng số lượng / ghi chú của một dòng (người sửa được ghi vào danh sách người đặt)
  Future<void> updateLine(
    String storeId,
    String date,
    String itemId, {
    required double qty,
    required String note,
    required String uid,
    required String userName,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _ordersRef(storeId).doc(date).update({
      'lines.$itemId.qty': qty,
      'lines.$itemId.note': note.trim(),
      'lines.$itemId.contributors': FieldValue.arrayUnion([
        {'uid': uid, 'name': '$userName (sửa thành ${_fmt(qty)})', 'qty': 0, 'at': now},
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeLine(String storeId, String date, String itemId) async {
    await _ordersRef(storeId).doc(date).update({
      'lines.$itemId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Tích / bỏ tích "Đã soạn" cho một dòng
  Future<void> setPrepared(
    String storeId,
    String date,
    String itemId, {
    required bool prepared,
    required String uid,
    required String userName,
  }) async {
    await _ordersRef(storeId).doc(date).update({
      'lines.$itemId.prepared': prepared,
      'lines.$itemId.preparedBy': prepared ? uid : FieldValue.delete(),
      'lines.$itemId.preparedByName': prepared ? userName : FieldValue.delete(),
      'lines.$itemId.preparedAt': prepared ? FieldValue.serverTimestamp() : FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String _fmt(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

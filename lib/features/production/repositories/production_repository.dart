import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/production_model.dart';

const List<ProductionTask> kDefaultProductionTasks = [
  ProductionTask(
    id: 'task_san_xuat',
    name: 'Sản lượng sản xuất trong ca',
    unit: ProductionUnitType.qty,
    unitLabel: 'sản phẩm',
    active: true,
    order: 1,
  ),
  ProductionTask(
    id: 'task_ve_sinh',
    name: 'Vệ sinh khu vực sản xuất & dụng cụ',
    unit: ProductionUnitType.qty,
    unitLabel: 'khu vực',
    active: true,
    order: 2,
  ),
  ProductionTask(
    id: 'task_ban_giao',
    name: 'Bàn giao nguyên vật liệu & công cụ',
    unit: ProductionUnitType.qty,
    unitLabel: 'lần',
    active: true,
    order: 3,
  ),
];

class ProductionRepository {
  final FirebaseFirestore _firestore;

  ProductionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tasksRef(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('production_tasks');

  CollectionReference<Map<String, dynamic>> _reportsRef(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('production_reports');

  // Lấy danh sách task active để hiển thị cho nhân viên (Stream)
  Stream<List<ProductionTask>> watchActiveTasks(String storeId) {
    return _tasksRef(storeId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => ProductionTask.fromJson(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list.isEmpty ? kDefaultProductionTasks : list;
    });
  }

  // Lấy danh sách task active trực tiếp (Future) với fallback mặc định
  Future<List<ProductionTask>> getActiveTasks(String storeId) async {
    try {
      final snap = await _tasksRef(storeId)
          .where('active', isEqualTo: true)
          .get();
      if (snap.docs.isEmpty) {
        return kDefaultProductionTasks;
      }
      final list = snap.docs
          .map((doc) => ProductionTask.fromJson(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list.isEmpty ? kDefaultProductionTasks : list;
    } catch (_) {
      return kDefaultProductionTasks;
    }
  }

  // Kiểm tra nhân viên đã nộp báo cáo sản xuất trong ngày hôm nay chưa
  Future<bool> hasReportToday(String storeId, String userId, String date) async {
    try {
      final snap = await _reportsRef(storeId)
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: date)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Submit báo cáo
  Future<void> submitReport(String storeId, ProductionReport report) async {
    try {
      await _reportsRef(storeId).add(report.toJson());
    } catch (e) {
      throw Exception('Nộp báo cáo thất bại: $e');
    }
  }
}

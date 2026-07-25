import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/production_model.dart';

class ProductionRepository {
  final FirebaseFirestore _firestore;

  ProductionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tasksRef(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('production_tasks');

  CollectionReference<Map<String, dynamic>> _reportsRef(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('production_reports');

  // Lấy danh sách task active để hiển thị cho nhân viên
  Stream<List<ProductionTask>> watchActiveTasks(String storeId) {
    return _tasksRef(storeId)
        .where('active', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ProductionTask.fromJson(doc.data(), doc.id))
            .toList());
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

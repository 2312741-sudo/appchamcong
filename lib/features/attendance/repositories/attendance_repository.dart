import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/attendance_model.dart';

class AttendanceRepository {
  final FirebaseFirestore _firestore;

  AttendanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _attendances(String storeId) =>
      _firestore
          .collection('stores')
          .doc(storeId)
          .collection('attendances');

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> checkIn(
    String storeId,
    String userId,
    CheckInMethod method,
  ) async {
    try {
      final now = DateTime.now().toUtc();
      final date = _todayDate();

      // Check for existing active record today
      final existing = await _attendances(storeId)
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: date)
          .where('checkOut', isNull: true)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('Bạn đang trong ca làm việc hôm nay');
      }

      await _attendances(storeId).add({
        'userId': userId,
        'storeId': storeId,
        'date': date,
        'checkIn': Timestamp.fromDate(now),
        'checkOut': null,
        'checkInMethod': method.value,
        'totalHours': 0.0,
        'isEdited': false,
        'editedBy': null,
        'editNote': null,
        'isOffline': false,
      });
    } catch (e) {
      throw Exception('Chấm vào thất bại: $e');
    }
  }

  Future<void> checkOut(String storeId, String userId) async {
    try {
      final date = _todayDate();
      final now = DateTime.now().toUtc();

      final query = await _attendances(storeId)
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: date)
          .where('checkOut', isNull: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('Không tìm thấy ca làm việc nào đang hoạt động');
      }

      final doc = query.docs.first;
      final checkIn = (doc.data()['checkIn'] as Timestamp).toDate().toUtc();
      final totalHours = now.difference(checkIn).inMinutes / 60.0;

      await doc.reference.update({
        'checkOut': Timestamp.fromDate(now),
        'totalHours': double.parse(totalHours.toStringAsFixed(2)),
      });
    } catch (e) {
      throw Exception('Chấm ra thất bại: $e');
    }
  }

  Stream<AttendanceModel?> watchTodayAttendance(
      String storeId, String userId) {
    final date = _todayDate();
    return _attendances(storeId)
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      
      // Look for active shift first
      final activeDoc = snap.docs.where((d) => d.data()['checkOut'] == null).firstOrNull;
      if (activeDoc != null) {
        return AttendanceModel.fromFirestore(activeDoc);
      }
      
      // Otherwise, return the latest shift
      final list = snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list.first;
    });
  }

  Stream<List<AttendanceModel>> watchMonthAttendance(
    String storeId,
    String userId,
    String month, // YYYY-MM
  ) {
    return _attendances(storeId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => AttendanceModel.fromFirestore(d))
              .where((a) => a.date.startsWith(month))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  Stream<List<AttendanceModel>> watchAllAttendances(
      String storeId, String date) {
    return _attendances(storeId)
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => AttendanceModel.fromFirestore(d))
              .toList();
          list.sort((a, b) => a.checkIn.compareTo(b.checkIn));
          return list;
        });
  }

  Future<void> editAttendance(
    String storeId,
    String attendanceId,
    DateTime newCheckIn,
    DateTime newCheckOut,
    String editNote,
    String editedBy,
  ) async {
    try {
      final totalHours =
          newCheckOut.difference(newCheckIn).inMinutes / 60.0;
      await _attendances(storeId).doc(attendanceId).update({
        'checkIn': Timestamp.fromDate(newCheckIn.toUtc()),
        'checkOut': Timestamp.fromDate(newCheckOut.toUtc()),
        'totalHours': double.parse(totalHours.toStringAsFixed(2)),
        'isEdited': true,
        'editedBy': editedBy,
        'editNote': editNote,
      });
    } catch (e) {
      throw Exception('Chỉnh sửa chấm công thất bại: $e');
    }
  }

  Future<List<AttendanceModel>> getMonthAttendances(
    String storeId,
    String month,
  ) async {
    try {
      final snap = await _attendances(storeId)
          .where('date', isGreaterThanOrEqualTo: '$month-01')
          .where('date', isLessThanOrEqualTo: '$month-31')
          .orderBy('date')
          .get();
      return snap.docs
          .map((d) => AttendanceModel.fromFirestore(d))
          .toList();
    } catch (e) {
      throw Exception('Lấy dữ liệu chấm công thất bại: $e');
    }
  }
}

// ---------- Provider ----------

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

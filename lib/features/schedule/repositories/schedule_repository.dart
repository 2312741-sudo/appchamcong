import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/schedule_model.dart';

class ScheduleRepository {
  final FirebaseFirestore _firestore;

  ScheduleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ---------- Collection reference ----------

  CollectionReference<Map<String, dynamic>> _schedules(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('schedules');

  // ---------- Reads ----------

  Future<ScheduleModel?> getWeekSchedule(
      String storeId, String weekStart) async {
    try {
      final doc = await _schedules(storeId).doc(weekStart).get();
      if (!doc.exists) return null;
      return ScheduleModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Lấy lịch tuần thất bại: $e');
    }
  }

  Stream<ScheduleModel?> watchWeekSchedule(
      String storeId, String weekStart) {
    return _schedules(storeId).doc(weekStart).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ScheduleModel.fromFirestore(snap);
    });
  }

  // ---------- Writes ----------

  /// Upserts a single user's DaySchedule for the given week.
  Future<void> saveUserSchedule(
    String storeId,
    String userId,
    String weekStart,
    DaySchedule schedule,
  ) async {
    try {
      final ref = _schedules(storeId).doc(weekStart);
      await ref.set({
        'storeId': storeId,
        'weekStart': weekStart,
        'shifts': {userId: schedule.toJson()},
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Lưu lịch cá nhân thất bại: $e');
    }
  }

  /// Owner sets the full weekly schedule for all employees at once.
  Future<void> setFullSchedule(
    String storeId,
    String weekStart,
    Map<String, DaySchedule> allShifts,
  ) async {
    try {
      final shiftsJson = allShifts.map((k, v) => MapEntry(k, v.toJson()));
      await _schedules(storeId).doc(weekStart).set({
        'storeId': storeId,
        'weekStart': weekStart,
        'shifts': shiftsJson,
      });
    } catch (e) {
      throw Exception('Lưu lịch toàn bộ thất bại: $e');
    }
  }

  // ---------- Date utilities ----------

  /// Returns the Monday of the week containing [date] as YYYY-MM-DD.
  String getWeekStart(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Returns the next [count] week-start dates starting from this week's Monday.
  List<String> getNextWeeks(int count) {
    final now = DateTime.now();
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(count, (i) {
      final monday = thisMonday.add(Duration(days: i * 7));
      final y = monday.year.toString().padLeft(4, '0');
      final m = monday.month.toString().padLeft(2, '0');
      final d = monday.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    });
  }
}

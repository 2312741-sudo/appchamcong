import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/schedule_model.dart';

class ScheduleRepository {
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  ScheduleRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestoreOverride = firestore,
        _authOverride = auth;

  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

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

  /// Backend authenticates the actor and commits business data before notifications.
  Future<void> saveUserSchedule(String storeId, String userId,
      String weekStart, DaySchedule schedule) async {
    await FirebaseFunctions.instance.httpsCallable('saveNotificationSchedule').call({
      'storeId': storeId,
      'weekStart': weekStart,
      'shifts': {userId: schedule.toJson()},
      'selfRegistration': _auth.currentUser?.uid == userId,
    });
  }

  Future<void> setFullSchedule(String storeId, String weekStart,
      Map<String, DaySchedule> allShifts) async {
    await FirebaseFunctions.instance.httpsCallable('saveNotificationSchedule').call({
      'storeId': storeId,
      'weekStart': weekStart,
      'shifts': allShifts.map((key, value) => MapEntry(key, value.toJson())),
    });
  }

  // ---------- Date utilities ----------

  /// Returns the Monday of the week containing [date] as YYYY-MM-DD.
  String getWeekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final day = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Returns a list of week-start dates spanning [pastWeeks] before this week to [futureWeeks] after this week.
  List<String> getWeeksRange({int pastWeeks = 8, int futureWeeks = 6}) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    final thisMonday = d.subtract(Duration(days: d.weekday - 1));
    final total = pastWeeks + 1 + futureWeeks;
    return List.generate(total, (i) {
      final offset = i - pastWeeks;
      final monday = thisMonday.add(Duration(days: offset * 7));
      final y = monday.year.toString().padLeft(4, '0');
      final m = monday.month.toString().padLeft(2, '0');
      final day = monday.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    });
  }

  /// Returns the next [count] week-start dates starting from this week's Monday.
  List<String> getNextWeeks(int count) {
    return getWeeksRange(pastWeeks: 0, futureWeeks: count > 0 ? count - 1 : 0);
  }
}

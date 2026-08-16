import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/auth/app_permissions.dart';
import '../../../models/member_model.dart';
import '../../../models/schedule_model.dart';

class ScheduleRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ScheduleRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

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
      final now = Timestamp.now();
      await ref.set({
        'storeId': storeId,
        'weekStart': weekStart,
        'shifts': {userId: schedule.toJson()},
        'updatedAt': now,
      }, SetOptions(merge: true));

      // Trigger notification
      try {
        final caller = _auth.currentUser;
        final isSelf = caller?.uid == userId;

        if (isSelf) {
          // Employee registered/updated their own schedule -> Notify Owner & Manager 1
          final memberDoc = await _firestore.collection('stores').doc(storeId).collection('members').doc(userId).get();
          final memberName = memberDoc.data()?['name'] as String? ?? 'Nhân viên';

          await _firestore.collection('stores').doc(storeId).collection('notifications').add({
            'storeId': storeId,
            'title': 'Đăng ký lịch làm mới',
            'body': '$memberName vừa đăng ký lịch làm việc tuần ($weekStart).',
            'type': 'schedule_changed',
            'createdAt': now,
            'targetRoles': ['owner', 'manager_1', 'manager'],
            'readBy': caller?.uid != null ? [caller!.uid] : [],
            'routePath': '/schedule-manager',
            'routeExtra': {'weekStart': weekStart, 'userId': userId},
          });
        } else {
          // Manager/Owner set schedule for this specific employee -> Notify this employee!
          await _firestore.collection('stores').doc(storeId).collection('notifications').add({
            'storeId': storeId,
            'title': 'Lịch làm việc đã cập nhật',
            'body': 'Lịch làm việc tuần ($weekStart) của bạn đã được cập nhật. Nhấn để xem chi tiết.',
            'type': 'schedule_changed',
            'createdAt': now,
            'targetUserId': userId,
            'readBy': caller?.uid != null ? [caller!.uid] : [],
            'routePath': '/schedule',
            'routeExtra': {'weekStart': weekStart},
          });
        }
      } catch (_) {}
    } catch (e) {
      throw Exception('Lưu lịch cá nhân thất bại: $e');
    }
  }

  /// Sets the full weekly schedule for all employees.
  /// Enforces permissions: Owner & Manager 1 can edit all shifts.
  /// Manager 2 can only update delivery/giaohang flags, cannot add/remove work shifts.
  Future<void> setFullSchedule(
    String storeId,
    String weekStart,
    Map<String, DaySchedule> allShifts,
  ) async {
    try {
      final caller = _auth.currentUser;
      if (caller != null) {
        final callerDoc = await _firestore
            .collection('stores')
            .doc(storeId)
            .collection('members')
            .doc(caller.uid)
            .get();

        if (callerDoc.exists) {
          final callerRole = UserRoleExtension.fromString(
              callerDoc.data()?['role'] as String?);

          if (!AppPermissions.canManageSchedule(callerRole)) {
            // Check if caller is manager2
            if (callerRole == UserRole.manager2) {
              // Fetch existing schedule to ensure shifts weren't altered
              final existingDoc = await _schedules(storeId).doc(weekStart).get();
              if (existingDoc.exists) {
                final existingSchedule = ScheduleModel.fromFirestore(existingDoc);
                // Verify shifts structure hasn't changed (excluding delivery/giaohang)
                for (final entry in allShifts.entries) {
                  final uid = entry.key;
                  final newDaySchedule = entry.value;
                  final oldDaySchedule = existingSchedule.getScheduleForUser(uid);
                  for (int d = 1; d <= 7; d++) {
                    final newWorkShifts = newDaySchedule.shiftForDay(d).where((s) => s != 'delivery' && s != 'giaohang').toSet();
                    final oldWorkShifts = oldDaySchedule?.shiftForDay(d).where((s) => s != 'delivery' && s != 'giaohang').toSet() ?? <String>{};
                    if (!newWorkShifts.containsAll(oldWorkShifts) || !oldWorkShifts.containsAll(newWorkShifts)) {
                      throw Exception('403 Forbidden: Quản lý 2 không có quyền xếp hoặc sửa ca làm việc (chỉ được tick chở hàng/giao hàng)');
                    }
                  }
                }
              } else {
                throw Exception('403 Forbidden: Quản lý 2 không có quyền tạo mới lịch làm việc');
              }
            } else {
              throw Exception('403 Forbidden: Bạn không có quyền sửa lịch làm việc');
            }
          }
        }
      }

      final shiftsJson = allShifts.map((k, v) => MapEntry(k, v.toJson()));
      final now = Timestamp.now();
      await _schedules(storeId).doc(weekStart).set({
        'storeId': storeId,
        'weekStart': weekStart,
        'shifts': shiftsJson,
        'updatedAt': now,
        'updatedBy': caller?.uid,
      });

      // Create notification for all members
      try {
        await _firestore.collection('stores').doc(storeId).collection('notifications').add({
          'storeId': storeId,
          'title': 'Lịch làm việc đã cập nhật',
          'body': 'Lịch làm việc tuần ($weekStart) đã được cập nhật. Nhấn để xem chi tiết ca của bạn.',
          'type': 'schedule_changed',
          'createdAt': now,
          'targetRoles': ['employee', 'manager_1', 'manager_2', 'manager'],
          'readBy': caller?.uid != null ? [caller!.uid] : [],
          'routePath': '/schedule',
          'routeExtra': {'weekStart': weekStart},
        });
      } catch (_) {}
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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/attendance_model.dart';
import '../repositories/attendance_repository.dart';
import '../../store/providers/store_provider.dart';

// ---------- Today's attendance ----------

final todayAttendanceProvider = StreamProvider<AttendanceModel?>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (storeId == null || uid == null) return Stream.value(null);
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.watchTodayAttendance(storeId, uid);
});

// ---------- Month attendance (family) ----------

final monthAttendanceProvider =
    StreamProvider.family<List<AttendanceModel>, String>((ref, month) {
  final storeId = ref.watch(currentStoreIdProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (storeId == null || uid == null) return Stream.value([]);
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.watchMonthAttendance(storeId, uid, month);
});

// ---------- All today attendances (owner/manager view) ----------

final allTodayAttendancesProvider =
    StreamProvider<List<AttendanceModel>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return Stream.value([]);

  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  final date =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.watchAllAttendances(storeId, date);
});

// ---------- All attendances on a specific date (family) ----------

final dateAttendancesProvider =
    StreamProvider.family<List<AttendanceModel>, String>((ref, date) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return Stream.value([]);
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.watchAllAttendances(storeId, date);
});

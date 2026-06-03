import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/schedule_model.dart';
import '../../store/providers/store_provider.dart';
import '../repositories/schedule_repository.dart';

// ---------- Repository ----------

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

// ---------- Current week start ----------

final currentWeekStartProvider = StateProvider<String>((ref) {
  final repo = ref.read(scheduleRepositoryProvider);
  return repo.getWeekStart(DateTime.now());
});

// ---------- Week schedule (stream by weekStart) ----------

final weekScheduleProvider =
    StreamProvider.family<ScheduleModel?, String>((ref, weekStart) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value(null);
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.watchWeekSchedule(storeId, weekStart);
});

// ---------- My schedule for the current week ----------

final myScheduleProvider = Provider<DaySchedule?>((ref) {
  final weekStart = ref.watch(currentWeekStartProvider);
  final scheduleAsync = ref.watch(weekScheduleProvider(weekStart));
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  return scheduleAsync.whenOrNull(
    data: (schedule) => schedule?.getScheduleForUser(uid),
  );
});

// ---------- Available weeks (current + next 2) ----------

final availableWeeksProvider = Provider<List<String>>((ref) {
  final repo = ref.read(scheduleRepositoryProvider);
  return repo.getNextWeeks(3);
});

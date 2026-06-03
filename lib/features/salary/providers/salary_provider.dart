import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/attendance_model.dart';
import '../../../models/member_model.dart';
import '../../store/providers/store_provider.dart';

// ---------- Repository-level salary logic ----------

class SalaryRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SalaryRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String _getUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Chưa đăng nhập');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _attendances(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('attendances');

  CollectionReference<Map<String, dynamic>> _members(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('members');

  /// Returns list of AttendanceModel for [userId] in [month] (YYYY-MM).
  Future<List<AttendanceModel>> getMonthAttendances(
      String storeId, String userId, String month) async {
    final snap = await _attendances(storeId)
        .where('userId', isEqualTo: userId)
        .get();
    return snap.docs
        .map(AttendanceModel.fromFirestore)
        .where((a) => a.date.startsWith(month))
        .toList();
  }

  /// Returns all attendance records for all members in [month].
  Future<Map<String, List<AttendanceModel>>> getAllMonthAttendances(
      String storeId, String month) async {
    final snap = await _attendances(storeId)
        .where('date', isGreaterThanOrEqualTo: '$month-01')
        .where('date', isLessThanOrEqualTo: '$month-31')
        .get();
    final result = <String, List<AttendanceModel>>{};
    for (final doc in snap.docs) {
      final att = AttendanceModel.fromFirestore(doc);
      result.putIfAbsent(att.userId, () => []).add(att);
    }
    return result;
  }

  /// Fetches all active members of the store.
  Future<List<MemberModel>> getActiveMembers(String storeId) async {
    final snap = await _members(storeId)
        .where('status', isEqualTo: 'active')
        .get();
    return snap.docs.map(MemberModel.fromFirestore).toList();
  }

  /// Calculates total worked hours for [attendances].
  double calculateTotalHours(List<AttendanceModel> attendances) {
    return attendances.fold(0.0, (sum, a) => sum + a.totalHours);
  }

  /// Calculates salary for given hours + member config.
  double calculateSalary(MemberModel member, double totalHours) {
    if (member.isFulltime) {
      final ratio = member.standardHoursPerMonth > 0
          ? (totalHours / member.standardHoursPerMonth).clamp(0.0, 1.5)
          : 0.0;
      return member.baseMonthlySalary * ratio;
    } else {
      return totalHours * member.baseHourlyRate;
    }
  }
}

// ---------- Providers ----------

final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  return SalaryRepository();
});

// My monthly salary (for employee view)
final myMonthlySalaryProvider =
    FutureProvider.family<double, String>((ref, month) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return 0.0;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return 0.0;
  final repo = ref.read(salaryRepositoryProvider);
  final members = await repo.getActiveMembers(storeId);
  final member = members.cast<MemberModel?>().firstWhere(
        (m) => m?.userId == uid,
        orElse: () => null,
      );
  if (member == null) return 0.0;
  final attendances = await repo.getMonthAttendances(storeId, uid, month);
  final totalHours = repo.calculateTotalHours(attendances);
  return repo.calculateSalary(member, totalHours);
});

// All salaries for owner view
final allSalariesProvider =
    FutureProvider.family<Map<String, double>, String>((ref, month) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return {};
  final repo = ref.read(salaryRepositoryProvider);
  final members = await repo.getActiveMembers(storeId);
  final allAttendances = await repo.getAllMonthAttendances(storeId, month);
  final result = <String, double>{};
  for (final member in members) {
    final attendances = allAttendances[member.userId] ?? [];
    final totalHours = repo.calculateTotalHours(attendances);
    result[member.userId] = repo.calculateSalary(member, totalHours);
  }
  return result;
});

// Total hours for a specific user in a month
final monthTotalHoursProvider = FutureProvider.family<double,
    ({String userId, String month})>((ref, args) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return 0.0;
  final repo = ref.read(salaryRepositoryProvider);
  final attendances =
      await repo.getMonthAttendances(storeId, args.userId, args.month);
  return repo.calculateTotalHours(attendances);
});

// All attendance records for a specific user in a month (for detail screen)
final myMonthAttendancesProvider =
    FutureProvider.family<List<AttendanceModel>, String>((ref, month) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return [];
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return [];
  final repo = ref.read(salaryRepositoryProvider);
  return repo.getMonthAttendances(storeId, uid, month);
});

// Current user member data (from active members)
final myMemberDataProvider = FutureProvider<MemberModel?>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return null;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  final repo = ref.read(salaryRepositoryProvider);
  final members = await repo.getActiveMembers(storeId);
  try {
    return members.firstWhere((m) => m.userId == uid);
  } catch (_) {
    return null;
  }
});

// All active members (for owner salary overview)
final allActiveMembersProvider =
    FutureProvider.family<List<MemberModel>, String>((ref, storeId) async {
  final repo = ref.read(salaryRepositoryProvider);
  return repo.getActiveMembers(storeId);
});

// Selected month for salary screens
final selectedSalaryMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});

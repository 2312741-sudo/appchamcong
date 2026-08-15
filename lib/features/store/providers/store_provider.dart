import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/store_model.dart';
import '../../../models/member_model.dart';
import '../repositories/store_repository.dart';
import 'user_repository.dart';
import '../../../models/advance_request_model.dart';

// ---------- Repository Provider ----------

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository();
});

// ---------- Current Store ----------

final currentStoreIdProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(userProvider);
  return userAsync.whenOrNull(data: (user) => user?.currentStoreId);
});

final currentStoreProvider = StreamProvider<StoreModel?>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value(null);
  final repo = ref.watch(storeRepositoryProvider);
  return repo.watchStore(storeId);
});

final userStoresProvider = FutureProvider<List<StoreModel>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return [];
  final repo = ref.watch(storeRepositoryProvider);
  return repo.getUserStores(uid);
});

// ---------- Members ----------

final storeMembersProvider = StreamProvider<List<MemberModel>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value([]);
  final repo = ref.watch(storeRepositoryProvider);
  return repo.watchMembers(storeId);
});

final pendingMembersProvider = StreamProvider<List<MemberModel>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value([]);
  final repo = ref.watch(storeRepositoryProvider);
  return repo.watchPendingMembers(storeId);
});

final activeMembersProvider = Provider<List<MemberModel>>((ref) {
  final membersAsync = ref.watch(storeMembersProvider);
  return membersAsync.whenOrNull(
        data: (members) =>
            members.where((m) => m.status == MemberStatus.active).toList(),
      ) ??
      [];
});

final currentMemberProvider = Provider<MemberModel?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  final members = ref.watch(storeMembersProvider);
  return members.whenOrNull(
    data: (list) {
      try {
        return list.firstWhere((m) => m.userId == uid);
      } catch (_) {
        return null;
      }
    },
  );
});

// ---------- Advances ----------

final storeAdvancesProvider = StreamProvider.family<List<AdvanceRequestModel>, String>((ref, month) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value([]);
  final repo = ref.watch(storeRepositoryProvider);
  return repo.watchAdvances(storeId, month);
});

final myAdvancesProvider = Provider.family<List<AdvanceRequestModel>, String>((ref, month) {
  final advancesAsync = ref.watch(storeAdvancesProvider(month));
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return [];
  return advancesAsync.whenOrNull(
    data: (list) => list.where((a) => a.userId == uid).toList(),
  ) ?? [];
});

final userAdvancesProvider = Provider.family<List<AdvanceRequestModel>, ({String userId, String month})>((ref, args) {
  final advancesAsync = ref.watch(storeAdvancesProvider(args.month));
  return advancesAsync.whenOrNull(
    data: (list) => list.where((a) => a.userId == args.userId).toList(),
  ) ?? [];
});


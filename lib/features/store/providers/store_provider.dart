import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/store_model.dart';
import '../../../models/member_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/store_repository.dart';
import '../../../models/advance_request_model.dart';

// ---------- Repository Provider ----------

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository();
});

// ---------- Current Store ----------

final currentStoreIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return null;

  // 1. If currentStoreId is set and valid within storeIds, return it
  if (user.currentStoreId != null && user.currentStoreId!.isNotEmpty) {
    if (user.storeIds.isEmpty || user.storeIds.contains(user.currentStoreId)) {
      return user.currentStoreId;
    }
  }

  // 2. If currentStoreId is invalid (e.g. user was kicked), fallback to first available storeId
  if (user.storeIds.isNotEmpty) {
    return user.storeIds.first;
  }

  // 3. Fallback to loaded stores list if available
  final stores = ref.watch(userStoresProvider).valueOrNull;
  if (stores != null && stores.isNotEmpty) {
    return stores.first.id;
  }
  return null;
});

final currentStoreProvider = StreamProvider<StoreModel?>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value(null);
  final repo = ref.watch(storeRepositoryProvider);
  return repo.watchStore(storeId);
});

final userStoresProvider = StreamProvider<List<StoreModel>>((ref) async* {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    yield [];
    return;
  }
  // Re-evaluate automatically when user document changes
  ref.watch(currentUserProvider);
  final repo = ref.watch(storeRepositoryProvider);
  final stores = await repo.getUserStores(uid);
  yield stores;
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
  final store = ref.watch(currentStoreProvider).valueOrNull;
  final list = membersAsync.whenOrNull(
        data: (members) =>
            members.where((m) => m.status == MemberStatus.active).toList(),
      ) ??
      [];
  if (store != null && store.memberOrder.isNotEmpty) {
    list.sort((a, b) {
      final idxA = store.memberOrder.indexOf(a.userId);
      final idxB = store.memberOrder.indexOf(b.userId);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return a.name.compareTo(b.name);
    });
  }
  return list;
});

/// Dedicated direct realtime stream for the current user's membership in active store
final currentMemberStreamProvider = StreamProvider<MemberModel?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final storeId = ref.watch(currentStoreIdProvider);
  if (uid == null || storeId == null || storeId.isEmpty) {
    return Stream.value(null);
  }
  return FirebaseFirestore.instance
      .collection('stores')
      .doc(storeId)
      .collection('members')
      .doc(uid)
      .snapshots()
      .map((snap) {
    if (!snap.exists || snap.data() == null) return null;
    return MemberModel.fromFirestore(snap);
  });
});

final currentMemberProvider = Provider<MemberModel?>((ref) {
  final directMember = ref.watch(currentMemberStreamProvider).valueOrNull;
  if (directMember != null) return directMember;

  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  final members = ref.watch(storeMembersProvider).valueOrNull;
  if (members != null) {
    try {
      return members.firstWhere((m) => m.userId == uid);
    } catch (_) {
      return null;
    }
  }
  return null;
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


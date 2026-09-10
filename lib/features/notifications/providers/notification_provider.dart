import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/app_notification_model.dart';
import '../../../models/member_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../store/providers/store_provider.dart';
import '../repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

/// Stream of notifications for current user in current store
final notificationsStreamProvider = StreamProvider.autoDispose<List<AppNotificationModel>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  final userId = ref.watch(currentUserIdProvider);
  final role = ref.watch(notificationRoleProvider);
  final user = ref.watch(currentUserProvider).valueOrNull;

  if (userId == null) {
    return Stream.value([]);
  }

  final repo = ref.watch(notificationRepositoryProvider);
  
  return repo.watchNotifications(
    storeId ?? '',
    userId,
    role,
    notifyShiftInOut: user?.notifyShiftInOut ?? true,
    limit: ref.watch(notificationPageLimitProvider),
  );
});

/// Stream of unread notification count for current user in current store
final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  final userId = ref.watch(currentUserIdProvider);
  final role = ref.watch(notificationRoleProvider);
  final user = ref.watch(currentUserProvider).valueOrNull;

  if (userId == null) {
    return Stream.value(0);
  }

  final repo = ref.watch(notificationRepositoryProvider);
  return repo.watchUnreadCount(
    storeId ?? '',
    userId,
    role,
    notifyShiftInOut: user?.notifyShiftInOut ?? true,
  );
});

final notificationPageLimitProvider = StateProvider.autoDispose<int>((ref) => 50);

final notificationRoleProvider = Provider<UserRole?>((ref) {
  final store = ref.watch(currentStoreProvider).valueOrNull;
  final member = ref.watch(currentMemberProvider);
  if (store == null || store.isDeleted || store.id != ref.watch(currentStoreIdProvider) || member?.status != MemberStatus.active) return null;
  return member?.role;
});

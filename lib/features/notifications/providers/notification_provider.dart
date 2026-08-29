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
  final member = ref.watch(currentMemberProvider);
  final user = ref.watch(currentUserProvider).valueOrNull;

  if (storeId == null || storeId.isEmpty || userId == null) {
    return Stream.value([]);
  }

  final repo = ref.watch(notificationRepositoryProvider);
  
  // Trigger periodic/lazy check for weekly schedule reminders and birthdays
  repo.checkAndGenerateWeeklyScheduleReminder(storeId);
  repo.checkAndGenerateBirthdayNotifications(storeId);

  return repo.watchNotifications(
    storeId,
    userId,
    member?.role ?? UserRole.employee,
    notifyShiftInOut: user?.notifyShiftInOut ?? true,
  );
});

/// Stream of unread notification count for current user in current store
final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  final userId = ref.watch(currentUserIdProvider);
  final member = ref.watch(currentMemberProvider);
  final user = ref.watch(currentUserProvider).valueOrNull;

  if (storeId == null || storeId.isEmpty || userId == null) {
    return Stream.value(0);
  }

  final repo = ref.watch(notificationRepositoryProvider);
  return repo.watchUnreadCount(
    storeId,
    userId,
    member?.role ?? UserRole.employee,
    notifyShiftInOut: user?.notifyShiftInOut ?? true,
  );
});

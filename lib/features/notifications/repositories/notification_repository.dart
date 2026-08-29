import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/app_notification_model.dart';
import '../../../models/member_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notificationsRef(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('notifications');

  /// Stream of notifications filtered for the specific user & role
  Stream<List<AppNotificationModel>> watchNotifications(
    String storeId,
    String? userId,
    UserRole? role, {
    bool notifyShiftInOut = true,
  }) {
    if (storeId.isEmpty) return Stream.value([]);

    return _notificationsRef(storeId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AppNotificationModel.fromFirestore(doc))
          .where((n) {
            if (!notifyShiftInOut &&
                (n.type == AppNotificationType.checkIn ||
                    n.type == AppNotificationType.checkOut)) {
              return false;
            }
            return n.isRelevantFor(userId, role);
          })
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream of unread notification count
  Stream<int> watchUnreadCount(
    String storeId,
    String? userId,
    UserRole? role, {
    bool notifyShiftInOut = true,
  }) {
    if (storeId.isEmpty || userId == null) return Stream.value(0);

    return watchNotifications(
      storeId,
      userId,
      role,
      notifyShiftInOut: notifyShiftInOut,
    ).map((list) {
      return list.where((n) => !n.isReadByUser(userId)).length;
    });
  }

  /// Mark a single notification as read by user
  Future<void> markAsRead(String storeId, String notificationId, String userId) async {
    if (storeId.isEmpty || notificationId.isEmpty || userId.isEmpty) return;
    try {
      await _notificationsRef(storeId).doc(notificationId).update({
        'readBy': FieldValue.arrayUnion([userId]),
      });
    } catch (_) {}
  }

  /// Mark all relevant notifications as read by user
  Future<void> markAllAsRead(String storeId, String userId, UserRole? role) async {
    if (storeId.isEmpty || userId.isEmpty) return;
    try {
      final snap = await _notificationsRef(storeId).get();

      final batch = _firestore.batch();
      int count = 0;

      for (final doc in snap.docs) {
        final notif = AppNotificationModel.fromFirestore(doc);
        if (notif.isRelevantFor(userId, role) && !notif.isReadByUser(userId)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([userId]),
          });
          count++;
        }
      }

      if (count > 0) {
        await batch.commit();
      }
    } catch (_) {}
  }

  /// Create and send a new notification
  Future<void> sendNotification(String storeId, AppNotificationModel notification) async {
    if (storeId.isEmpty) return;
    try {
      await _notificationsRef(storeId).add(notification.toJson());
    } catch (e) {
      // Don't crash caller if notification fails
    }
  }

  /// Check and generate weekly schedule registration reminder
  Future<void> checkAndGenerateWeeklyScheduleReminder(String storeId) async {
    if (storeId.isEmpty) return;
    try {
      final now = DateTime.now();
      // Only trigger reminder on Thursday or Friday (weekday 4 or 5)
      if (now.weekday != DateTime.thursday && now.weekday != DateTime.friday) return;

      // Calculate upcoming next week's Monday
      final thisMonday = now.subtract(Duration(days: now.weekday - 1));
      final nextMonday = thisMonday.add(const Duration(days: 7));
      final nextWeekStr = '${nextMonday.year}-${nextMonday.month.toString().padLeft(2, '0')}-${nextMonday.day.toString().padLeft(2, '0')}';
      final reminderKey = 'schedule_reg_remind_$nextWeekStr';

      // Check if reminder for this week was already sent
      final existing = await _notificationsRef(storeId)
          .where('routeExtra.reminderKey', isEqualTo: reminderKey)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        // Create reminder for Quản lý & Nhân viên
        await sendNotification(
          storeId,
          AppNotificationModel(
            id: '',
            storeId: storeId,
            title: 'Nhắc nhở: Đăng ký lịch làm tuần tới',
            body: 'Hạn chót đăng ký ca làm việc cho tuần tới ($nextWeekStr) là 23:59 Thứ Sáu. Vui lòng hoàn tất đăng ký sớm!',
            type: AppNotificationType.scheduleRegistrationReminder,
            createdAt: DateTime.now(),
            targetRoles: [
              UserRole.owner,
              UserRole.manager1,
              UserRole.manager2,
              UserRole.legacyManager,
              UserRole.employee,
            ],
            routePath: '/schedule',
            routeExtra: {
              'storeId': storeId,
              'reminderKey': reminderKey,
              'weekStart': nextWeekStr
            },
          ),
        );
      }
    } catch (_) {}
  }

  /// Check and generate birthday notifications for any member of the store (including Owner, Managers, Employees)
  Future<void> checkAndGenerateBirthdayNotifications(String storeId) async {
    if (storeId.isEmpty) return;
    try {
      final now = DateTime.now();
      final membersSnap = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('members')
          .where('status', isEqualTo: 'active')
          .get();

      final activeMembers = membersSnap.docs.map((d) => MemberModel.fromFirestore(d)).toList();

      for (final member in activeMembers) {
        DateTime? birthday = member.birthday;

        // If birthday is not in member doc, lookup user document
        if (birthday == null) {
          try {
            final userDoc = await _firestore.collection('users').doc(member.userId).get();
            if (userDoc.exists && userDoc.data() != null) {
              final bStr = userDoc.data()!['birthday'];
              if (bStr != null) {
                birthday = DateTime.tryParse(bStr.toString());
              }
            }
          } catch (_) {}
        }

        if (birthday != null && birthday.day == now.day && birthday.month == now.month) {
          final birthdayKey = 'birthday_${member.userId}_${now.year}_${now.month}_${now.day}';

          final existing = await _notificationsRef(storeId)
              .where('routeExtra.birthdayKey', isEqualTo: birthdayKey)
              .limit(1)
              .get();

          if (existing.docs.isEmpty) {
            await sendNotification(
              storeId,
              AppNotificationModel(
                id: '',
                storeId: storeId,
                title: '🎂 Hôm nay là sinh nhật của ${member.name}!',
                body: 'Cả cửa hàng hãy cùng gửi những lời chúc mừng tốt đẹp nhất đến ${member.name} (${member.role.label}) nhân ngày sinh nhật hôm nay nhé! 🎉🎈',
                type: AppNotificationType.birthday,
                createdAt: DateTime.now(),
                targetRoles: null, // Broadcast to all roles in store (Owner, Managers, Employees)
                targetUserId: null,
                routePath: null,
                routeExtra: {
                  'storeId': storeId,
                  'birthdayKey': birthdayKey,
                  'memberId': member.userId,
                  'memberName': member.name,
                  'memberRole': member.role.label,
                },
              ),
            );
          }
        }
      }
    } catch (_) {}
  }
}

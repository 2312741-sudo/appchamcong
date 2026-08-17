import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/app_notification_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../store/providers/store_provider.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final storeId = ref.watch(currentStoreIdProvider) ?? '';
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final member = ref.watch(currentMemberProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Thông báo',
          style: GoogleFonts.beVietnamPro(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          notificationsAsync.maybeWhen(
            data: (list) {
              final unreadCount = list.where((n) => !n.isReadByUser(userId)).length;
              if (unreadCount == 0) return const SizedBox();
              return TextButton.icon(
                onPressed: () async {
                  await ref.read(notificationRepositoryProvider).markAllAsRead(
                        storeId,
                        userId,
                        member?.role,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã đánh dấu đọc tất cả thông báo'),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFFC8102E)),
                label: Text(
                  'Đã đọc tất cả',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFC8102E),
                  ),
                ),
              );
            },
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Lỗi tải thông báo: $e',
              textAlign: TextAlign.center,
              style: GoogleFonts.beVietnamPro(color: AppColors.danger),
            ),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8102E).withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_off_rounded,
                        size: 44,
                        color: Color(0xFFC8102E),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Không có thông báo nào',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Các thông báo về lịch làm việc, duyệt thành viên và nhắc nhở ca làm sẽ xuất hiện tại đây.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final isRead = notif.isReadByUser(userId);

              return _NotificationCard(
                notification: notif,
                isRead: isRead,
                onTap: () async {
                  if (!isRead) {
                    await ref
                        .read(notificationRepositoryProvider)
                        .markAsRead(storeId, notif.id, userId);
                  }

                  if (notif.routePath != null && notif.routePath!.isNotEmpty && context.mounted) {
                    if (notif.routeExtra != null) {
                      context.push(notif.routePath!, extra: notif.routeExtra);
                    } else {
                      context.push(notif.routePath!);
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotificationModel notification;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeConfig = _getTypeConfig(notification.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? Colors.black.withOpacity(0.06) : const Color(0xFFC8102E).withOpacity(0.3),
              width: isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isRead ? Colors.black.withOpacity(0.02) : const Color(0xFFC8102E).withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeConfig.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeConfig.icon, color: typeConfig.color, size: 22),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 14.5,
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              color: isRead ? const Color(0xFF2C3E50) : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFC8102E),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        color: isRead ? Colors.grey.shade600 : const Color(0xFF333333),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(notification.createdAt),
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 11.5,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (notification.routePath != null && notification.routePath!.isNotEmpty) ...[
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                'Xem chi tiết',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 11.5,
                                  color: typeConfig.color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, size: 14, color: typeConfig.color),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24 && now.day == time.day) {
      return 'Hôm nay ${DateFormat('HH:mm').format(time)}';
    } else if (diff.inDays < 2) {
      return 'Hôm qua ${DateFormat('HH:mm').format(time)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(time);
    }
  }

  _TypeConfig _getTypeConfig(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.joinRequest:
        return const _TypeConfig(Icons.person_add_rounded, Color(0xFFC8102E));
      case AppNotificationType.joinApproved:
        return const _TypeConfig(Icons.check_circle_rounded, Color(0xFF1A6B5A));
      case AppNotificationType.joinRejected:
        return const _TypeConfig(Icons.cancel_rounded, Color(0xFFC8102E));
      case AppNotificationType.advanceRequest:
        return const _TypeConfig(Icons.account_balance_wallet_rounded, Color(0xFFB8860B));
      case AppNotificationType.advanceApproved:
        return const _TypeConfig(Icons.payments_rounded, Color(0xFF1A6B5A));
      case AppNotificationType.advanceRejected:
        return const _TypeConfig(Icons.money_off_rounded, Color(0xFFC8102E));
      case AppNotificationType.scheduleChanged:
        return const _TypeConfig(Icons.calendar_month_rounded, Color(0xFF1C4E6B));
      case AppNotificationType.scheduleRegistrationReminder:
        return const _TypeConfig(Icons.alarm_rounded, Color(0xFFD97706));
      case AppNotificationType.checklistReminder:
        return const _TypeConfig(Icons.assignment_late_rounded, Color(0xFFEA580C));
      case AppNotificationType.deliveryUpdate:
        return const _TypeConfig(Icons.local_shipping_rounded, Color(0xFF7B1FA2));
      case AppNotificationType.birthday:
        return const _TypeConfig(Icons.cake_rounded, Color(0xFFE91E63));
      case AppNotificationType.general:
        return const _TypeConfig(Icons.notifications_rounded, Color(0xFF475569));
    }
  }
}

class _TypeConfig {
  final IconData icon;
  final Color color;
  const _TypeConfig(this.icon, this.color);
}

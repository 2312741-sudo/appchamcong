import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  factory EmptyState.attendance({VoidCallback? onRefresh}) {
    return EmptyState(
      icon: Icons.event_busy_rounded,
      message: 'Chưa có dữ liệu chấm công',
      subtitle: 'Dữ liệu chấm công sẽ xuất hiện ở đây',
      actionLabel: onRefresh != null ? 'Làm mới' : null,
      onAction: onRefresh,
    );
  }

  factory EmptyState.members({VoidCallback? onAdd}) {
    return EmptyState(
      icon: Icons.group_outlined,
      message: 'Chưa có nhân viên nào',
      subtitle: 'Mời nhân viên tham gia bằng mã hoặc mã QR',
      actionLabel: onAdd != null ? 'Mời nhân viên' : null,
      onAction: onAdd,
    );
  }

  factory EmptyState.schedule({VoidCallback? onCreate}) {
    return EmptyState(
      icon: Icons.calendar_month_outlined,
      message: 'Chưa có lịch làm việc',
      subtitle: 'Tạo lịch làm việc cho tuần này',
      actionLabel: onCreate != null ? 'Tạo lịch' : null,
      onAction: onCreate,
    );
  }

  factory EmptyState.salary({VoidCallback? onCalculate}) {
    return EmptyState(
      icon: Icons.calculate_outlined,
      message: 'Chưa có dữ liệu lương',
      subtitle: 'Tính lương cho tháng này',
      actionLabel: onCalculate != null ? 'Tính lương' : null,
      onAction: onCalculate,
    );
  }

  factory EmptyState.search() {
    return const EmptyState(
      icon: Icons.search_off_rounded,
      message: 'Không tìm thấy kết quả',
      subtitle: 'Thử tìm kiếm với từ khóa khác',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: AppColors.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 44),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

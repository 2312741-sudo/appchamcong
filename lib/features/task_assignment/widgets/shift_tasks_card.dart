import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/task_assignment_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../store/providers/store_provider.dart';
import '../providers/task_provider.dart';
import '../screens/task_report_screen.dart';

/// Thẻ hiển thị trên Dashboard ca làm việc:
/// - Lấy danh sách task của ngày hôm nay áp dụng cho user hiện tại (todayUserTasksProvider)
/// - Hiển thị tiến độ: ví dụ "Công việc trong ca hôm nay: 2/3 hoàn thành" kèm Progress Indicator
/// - Danh sách tóm tắt các việc trong ca, icon trạng thái (đã hoàn thành xanh lá, chưa hoàn thành cam)
/// - Bấm vào từng việc mở TaskReportScreen để xem/báo cáo ngay
class ShiftTasksCard extends ConsumerWidget {
  final String? storeId;
  final String? userId;
  final String? dateStr; // YYYY-MM-DD
  final VoidCallback? onTasksChanged;

  const ShiftTasksCard({
    super.key,
    this.storeId,
    this.userId,
    this.dateStr,
    this.onTasksChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveStoreId = storeId ?? ref.watch(currentStoreIdProvider) ?? '';
    final effectiveUserId = userId ?? ref.watch(currentUserIdProvider) ?? '';

    if (effectiveStoreId.isEmpty || effectiveUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final effectiveDateStr = dateStr ??
        '${vnNow.year}-${vnNow.month.toString().padLeft(2, '0')}-${vnNow.day.toString().padLeft(2, '0')}';

    final params = (
      storeId: effectiveStoreId,
      userId: effectiveUserId,
      dateStr: effectiveDateStr,
    );

    final tasksAsync = ref.watch(todayUserTasksProvider(params));
    final unfinishedAsync = ref.watch(unfinishedUserTasksProvider(params));

    return tasksAsync.when(
      loading: () => _buildLoadingCard(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tasks) {
        if (tasks.isEmpty) {
          return _buildEmptyCard();
        }

        final unfinishedTasks = unfinishedAsync.valueOrNull ?? [];
        final unfinishedIds = unfinishedTasks.map((t) => t.id).toSet();

        final totalCount = tasks.length;
        final unfinishedCount = unfinishedTasks.length;
        final completedCount = (totalCount - unfinishedCount).clamp(0, totalCount);
        final progress = totalCount > 0 ? (completedCount / totalCount) : 1.0;
        final isAllDone = completedCount == totalCount;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAllDone
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.cardOutline,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Badge tiến độ
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isAllDone
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isAllDone
                          ? Icons.task_alt_rounded
                          : Icons.assignment_turned_in_rounded,
                      color: isAllDone ? AppColors.success : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Công việc trong ca hôm nay',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'BeVietnamPro',
                        color: AppColors.neutral,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAllDone
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAllDone
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '$completedCount/$totalCount hoàn thành',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'BeVietnamPro',
                        color: isAllDone ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.paperInk,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isAllDone ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Danh sách tóm tắt các việc trong ca
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tasks.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.divider, height: 16),
                itemBuilder: (ctx, index) {
                  final AssignedTask task = tasks[index];
                  final isDone = !unfinishedIds.contains(task.id);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final res = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskReportScreen(
                            task: task,
                            workDate: effectiveDateStr,
                          ),
                        ),
                      );
                      if (res == true || ctx.mounted) {
                        ref.invalidate(todayUserTasksProvider(params));
                        ref.invalidate(unfinishedUserTasksProvider(params));
                        onTasksChanged?.call();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          Icon(
                            isDone
                                ? Icons.check_circle_rounded
                                : Icons.pending_actions_rounded,
                            color: isDone
                                ? AppColors.success
                                : AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'BeVietnamPro',
                                    color: isDone
                                        ? AppColors.textSecondary
                                        : AppColors.neutral,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (task.createdByName.isNotEmpty) ...[
                                      Text(
                                        'Giao bởi: ${task.createdByName}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                          fontFamily: 'BeVietnamPro',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (task.requirePhoto)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3E0),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.camera_alt_rounded,
                                                size: 10,
                                                color: Color(0xFFE65100)),
                                            SizedBox(width: 3),
                                            Text(
                                              'Cần ảnh',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFE65100),
                                                fontFamily: 'BeVietnamPro',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textDisabled,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardOutline, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Công việc trong ca',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'BeVietnamPro',
                    color: AppColors.neutral,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Hôm nay bạn không có công việc được phân công',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    fontFamily: 'BeVietnamPro',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardOutline, width: 1.2),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

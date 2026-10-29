import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/supply_date_utils.dart';
import '../../../core/utils/department_utils.dart';
import '../../schedule/providers/schedule_provider.dart';
import '../../store/providers/store_provider.dart';
import '../providers/supply_order_provider.dart';
import '../repositories/supply_order_repository.dart';
import '../supply_reminder_service.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../screens/supply_order_screen.dart';

/// Thẻ trên Dashboard: hàng cần soạn hôm nay (tích "Đã soạn") + lối tắt đặt hàng ngày mai.
class SupplyChecklistCard extends ConsumerWidget {
  const SupplyChecklistCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = SupplyDateUtils.today();
    final tomorrow = SupplyDateUtils.tomorrow();
    final todayOrder = ref.watch(supplyOrderProvider(today)).valueOrNull;
    final tomorrowOrder = ref.watch(supplyOrderProvider(tomorrow)).valueOrNull;

    void open(String date) => Navigator.push(context, MaterialPageRoute(builder: (_) => SupplyOrderScreen(initialDate: date)));

    final total = todayOrder?.lines.length ?? 0;
    final done = todayOrder?.preparedCount ?? 0;
    final allDone = todayOrder?.isAllPrepared ?? false;
    final tomorrowCount = tomorrowOrder?.lines.length ?? 0;
    final settings = ref.watch(supplySettingsProvider).valueOrNull;
    final assigned = (settings?.preparerDepartmentIds.isNotEmpty ?? false) && ref.watch(isSupplyPreparerProvider(today));

    // Nhắc đặt hàng trước giờ chốt: đang trong ca + phiếu ngày mai còn trống
    final active = ref.watch(todayAttendanceProvider).valueOrNull;
    if (settings != null && tomorrowOrder != null) {
      final onShift = active != null && active.checkOut == null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SupplyReminderService.instance.sync(
          cutoff: settings.cutoffTime,
          onShift: onShift,
          tomorrowEmpty: tomorrowOrder.isEmpty,
        );
      });
    }
    final cutoffText = SupplyDateUtils.cutoffLabel(tomorrow, settings?.cutoffTime);
    final orderLocked = SupplyDateUtils.isOrderLocked(tomorrow, settings?.cutoffTime);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Đặt & soạn hàng', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w800, fontSize: 15))),
        ]),
        if (assigned && total > 0 && !allDone) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text('🧺 Bạn được phân công soạn hàng hôm nay',
                style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 10),
        InkWell(
          onTap: () => open(today),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(total == 0 ? Icons.inbox_outlined : (allDone ? Icons.check_circle : Icons.pending_actions_rounded),
                  color: total == 0 ? AppColors.textDisabled : (allDone ? AppColors.success : AppColors.warning)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  total == 0
                      ? 'Hôm nay không có hàng cần soạn'
                      : (allDone ? 'Hôm nay: đã soạn đủ $total món' : 'Hôm nay cần soạn: $done/$total món đã soạn'),
                  style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600),
                ),
              ),
              if (total > 0) const Icon(Icons.chevron_right),
            ]),
          ),
        ),
        if (total > 0) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: done / total,
            minHeight: 5,
            backgroundColor: AppColors.paperInk,
            color: allDone ? AppColors.success : AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => open(tomorrow),
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: Text(tomorrowCount == 0 ? 'Đặt hàng cho ngày mai' : 'Ngày mai: $tomorrowCount món đã đặt — thêm / xem'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
          ),
        ),
        if (cutoffText != null) ...[
          const SizedBox(height: 6),
          Text(orderLocked ? 'Đã chốt đặt hàng ngày mai ($cutoffText)' : 'Chốt đặt hàng lúc $cutoffText',
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: orderLocked ? AppColors.danger : AppColors.textSecondary)),
        ],
      ]),
    );
  }
}

/// Sau khi chấm công VÀO: nếu người này là người soạn hàng hôm nay (theo bộ phận trong lịch làm)
/// và phiếu hôm nay còn món chưa soạn → hỏi "Soạn hàng ngay?".
Future<void> promptSupplyPrepAfterCheckIn(BuildContext context, WidgetRef ref) async {
  final storeId = ref.read(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return;
  final today = SupplyDateUtils.today();
  try {
    final SupplyOrderRepository repo = ref.read(supplyOrderRepositoryProvider);
    final order = await repo.watchOrder(storeId, today).first;
    if (order.isEmpty || order.isAllPrepared) return;
    // Chờ cài đặt và lịch tuần tải xong rồi mới xét bộ phận soạn hàng
    await ref.read(supplySettingsProvider.future);
    await ref.read(weekScheduleProvider(DepartmentUtils.getMondayOfWeek(today)).future);
    if (!ref.read(isSupplyPreparerProvider(today))) return;
    if (!context.mounted) return;
    final remaining = order.lines.length - order.preparedCount;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Soạn hàng hôm nay'),
        content: Text('Bạn được phân công soạn hàng. Còn $remaining/${order.lines.length} món chưa soạn. Soạn ngay?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Để sau')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Soạn ngay'),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SupplyOrderScreen(initialDate: today)));
    }
  } catch (_) {
    // Không chặn chấm công nếu tải phiếu lỗi
  }
}

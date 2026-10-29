import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/supply_date_utils.dart';
import '../providers/supply_order_provider.dart';
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
      ]),
    );
  }
}

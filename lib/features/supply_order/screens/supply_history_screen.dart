import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/supply_date_utils.dart';
import '../providers/supply_order_provider.dart';
import '../../store/providers/store_provider.dart';
import '../supply_export.dart';
import 'supply_order_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/supply_error_view.dart';

/// Lịch sử phiếu đặt / soạn hàng theo ngày
class SupplyHistoryScreen extends ConsumerWidget {
  const SupplyHistoryScreen({super.key});

  /// Chọn tháng rồi xuất Excel toàn bộ phiếu trong tháng
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    final now = SupplyDateUtils.vnNow();
    final months = [for (var i = 0; i < 3; i++) DateTime.utc(now.year, now.month - i, 1)];
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Xuất Excel tháng', style: TextStyle(fontWeight: FontWeight.bold))),
          for (final m in months)
            ListTile(
              leading: const Icon(LucideIcons.calendarDays),
              title: Text('Tháng ${m.month}/${m.year}'),
              onTap: () => Navigator.pop(ctx, m),
            ),
        ]),
      ),
    );
    if (picked == null) return;
    final from = SupplyDateUtils.ymd(picked);
    final to = SupplyDateUtils.ymd(DateTime.utc(picked.year, picked.month + 1, 0));
    try {
      final orders = await ref.read(supplyOrderRepositoryProvider).getOrdersInRange(storeId, from, to);
      if (orders.isEmpty) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tháng này chưa có phiếu nào')));
        return;
      }
      if (!context.mounted) return;
      await SupplyExport.exportToExcel(
        orders,
        fromDate: from,
        toDate: to,
        storeName: ref.read(currentStoreProvider).valueOrNull?.name ?? '',
        context: context,
      );
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xuất file: ${supplyErrorMessage(e)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(recentSupplyOrdersProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch sử đặt & soạn hàng', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        // Theme chung đặt màu chữ/icon AppBar cố định → phải ghi rõ để nền màu dùng chữ trắng
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        actions: [
          IconButton(tooltip: 'Xuất Excel', icon: const Icon(LucideIcons.download), onPressed: () => _export(context, ref)),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SupplyErrorView(e),
        data: (orders) {
          final list = orders.where((o) => !o.isEmpty).toList();
          if (list.isEmpty) {
            return Center(child: Text('Chưa có phiếu nào', style: GoogleFonts.beVietnamPro(color: AppColors.textSecondary)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final o = list[i];
              final names = <String>{for (final l in o.lines) ...l.contributorNames};
              return Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: ListTile(
                  leading: Icon(o.isAllPrepared ? LucideIcons.circleCheck : LucideIcons.clipboardClock,
                      color: o.isAllPrepared ? AppColors.success : AppColors.warning),
                  title: Text(SupplyDateUtils.label(o.date), style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
                  subtitle: Text('${o.lines.length} món • đã soạn ${o.preparedCount}/${o.lines.length}'
                      '${names.isEmpty ? "" : "\nĐặt bởi: ${names.join(", ")}"}'),
                  isThreeLine: names.isNotEmpty,
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupplyOrderScreen(initialDate: o.date))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

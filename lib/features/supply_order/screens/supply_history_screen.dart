import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/supply_date_utils.dart';
import '../providers/supply_order_provider.dart';
import 'supply_order_screen.dart';

/// Lịch sử phiếu đặt / soạn hàng theo ngày
class SupplyHistoryScreen extends ConsumerWidget {
  const SupplyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(recentSupplyOrdersProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch sử đặt & soạn hàng', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
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
                  leading: Icon(o.isAllPrepared ? Icons.check_circle : Icons.pending_actions_rounded,
                      color: o.isAllPrepared ? AppColors.success : AppColors.warning),
                  title: Text(SupplyDateUtils.label(o.date), style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
                  subtitle: Text('${o.lines.length} món • đã soạn ${o.preparedCount}/${o.lines.length}'
                      '${names.isEmpty ? "" : "\nĐặt bởi: ${names.join(", ")}"}'),
                  isThreeLine: names.isNotEmpty,
                  trailing: const Icon(Icons.chevron_right),
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

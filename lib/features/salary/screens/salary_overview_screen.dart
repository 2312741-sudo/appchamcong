import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../store/providers/store_provider.dart';
import '../providers/salary_provider.dart';
import '../../../models/advance_request_model.dart';

class SalaryOverviewScreen extends ConsumerWidget {
  const SalaryOverviewScreen({super.key});

  void _selectMonth(BuildContext context, WidgetRef ref) async {
    // Simple month picker using dialog (for simplicity, or we can just use showDatePicker focusing on month)
    final now = DateTime.now();
    final firstDate = DateTime(2020);
    
    final currentStr = ref.read(selectedSalaryMonthProvider);
    final currentParts = currentStr.split('-');
    DateTime initialDate = now;
    if (currentParts.length == 2) {
      initialDate = DateTime(int.tryParse(currentParts[0]) ?? now.year, int.tryParse(currentParts[1]) ?? now.month);
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white, onSurface: AppColors.neutral),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      ref.read(selectedSalaryMonthProvider.notifier).state = formatted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeId = ref.watch(currentStoreIdProvider);
    final monthStr = ref.watch(selectedSalaryMonthProvider); // YYYY-MM

    if (storeId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final membersAsync = ref.watch(allActiveMembersProvider(storeId));
    final salariesAsync = ref.watch(allSalariesProvider(monthStr));
    
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Báo cáo Lương', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Tháng: $monthStr', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: () => _selectMonth(context, ref),
                    child: Text('Chọn tháng', style: GoogleFonts.beVietnamPro()),
                  ),
                ],
              ),
            ),
          Expanded(
            child: membersAsync.when(
              data: (members) {
                if (members.isEmpty) return const Center(child: Text('Chưa có nhân viên nào'));
                return salariesAsync.when(
                  data: (salaries) {
                    final deliveryCountsAsync = ref.watch(allMonthlyDeliveryCountsProvider(monthStr));
                    final storeAsync = ref.watch(currentStoreProvider);
                    final advancesAsync = ref.watch(storeAdvancesProvider(monthStr));

                    return deliveryCountsAsync.when(
                      data: (deliveryCounts) => storeAsync.when(
                        data: (store) => advancesAsync.when(
                          data: (advances) {
                            final deliveryAllowance = (store?.deliveryAllowance ?? 0).toDouble();

                            // Calculate actual net salary payout
                            double totalPayout = 0;
                            final netSalaries = <String, double>{};
                            final advanceTotals = <String, double>{};

                            for (final member in members) {
                              final baseSalary = salaries[member.userId] ?? 0.0;
                              final totalAdvance = advances
                                  .where((a) => a.userId == member.userId && a.status == AdvanceStatus.approved)
                                  .fold(0.0, (sum, a) => sum + a.amount);
                              
                              final netSalary = baseSalary - totalAdvance;
                              
                              netSalaries[member.userId] = netSalary;
                              advanceTotals[member.userId] = totalAdvance;
                              totalPayout += netSalary;
                            }

                            return CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildSummaryCard(totalPayout, currencyFormat),
                                        const SizedBox(height: 24),
                                        Text('Chi tiết từng nhân viên', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (ctx, i) {
                                        final member = members[i];
                                        final salary = salaries[member.userId] ?? 0.0;
                                        final deliveryCount = deliveryCounts[member.userId] ?? 0;
                                        final advanceTotal = advanceTotals[member.userId] ?? 0.0;
                                        final netSalary = netSalaries[member.userId] ?? 0.0;
                                        
                                        return _buildSalaryCard(member, salary, deliveryCount, deliveryAllowance, advanceTotal, netSalary, currencyFormat);
                                      },
                                      childCount: members.length,
                                    ),
                                  ),
                                ),
                                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                              ],
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text('Lỗi tải dữ liệu ứng lương: $e')),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, st) => Center(child: Text('Lỗi tải dữ liệu: $e')),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Lỗi tải dữ liệu: $e')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Lỗi tính lương: $e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Lỗi: $err')),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSummaryCard(double total, NumberFormat currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tổng chi trả lương thực tế', style: TextStyle(color: Colors.white70)),
          Text(currencyFormat.format(total), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSalaryCard(MemberModel member, double salary, int deliveryCount, double deliveryAllowance, double advanceTotal, double netSalary, NumberFormat currencyFormat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surface,
                child: Text(member.initials, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(member.isFulltime ? 'Full-time' : 'Part-time', style: GoogleFonts.beVietnamPro(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text(
                currencyFormat.format(netSalary),
                style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng lương thu nhập', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      currencyFormat.format(salary),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (advanceTotal > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Đã tạm ứng', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        '-${currencyFormat.format(advanceTotal)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/member_model.dart';
import '../../store/providers/store_provider.dart';
import '../providers/salary_provider.dart';

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
        child: ListView(
          children: [
            // Month Picker
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
                      Text(
                        'Tháng: $monthStr',
                        style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.neutral),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: () => _selectMonth(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Chọn tháng', style: TextStyle(fontFamily: 'BeVietnamPro')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            membersAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(32), child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primary)))),
              error: (err, _) => Padding(padding: const EdgeInsets.all(32), child: SizedBox(height: 100, child: Center(child: Text('Lỗi: $err')))),
              data: (members) {
                if (members.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(32), child: SizedBox(height: 100, child: Center(child: Text('Cửa hàng chưa có nhân viên nào.', style: TextStyle(fontFamily: 'BeVietnamPro')))));
                }

                return salariesAsync.when(
                  loading: () => const Padding(padding: EdgeInsets.all(32), child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primary)))),
                  error: (err, _) => Padding(padding: const EdgeInsets.all(32), child: SizedBox(height: 100, child: Center(child: Text('Lỗi: $err')))),
                  data: (salaries) {
                    // Calculate total payout
                    final totalPayout = salaries.values.fold(0.0, (sum, val) => sum + val);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Summary Card
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(Icons.payments_rounded, color: Colors.white, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tổng chi trả lương', style: TextStyle(fontFamily: 'BeVietnamPro', color: Colors.white70, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(
                                      currencyFormat.format(totalPayout),
                                      style: const TextStyle(fontFamily: 'BeVietnamPro', color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // List of employees
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: members.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final salary = salaries[member.userId] ?? 0.0;
                            
                            // Create an inline consumer for total hours
                            return Consumer(
                              builder: (context, ref, _) {
                                final hoursAsync = ref.watch(monthTotalHoursProvider((userId: member.userId, month: monthStr)));
                                final totalHours = hoursAsync.valueOrNull ?? 0.0;
                                
                                return _buildSalaryCard(member, totalHours, salary, currencyFormat);
                              }
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryCard(MemberModel member, double totalHours, double salary, NumberFormat currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(member.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.neutral)),
                    const SizedBox(height: 2),
                    Text(
                      member.employeeType.shortLabel,
                      style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                currencyFormat.format(salary),
                style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tổng số giờ', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text('${totalHours.toStringAsFixed(1)}h', style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Mức thiết lập', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    member.isFulltime ? '${currencyFormat.format(member.baseMonthlySalary)} /tháng' : '${currencyFormat.format(member.baseHourlyRate)} /giờ',
                    style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

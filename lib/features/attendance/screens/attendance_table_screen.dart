import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/export_utils.dart';
import '../../../models/attendance_model.dart';
import '../../../models/member_model.dart';
import '../../store/providers/store_provider.dart';
import '../../salary/providers/salary_provider.dart';
import '../repositories/attendance_repository.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final dailyAttendancesProvider = StreamProvider.family<List<AttendanceModel>, DateTime>((ref, date) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value([]);
  final repo = ref.watch(attendanceRepositoryProvider);
  
  final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  return repo.watchAllAttendances(storeId, dateString);
});

class AttendanceTableScreen extends ConsumerWidget {
  const AttendanceTableScreen({super.key});

  Future<void> _selectDate(BuildContext context, WidgetRef ref) async {
    final current = ref.read(selectedDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: AppColors.neutral, // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final attendancesAsync = ref.watch(dailyAttendancesProvider(selectedDate));
    final storeId = ref.watch(currentStoreIdProvider);
    
    // Use storeMembersProvider which returns an AsyncValue
    final membersAsync = ref.watch(storeMembersProvider);

    final dateStr = DateFormat('dd/MM/yyyy').format(selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('Bảng công', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Xuất Excel Tháng',
            onPressed: () async {
              final membersData = membersAsync.valueOrNull;
              if (storeId != null && membersData != null) {
                final activeMembers = membersData.where((m) => m.status == MemberStatus.active).toList();
                try {
                  final repo = ref.read(salaryRepositoryProvider);
                  await ExportUtils.exportMonthlyAttendanceToExcel(
                    storeId,
                    selectedDate,
                    activeMembers,
                    repo,
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi xuất file: $e'), backgroundColor: AppColors.primary),
                    );
                  }
                }
              }
            },
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.salaryOverview),
            child: const Text('Báo cáo Lương', style: TextStyle(color: Colors.white, fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            // Header / Date Picker
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Ngày: $dateStr',
                        style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.neutral),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: () => _selectDate(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Chọn ngày', style: TextStyle(fontFamily: 'BeVietnamPro')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // List of ALL members
            membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32.0),
                child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(32.0),
                child: SizedBox(height: 100, child: Center(child: Text('Lỗi tải nhân viên: $err'))),
              ),
              data: (allMembers) {
                final members = allMembers.where((m) => m.status == MemberStatus.active).toList();
                
                if (members.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: SizedBox(height: 100, child: Center(
                      child: Text(
                        'Cửa hàng chưa có nhân viên nào.',
                        style: TextStyle(fontFamily: 'BeVietnamPro', color: AppColors.textSecondary),
                      ),
                    )),
                  );
                }

                return attendancesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: SizedBox(height: 100, child: Center(child: Text('Lỗi tải chấm công: $err'))),
                  ),
                  data: (attendances) {
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final name = member.name;
                        final initials = member.initials;
                        
                        // Find attendance for this member
                        final att = attendances.where((a) => a.userId == member.userId).firstOrNull;

                        return _buildAttendanceCard(att, name, initials);
                      },
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

  Widget _buildAttendanceCard(AttendanceModel? att, String name, String initials) {
    final checkInStr = att != null ? DateFormat('HH:mm').format(att.checkIn.toLocal()) : '--:--';
    final checkOutStr = (att != null && att.checkOut != null) ? DateFormat('HH:mm').format(att.checkOut!.toLocal()) : '--:--';
    final durationStr = att != null ? att.formattedDuration : '0h';
    final hasCheckedIn = att != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.neutral),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTimeBadge('Vào', checkInStr, hasCheckedIn ? AppColors.success : AppColors.textSecondary),
                    const SizedBox(width: 12),
                    _buildTimeBadge('Ra', checkOutStr, AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Số giờ', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12, color: AppColors.textSecondary)),
              Text(
                durationStr,
                style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.w700, color: hasCheckedIn ? AppColors.primary : AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBadge(String label, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          Text(time, style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 13, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

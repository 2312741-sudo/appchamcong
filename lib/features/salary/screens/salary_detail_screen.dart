import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/attendance_model.dart';
import '../../../models/member_model.dart';
import '../../../models/advance_request_model.dart';
import '../../store/providers/store_provider.dart';
import '../providers/salary_provider.dart';

class SalaryDetailScreen extends ConsumerStatefulWidget {
  const SalaryDetailScreen({super.key});

  @override
  ConsumerState<SalaryDetailScreen> createState() =>
      _SalaryDetailScreenState();
}

class _SalaryDetailScreenState extends ConsumerState<SalaryDetailScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  String get _monthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  String _formatCurrency(double amount) {
    final n = amount.round();
    final formatted = NumberFormat('#,###', 'vi_VN')
        .format(n)
        .replaceAll(',', '.');
    return '$formatted ₫';
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) {
        DateTime temp = _selectedMonth;
        return AlertDialog(
          title: Text('Chọn tháng',
              style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
          content: SizedBox(
            height: 200,
            width: 280,
            child: YearPicker(
              firstDate: DateTime(now.year - 2),
              lastDate: now,
              selectedDate: temp,
              onChanged: (d) {
                setState(() {
                  _selectedMonth = DateTime(d.year, d.month);
                });
                Navigator.pop(ctx);
              },
            ),
          ),
        );
      },
    );
  }

  void _showAdvanceRequestModal(BuildContext context, String storeId, String userId) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xin ứng lương', style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tiền muốn ứng (VNĐ)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Lý do (không bắt buộc)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')));
                    return;
                  }
                  
                  final request = AdvanceRequestModel(
                    id: '', // Firestore auto-generates if we don't pass id, wait, in toMap we don't pass id.
                    storeId: storeId,
                    userId: userId,
                    month: _monthKey,
                    amount: amount,
                    status: AdvanceStatus.pending,
                    requestDate: DateTime.now(),
                    note: noteCtrl.text.trim(),
                  );
                  
                  try {
                    await ref.read(storeRepositoryProvider).createAdvanceRequest(request);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu ứng lương thành công'), backgroundColor: AppColors.success));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger));
                    }
                  }
                },
                child: Text('Gửi yêu cầu', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(myMemberDataProvider);
    final salaryAsync = ref.watch(myMonthlySalaryProvider(_monthKey));
    final hoursAsync = ref.watch(monthTotalHoursProvider(
        (userId: '', month: _monthKey)));
    final attendancesAsync =
        ref.watch(myMonthAttendancesProvider(_monthKey));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: GestureDetector(
          onTap: _pickMonth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lương Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                style: GoogleFonts.beVietnamPro(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
        ),
        elevation: 0,
      ),
      body: memberAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (member) {
          if (member == null) return const Center(child: Text('Không tìm thấy thông tin nhân viên'));
          return salaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi tải lương: $e')),
            data: (salary) => attendancesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi tải bảng công: $e')),
              data: (attendances) {
                final deliveryCountAsync = ref.watch(myMonthlyDeliveryCountProvider(_monthKey));
                final storeAsync = ref.watch(currentStoreProvider);
                
                return deliveryCountAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
                  data: (deliveryCount) => storeAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
                    data: (store) {
                      final advancesAsync = ref.watch(myAdvancesProvider(_monthKey));
                      
                      final totalHours = attendances.fold(0.0, (sum, a) => sum + a.totalHours);
                      final deliveryAllowance = (store?.deliveryAllowance ?? 0).toDouble();

                      final totalAdvance = advancesAsync.where((a) => a.status == AdvanceStatus.approved).fold(0.0, (sum, a) => sum + a.amount);
                      final hasPending = advancesAsync.any((a) => a.status == AdvanceStatus.pending);

                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(myMonthlySalaryProvider);
                          ref.invalidate(myMonthAttendancesProvider);
                          ref.invalidate(myMonthlyDeliveryCountProvider);
                          ref.invalidate(myAdvancesProvider);
                          ref.invalidate(currentStoreProvider);
                        },
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildSalaryCard(member, salary, totalHours, deliveryCount, deliveryAllowance, totalAdvance),
                            const SizedBox(height: 16),
                            if (hasPending)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Color(0xFF856404), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('Bạn đang có yêu cầu ứng lương chờ duyệt.', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF856404))),
                                    ),
                                  ],
                                ),
                              ),
                            _buildStatsRow(
                              attendances.where((a) => a.totalHours > 0).map((a) => a.date).toSet().length,
                              totalHours,
                              (DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month) - attendances.where((a) => a.totalHours > 0).map((a) => a.date).toSet().length).clamp(0, 31),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.money),
                                label: const Text('Xin ứng lương'),
                                onPressed: () => _showAdvanceRequestModal(context, ref.read(currentStoreIdProvider)!, member.userId),
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDailyBreakdown(attendances),
                          ],
                        ),
                      );
                    }
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalaryCard(
      MemberModel member, double salary, double totalHours, int deliveryCount, double deliveryAllowance, double totalAdvance) {
    final standardHours = member.standardHoursPerMonth;
    final progress = standardHours > 0 ? (totalHours / standardHours).clamp(0.0, 1.0) : 0.0;
    final netSalary = salary - totalAdvance;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A6B5A), Color(0xFF0D4A3D)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thực nhận tháng này', style: GoogleFonts.beVietnamPro(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(_formatCurrency(netSalary), style: GoogleFonts.beVietnamPro(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng thu nhập:', style: TextStyle(color: Colors.white70)),
              Text(
                _formatCurrency(salary),
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          if (deliveryCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🚚 Chở hàng ($deliveryCount ca):', style: TextStyle(color: Colors.white70)),
                Text(
                  '+${_formatCurrency(deliveryCount * deliveryAllowance)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent),
                ),
              ],
            ),
          ],
          if (totalAdvance > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Đã tạm ứng:', style: TextStyle(color: Colors.white70)),
                Text(
                  '-${_formatCurrency(totalAdvance)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% giờ chuẩn',
            style: GoogleFonts.beVietnamPro(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int workedDays, double totalHours, int absentDays) {
    return Row(
      children: [
        _StatCard(label: 'Ngày làm', value: '$workedDays ngày', icon: Icons.today),
        const SizedBox(width: 10),
        _StatCard(label: 'Tổng giờ', value: '${totalHours.toStringAsFixed(1)}h', icon: Icons.access_time),
        const SizedBox(width: 10),
        _StatCard(label: 'Ngày vắng', value: '$absentDays ngày', icon: Icons.event_busy, isAlert: absentDays > 0),
      ],
    );
  }

  Widget _buildDailyBreakdown(List<AttendanceModel> attendances) {
    if (attendances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text('Chưa có dữ liệu chấm công tháng này', style: GoogleFonts.beVietnamPro(color: AppColors.textSecondary, fontSize: 14))),
      );
    }

    final sorted = List<AttendanceModel>.from(attendances)..sort((a, b) => a.date.compareTo(b.date));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Chi tiết ngày làm', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          const Divider(height: 1),
          ...sorted.asMap().entries.map((entry) => _AttendanceRow(attendance: entry.value, isLast: entry.key == sorted.length - 1)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isAlert;

  const _StatCard({required this.label, required this.value, required this.icon, this.isAlert = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isAlert ? AppColors.primary.withOpacity(0.3) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: isAlert ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: isAlert ? AppColors.primary : AppColors.textPrimary)),
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final AttendanceModel attendance;
  final bool isLast;

  const _AttendanceRow({required this.attendance, required this.isLast});

  String _fmt(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final parts = attendance.date.split('-');
    final day = parts.length == 3 ? parts[2] : '?';
    final month = parts.length == 3 ? parts[1] : '?';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: attendance.totalHours > 0 ? AppColors.success.withOpacity(0.1) : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(day, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 14, color: attendance.totalHours > 0 ? AppColors.success : AppColors.primary)),
                    Text('Th$month', style: GoogleFonts.beVietnamPro(fontSize: 9, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vào: ${_fmt(attendance.checkIn)}  •  Ra: ${_fmt(attendance.checkOut)}', style: GoogleFonts.beVietnamPro(fontSize: 13, color: AppColors.textPrimary)),
                    if (attendance.isEdited) Text('(Đã sửa)', style: GoogleFonts.beVietnamPro(fontSize: 11, color: AppColors.accent)),
                  ],
                ),
              ),
              Text(
                attendance.formattedDuration,
                style: GoogleFonts.beVietnamPro(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: attendance.totalHours > 0 ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/attendance_model.dart';
import '../../../models/member_model.dart';
import '../../store/providers/store_provider.dart';
import '../repositories/attendance_repository.dart';

// ── Providers ───────────────────────────────────────────────────────────────

final monthlyMemberAttendanceProvider =
    StreamProvider.family<List<AttendanceModel>, ({String storeId, String userId, String month})>(
        (ref, args) {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.watchMonthAttendance(args.storeId, args.userId, args.month);
});

// ── Screen ──────────────────────────────────────────────────────────────────

class MonthlyAttendanceScreen extends ConsumerStatefulWidget {
  final String memberId;
  final String memberName;

  const MonthlyAttendanceScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  ConsumerState<MonthlyAttendanceScreen> createState() =>
      _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState
    extends ConsumerState<MonthlyAttendanceScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (nextMonth.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _selectedMonth = nextMonth);
  }

  String get _monthStr =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final storeId = ref.watch(currentStoreIdProvider);
    final currentMember = ref.watch(currentMemberProvider);
    final isOwnerOrManager = currentMember?.isOwner == true ||
        currentMember?.isManager == true;

    if (storeId == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final attendanceAsync = ref.watch(monthlyMemberAttendanceProvider((
      storeId: storeId,
      userId: widget.memberId,
      month: _monthStr,
    )));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.memberName,
                style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const Text('Bảng công tháng',
                style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12,
                    color: Colors.white70)),
          ],
        ),
      ),
      body: attendanceAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (attendances) {
          return _MonthCalendarBody(
            month: _selectedMonth,
            attendances: attendances,
            storeId: storeId,
            memberId: widget.memberId,
            memberName: widget.memberName,
            canEdit: isOwnerOrManager,
            onPrevMonth: _prevMonth,
            onNextMonth: _nextMonth,
          );
        },
      ),
    );
  }
}

// ── Calendar Body ────────────────────────────────────────────────────────────

class _MonthCalendarBody extends StatelessWidget {
  final DateTime month;
  final List<AttendanceModel> attendances;
  final String storeId;
  final String memberId;
  final String memberName;
  final bool canEdit;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  const _MonthCalendarBody({
    required this.month,
    required this.attendances,
    required this.storeId,
    required this.memberId,
    required this.memberName,
    required this.canEdit,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  AttendanceModel? _getAttForDay(int day) {
    final dateStr =
        '${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    try {
      return attendances.firstWhere((a) => a.date == dateStr);
    } catch (_) {
      return null;
    }
  }

  _DayStatus _statusForDay(int day) {
    final today = DateTime.now();
    final isToday = month.year == today.year &&
        month.month == today.month &&
        day == today.day;
    final isPast = DateTime(month.year, month.month, day)
        .isBefore(DateTime(today.year, today.month, today.day));

    final att = _getAttForDay(day);
    if (att == null) {
      if (isToday || isPast) return _DayStatus.absent;
      return _DayStatus.future;
    }
    if (att.checkOut == null) return _DayStatus.inProgress;
    return _DayStatus.worked;
  }

  int get _workedCount =>
      List.generate(DateUtils.getDaysInMonth(month.year, month.month), (i) => i + 1)
          .where((d) => _statusForDay(d) == _DayStatus.worked)
          .length;

  int get _inProgressCount =>
      List.generate(DateUtils.getDaysInMonth(month.year, month.month), (i) => i + 1)
          .where((d) => _statusForDay(d) == _DayStatus.inProgress)
          .length;

  int get _absentCount =>
      List.generate(DateUtils.getDaysInMonth(month.year, month.month), (i) => i + 1)
          .where((d) => _statusForDay(d) == _DayStatus.absent)
          .length;

  double get _totalHours =>
      attendances.fold(0.0, (sum, a) => sum + a.totalHours);

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // weekday of 1st day: 1=Mon, 7=Sun
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final now = DateTime.now();
    final canGoNext = DateTime(month.year, month.month + 1)
        .isBefore(DateTime(now.year, now.month + 1));

    return SingleChildScrollView(
      child: Column(
        children: [
          // Month Navigator
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                  onPressed: onPrevMonth,
                ),
                Text(
                  'Tháng ${month.month}/${month.year}',
                  style: const TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right,
                      color: canGoNext ? Colors.white : Colors.white38,
                      size: 28),
                  onPressed: canGoNext ? onNextMonth : null,
                ),
              ],
            ),
          ),

          // Calendar Card
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                // Day headers
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Row(
                    children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(d,
                                    style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: d == 'CN'
                                            ? AppColors.primary
                                            : AppColors.textSecondary)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 8),

                // Grid
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: _buildGrid(context, daysInMonth, firstWeekday),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // Summary Stats
          _buildSummary(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, int daysInMonth, int firstWeekday) {
    // Total cells needed (pad start + days)
    final totalCells = firstWeekday - 1 + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              final day = cellIndex - (firstWeekday - 1) + 1;

              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox());
              }

              return Expanded(
                child: _DayCell(
                  day: day,
                  status: _statusForDay(day),
                  attendance: _getAttForDay(day),
                  canEdit: canEdit,
                  onTap: () => _onDayTap(context, day),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  void _onDayTap(BuildContext context, int day) {
    final att = _getAttForDay(day);
    final dateStr =
        '${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final displayDate = DateFormat('dd/MM/yyyy')
        .format(DateTime(month.year, month.month, day));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayDetailSheet(
        date: displayDate,
        dateStr: dateStr,
        day: day,
        month: month,
        attendance: att,
        storeId: storeId,
        memberId: memberId,
        memberName: memberName,
        canEdit: canEdit,
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tổng kết tháng',
              style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.neutral)),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryItem(
                color: AppColors.success,
                icon: Icons.check_circle_rounded,
                label: 'Đi làm',
                value: '$_workedCount ngày',
              ),
              const SizedBox(width: 12),
              _SummaryItem(
                color: const Color(0xFF1565C0),
                icon: Icons.radio_button_on_rounded,
                label: 'Đang làm',
                value: '$_inProgressCount ngày',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SummaryItem(
                color: AppColors.textSecondary,
                icon: Icons.cancel_outlined,
                label: 'Chưa chấm',
                value: '$_absentCount ngày',
              ),
              const SizedBox(width: 12),
              _SummaryItem(
                color: AppColors.primary,
                icon: Icons.access_time_rounded,
                label: 'Tổng giờ',
                value: '${_totalHours.toStringAsFixed(1)}h',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Day Cell ─────────────────────────────────────────────────────────────────

enum _DayStatus { worked, inProgress, absent, future }

class _DayCell extends StatelessWidget {
  final int day;
  final _DayStatus status;
  final AttendanceModel? attendance;
  final bool canEdit;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.status,
    required this.attendance,
    required this.canEdit,
    required this.onTap,
  });

  Color get _bgColor {
    switch (status) {
      case _DayStatus.worked:
        return AppColors.success;
      case _DayStatus.inProgress:
        return const Color(0xFF1565C0);
      case _DayStatus.absent:
        return const Color(0xFF9E9E9E);
      case _DayStatus.future:
        return AppColors.surface;
    }
  }

  Color get _textColor {
    switch (status) {
      case _DayStatus.future:
        return AppColors.textSecondary;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = attendance?.totalHours ?? 0.0;
    final hoursStr = status == _DayStatus.worked
        ? '${hours.toStringAsFixed(1)}h'
        : status == _DayStatus.inProgress
            ? '...'
            : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        height: 52,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textColor),
            ),
            if (hoursStr.isNotEmpty)
              Text(
                hoursStr,
                style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 9,
                    color: _textColor.withOpacity(0.85)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Summary Item ─────────────────────────────────────────────────────────────

class _SummaryItem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 11,
                      color: AppColors.textSecondary)),
              Text(value,
                  style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Day Detail Bottom Sheet ───────────────────────────────────────────────────

class _DayDetailSheet extends ConsumerStatefulWidget {
  final String date;
  final String dateStr;
  final int day;
  final DateTime month;
  final AttendanceModel? attendance;
  final String storeId;
  final String memberId;
  final String memberName;
  final bool canEdit;

  const _DayDetailSheet({
    required this.date,
    required this.dateStr,
    required this.day,
    required this.month,
    required this.attendance,
    required this.storeId,
    required this.memberId,
    required this.memberName,
    required this.canEdit,
  });

  @override
  ConsumerState<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends ConsumerState<_DayDetailSheet> {
  bool _editing = false;
  bool _saving = false;

  late TimeOfDay _checkInTime;
  late TimeOfDay _checkOutTime;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final att = widget.attendance;
    if (att != null) {
      final ci = att.checkIn.toLocal();
      _checkInTime = TimeOfDay(hour: ci.hour, minute: ci.minute);
      if (att.checkOut != null) {
        final co = att.checkOut!.toLocal();
        _checkOutTime = TimeOfDay(hour: co.hour, minute: co.minute);
      } else {
        _checkOutTime = TimeOfDay.now();
      }
    } else {
      _checkInTime = const TimeOfDay(hour: 8, minute: 0);
      _checkOutTime = const TimeOfDay(hour: 17, minute: 0);
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isCheckIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isCheckIn ? _checkInTime : _checkOutTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInTime = picked;
        } else {
          _checkOutTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final date = DateTime(widget.month.year, widget.month.month, widget.day);

      final newCheckIn = DateTime(
              date.year, date.month, date.day, _checkInTime.hour, _checkInTime.minute)
          .toUtc();
      final newCheckOut = DateTime(
              date.year, date.month, date.day, _checkOutTime.hour, _checkOutTime.minute)
          .toUtc();

      if (newCheckOut.isBefore(newCheckIn)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Giờ ra không thể trước giờ vào'),
            backgroundColor: AppColors.primary,
          ));
        }
        setState(() => _saving = false);
        return;
      }

      if (widget.attendance != null) {
        // Edit existing
        await repo.editAttendance(
          widget.storeId,
          widget.attendance!.id,
          newCheckIn,
          newCheckOut,
          _noteCtrl.text.trim(),
          widget.memberName,
        );
      } else {
        // Create new record
        await repo.createManualAttendance(
          widget.storeId,
          widget.memberId,
          widget.dateStr,
          newCheckIn,
          newCheckOut,
          _noteCtrl.text.trim(),
          widget.memberName,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã lưu thay đổi'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.primary),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attendance;
    final hasCheckIn = att != null;
    final hasCheckOut = att?.checkOut != null;
    final method = att?.checkInMethod;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('${widget.day}',
                          style: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.date,
                          style: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral)),
                      Text(widget.memberName,
                          style: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  if (hasCheckIn && method != null)
                    _MethodBadge(method: method),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _editing
                    ? _buildEditForm()
                    : _buildReadView(hasCheckIn, hasCheckOut, att),
              ),
            ),

            // Actions
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: _editing
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _editing = false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Hủy',
                                style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    color: AppColors.textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Text('Lưu thay đổi',
                                    style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  : widget.canEdit
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => setState(() => _editing = true),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: Text(
                              hasCheckIn ? 'Sửa giờ vào/ra' : 'Thêm chấm công',
                              style: const TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadView(bool hasCheckIn, bool hasCheckOut, AttendanceModel? att) {
    if (!hasCheckIn) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_busy_rounded,
                  size: 52, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text('Ngày này chưa chấm công',
                  style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 15,
                      color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    final checkInStr = DateFormat('HH:mm').format(att!.checkIn.toLocal());
    final checkOutStr =
        hasCheckOut ? DateFormat('HH:mm').format(att.checkOut!.toLocal()) : '--:--';
    final durationStr = att.formattedDuration;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _TimeCard(
                    label: 'Giờ vào',
                    time: checkInStr,
                    icon: Icons.login_rounded,
                    color: AppColors.success)),
            const SizedBox(width: 12),
            Expanded(
                child: _TimeCard(
                    label: 'Giờ ra',
                    time: checkOutStr,
                    icon: Icons.logout_rounded,
                    color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng giờ làm',
                  style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      color: AppColors.textSecondary)),
              Text(durationStr,
                  style: const TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral)),
            ],
          ),
        ),
        if (att.isEdited) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã chỉnh sửa bởi ${att.editedBy ?? "Quản lý"}',
                    style: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 12,
                        color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chỉnh sửa giờ công',
            style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.neutral)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TimePickerButton(
                label: 'Giờ vào',
                time: _checkInTime,
                color: AppColors.success,
                onTap: () => _pickTime(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimePickerButton(
                label: 'Giờ ra',
                time: _checkOutTime,
                color: AppColors.primary,
                onTap: () => _pickTime(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          style: const TextStyle(fontFamily: 'BeVietnamPro'),
          decoration: InputDecoration(
            hintText: 'Ghi chú lý do chỉnh sửa...',
            hintStyle: const TextStyle(
                fontFamily: 'BeVietnamPro', color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Small Widgets ─────────────────────────────────────────────────────────────

class _TimeCard extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final Color color;

  const _TimeCard(
      {required this.label,
      required this.time,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11,
                  color: color)),
          const SizedBox(height: 2),
          Text(time,
              style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final Color color;
  final VoidCallback onTap;

  const _TimePickerButton(
      {required this.label,
      required this.time,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 12,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text(formatted,
                style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Icon(Icons.touch_app_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  final CheckInMethod method;

  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (method) {
      CheckInMethod.gps => (Icons.location_on_rounded, AppColors.success),
      CheckInMethod.wifi => (Icons.wifi_rounded, AppColors.info),
      CheckInMethod.qr => (Icons.qr_code_rounded, AppColors.accent),
      CheckInMethod.manual => (Icons.edit_rounded, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(method.label,
              style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

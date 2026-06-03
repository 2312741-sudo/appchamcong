import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/schedule_model.dart';
import '../../store/providers/store_provider.dart';
import '../providers/schedule_provider.dart';
import '../repositories/schedule_repository.dart';

class ScheduleRegisterScreen extends ConsumerStatefulWidget {
  const ScheduleRegisterScreen({super.key});

  @override
  ConsumerState<ScheduleRegisterScreen> createState() =>
      _ScheduleRegisterScreenState();
}

class _ScheduleRegisterScreenState
    extends ConsumerState<ScheduleRegisterScreen> {
  late int _selectedWeekIndex;
  late List<String> _weeks;
  // Local draft: dayIndex (0=Mon..6=Sun) → ShiftType
  final Map<int, ShiftType> _draft = {};
  bool _saving = false;

  static const List<String> _dayNames = [
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật',
  ];

  static const List<ShiftType> _shifts = [
    ShiftType.morning,
    ShiftType.afternoon,
    ShiftType.evening,
    ShiftType.off,
  ];

  @override
  void initState() {
    super.initState();
    final repo = ScheduleRepository();
    _weeks = repo.getNextWeeks(3);
    _selectedWeekIndex = 0;
  }

  String get _currentWeek => _weeks[_selectedWeekIndex];

  /// Parse "YYYY-MM-DD" to DateTime
  DateTime _parseDate(String s) => DateTime.parse(s);

  /// Format date range "dd/MM → dd/MM"
  String _weekLabel(String weekStart) {
    final monday = _parseDate(weekStart);
    final sunday = monday.add(const Duration(days: 6));
    final mLabel =
        '${monday.day.toString().padLeft(2, '0')}/${monday.month.toString().padLeft(2, '0')}';
    final sLabel =
        '${sunday.day.toString().padLeft(2, '0')}/${sunday.month.toString().padLeft(2, '0')}';
    return '$mLabel → $sLabel';
  }

  /// Week number in year
  int _weekNumber(String weekStart) {
    final date = _parseDate(weekStart);
    final firstJan = DateTime(date.year, 1, 1);
    final days = date.difference(firstJan).inDays;
    return (days / 7).ceil() + 1;
  }

  bool _isPastDeadline(String weekStart) {
    // Deadline: Friday 23:59 of the PREVIOUS week
    final monday = _parseDate(weekStart);
    final prevFriday = monday.subtract(const Duration(days: 3));
    final deadline = DateTime(
        prevFriday.year, prevFriday.month, prevFriday.day, 23, 59, 59);
    return DateTime.now().isAfter(deadline);
  }

  void _loadDraftFromSchedule(DaySchedule? schedule) {
    _draft.clear();
    if (schedule == null) {
      for (int i = 0; i < 7; i++) {
        _draft[i] = ShiftType.off;
      }
      return;
    }
    for (int i = 0; i < 7; i++) {
      _draft[i] = schedule.shiftForDay(i + 1);
    }
  }

  DaySchedule _buildDaySchedule() {
    return DaySchedule(
      monday: _draft[0] ?? ShiftType.off,
      tuesday: _draft[1] ?? ShiftType.off,
      wednesday: _draft[2] ?? ShiftType.off,
      thursday: _draft[3] ?? ShiftType.off,
      friday: _draft[4] ?? ShiftType.off,
      saturday: _draft[5] ?? ShiftType.off,
      sunday: _draft[6] ?? ShiftType.off,
    );
  }

  Future<void> _save() async {
    final storeId = ref.read(currentStoreIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (storeId == null || uid == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(scheduleRepositoryProvider);
      await repo.saveUserSchedule(
          storeId, uid, _currentWeek, _buildDaySchedule());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu lịch làm việc'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _shiftColor(ShiftType shift) {
    switch (shift) {
      case ShiftType.morning:
        return AppColors.primary;
      case ShiftType.afternoon:
        return AppColors.success;
      case ShiftType.evening:
        return AppColors.info;
      case ShiftType.off:
        return const Color(0xFF888780);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(weekScheduleProvider(_currentWeek));
    final uid = FirebaseAuth.instance.currentUser?.uid;

    scheduleAsync.whenData((schedule) {
      final userSchedule = uid != null ? schedule?.getScheduleForUser(uid) : null;
      if (_draft.isEmpty) {
        _loadDraftFromSchedule(userSchedule);
      }
    });

    final pastDeadline = _isPastDeadline(_currentWeek);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          'Đăng ký lịch làm',
          style: GoogleFonts.beVietnamPro(
              fontWeight: FontWeight.w600, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildWeekSelector(),
          if (pastDeadline) _buildDeadlineWarning(),
          Expanded(
            child: scheduleAsync.when(
              data: (_) => _buildScheduleList(),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
            ),
          ),
          _buildSaveButton(pastDeadline),
        ],
      ),
    );
  }

  Widget _buildWeekSelector() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: _selectedWeekIndex > 0
                ? () {
                    setState(() {
                      _selectedWeekIndex--;
                      _draft.clear();
                    });
                  }
                : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Tuần ${_weekNumber(_currentWeek)}',
                  style: GoogleFonts.beVietnamPro(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _weekLabel(_currentWeek),
                  style: GoogleFonts.beVietnamPro(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _selectedWeekIndex < _weeks.length - 1
                ? () {
                    setState(() {
                      _selectedWeekIndex++;
                      _draft.clear();
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineWarning() {
    return Container(
      width: double.infinity,
      color: AppColors.accent.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đã qua hạn đăng ký (thứ 6 tuần trước). Vui lòng liên hệ quản lý.',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: const Color(0xFF7A6000)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, dayIndex) {
        final monday = _parseDate(_currentWeek);
        final dayDate = monday.add(Duration(days: dayIndex));
        return _DayRow(
          dayName: _dayNames[dayIndex],
          date: dayDate,
          selected: _draft[dayIndex] ?? ShiftType.off,
          shifts: _shifts,
          onSelect: (shift) => setState(() => _draft[dayIndex] = shift),
          shiftColor: _shiftColor,
        );
      },
    );
  }

  Widget _buildSaveButton(bool disabled) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ElevatedButton(
        onPressed: (!disabled && !_saving) ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(
                'Lưu lịch',
                style: GoogleFonts.beVietnamPro(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final String dayName;
  final DateTime date;
  final ShiftType selected;
  final List<ShiftType> shifts;
  final ValueChanged<ShiftType> onSelect;
  final Color Function(ShiftType) shiftColor;

  const _DayRow({
    required this.dayName,
    required this.date,
    required this.selected,
    required this.shifts,
    required this.onSelect,
    required this.shiftColor,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dayName,
                style: GoogleFonts.beVietnamPro(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: shifts.map((shift) {
              final isSelected = selected == shift;
              return GestureDetector(
                onTap: () => onSelect(shift),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? shiftColor(shift)
                        : shiftColor(shift).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? shiftColor(shift)
                          : shiftColor(shift).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shift.label,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : shiftColor(shift),
                        ),
                      ),
                      if (shift.timeRange.isNotEmpty)
                        Text(
                          shift.timeRange,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.white70
                                : shiftColor(shift).withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

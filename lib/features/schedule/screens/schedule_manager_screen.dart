import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/member_model.dart';
import '../../../models/schedule_model.dart';
import '../../store/providers/store_provider.dart';
import '../providers/schedule_provider.dart';
import '../repositories/schedule_repository.dart';

enum _ViewMode { byDay, byEmployee }

class ScheduleManagerScreen extends ConsumerStatefulWidget {
  const ScheduleManagerScreen({super.key});

  @override
  ConsumerState<ScheduleManagerScreen> createState() =>
      _ScheduleManagerScreenState();
}

class _ScheduleManagerScreenState
    extends ConsumerState<ScheduleManagerScreen> {
  _ViewMode _viewMode = _ViewMode.byDay;
  late int _selectedWeekIndex;
  late List<String> _weeks;

  // Local editable schedule: userId → DaySchedule
  final Map<String, DaySchedule> _draft = {};
  bool _saving = false;
  bool _draftLoaded = false;

  static const List<String> _dayNames = [
    'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN',
  ];
  static const List<String> _dayFullNames = [
    'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật',
  ];

  @override
  void initState() {
    super.initState();
    final repo = ScheduleRepository();
    _weeks = repo.getNextWeeks(5);
    _selectedWeekIndex = 0;
  }

  String get _currentWeek => _weeks[_selectedWeekIndex];

  DateTime _parseDate(String s) => DateTime.parse(s);

  String _weekLabel(String weekStart) {
    final monday = _parseDate(weekStart);
    final sunday = monday.add(const Duration(days: 6));
    return '${monday.day.toString().padLeft(2, '0')}/${monday.month} — '
        '${sunday.day.toString().padLeft(2, '0')}/${sunday.month}';
  }

  int _weekNumber(String weekStart) {
    final date = _parseDate(weekStart);
    final firstJan = DateTime(date.year, 1, 1);
    final days = date.difference(firstJan).inDays;
    return (days / 7).ceil() + 1;
  }

  void _loadDraft(ScheduleModel? schedule, List<MemberModel> members) {
    if (_draftLoaded) return;
    _draft.clear();
    for (final m in members) {
      _draft[m.userId] = schedule?.getScheduleForUser(m.userId) ??
          DaySchedule.allOff();
    }
    _draftLoaded = true;
  }

  void _setShift(String userId, int dayIndex, ShiftType shift) {
    final current = _draft[userId] ?? DaySchedule.allOff();
    setState(() {
      _draft[userId] = switch (dayIndex) {
        0 => current.copyWith(monday: shift),
        1 => current.copyWith(tuesday: shift),
        2 => current.copyWith(wednesday: shift),
        3 => current.copyWith(thursday: shift),
        4 => current.copyWith(friday: shift),
        5 => current.copyWith(saturday: shift),
        6 => current.copyWith(sunday: shift),
        _ => current,
      };
    });
  }

  Future<void> _saveAll() async {
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(scheduleRepositoryProvider);
      await repo.setFullSchedule(storeId, _currentWeek, _draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã lưu lịch làm việc'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: AppColors.primary,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showShiftPicker(String userId, int dayIndex) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final currentShift =
            _draft[userId]?.shiftForDay(dayIndex + 1) ?? ShiftType.off;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_dayFullNames[dayIndex]} — Chọn ca',
                  style: GoogleFonts.beVietnamPro(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ...ShiftType.values.map((shift) {
                  final isSelected = shift == currentShift;
                  return ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _shiftColor(shift),
                      ),
                    ),
                    title: Text(
                      shift.label,
                      style: GoogleFonts.beVietnamPro(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400),
                    ),
                    subtitle: shift.timeRange.isNotEmpty
                        ? Text(shift.timeRange,
                            style: GoogleFonts.beVietnamPro(fontSize: 12))
                        : null,
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.success)
                        : null,
                    onTap: () {
                      _setShift(userId, dayIndex, shift);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
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
        return const Color(0xFFCCCCCC);
    }
  }

  String _shiftAbbr(ShiftType shift) {
    switch (shift) {
      case ShiftType.morning:
        return 'S';
      case ShiftType.afternoon:
        return 'C';
      case ShiftType.evening:
        return 'T';
      case ShiftType.off:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(weekScheduleProvider(_currentWeek));
    final members = ref.watch(activeMembersProvider);

    scheduleAsync.whenData((schedule) {
      _loadDraft(schedule, members);
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          'Quản lý lịch làm',
          style: GoogleFonts.beVietnamPro(
              fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _saveAll,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_alt, color: Colors.white, size: 18),
            label: Text('Lưu thay đổi',
                style: GoogleFonts.beVietnamPro(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: scheduleAsync.when(
              data: (_) => _viewMode == _ViewMode.byDay
                  ? _buildByDayView(members)
                  : _buildByEmployeeView(members),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        children: [
          // Week selector
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _selectedWeekIndex > 0
                    ? () => setState(() {
                          _selectedWeekIndex--;
                          _draftLoaded = false;
                          _draft.clear();
                        })
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
                          fontSize: 16),
                    ),
                    Text(
                      _weekLabel(_currentWeek),
                      style: GoogleFonts.beVietnamPro(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _selectedWeekIndex < _weeks.length - 1
                    ? () => setState(() {
                          _selectedWeekIndex++;
                          _draftLoaded = false;
                          _draft.clear();
                        })
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // View toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ViewToggleButton(
                  label: 'Theo ngày',
                  selected: _viewMode == _ViewMode.byDay,
                  onTap: () =>
                      setState(() => _viewMode = _ViewMode.byDay),
                ),
                _ViewToggleButton(
                  label: 'Theo nhân viên',
                  selected: _viewMode == _ViewMode.byEmployee,
                  onTap: () =>
                      setState(() => _viewMode = _ViewMode.byEmployee),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildByDayView(List<MemberModel> members) {
    if (members.isEmpty) {
      return _emptyState('Chưa có nhân viên nào');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 7,
      itemBuilder: (_, dayIndex) {
        final monday = _parseDate(_currentWeek);
        final dayDate = monday.add(Duration(days: dayIndex));
        final dateLabel =
            '${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Text(
                  '${_dayFullNames[dayIndex]}  •  $dateLabel',
                  style: GoogleFonts.beVietnamPro(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primary),
                ),
              ),
              ...members.map((m) {
                final shift =
                    _draft[m.userId]?.shiftForDay(dayIndex + 1) ??
                        ShiftType.off;
                return ListTile(
                  dense: true,
                  leading: _Avatar(member: m, size: 32),
                  title: Text(m.name,
                      style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w500, fontSize: 13)),
                  trailing: GestureDetector(
                    onTap: () => _showShiftPicker(m.userId, dayIndex),
                    child: _ShiftChip(shift: shift, color: _shiftColor(shift)),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildByEmployeeView(List<MemberModel> members) {
    if (members.isEmpty) {
      return _emptyState('Chưa có nhân viên nào');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: members.length,
      itemBuilder: (_, i) {
        final m = members[i];
        final schedule = _draft[m.userId] ?? DaySchedule.allOff();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(member: m, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(m.name,
                          style: GoogleFonts.beVietnamPro(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(7, (dayIndex) {
                    final shift = schedule.shiftForDay(dayIndex + 1);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _showShiftPicker(m.userId, dayIndex),
                        child: Column(
                          children: [
                            Text(
                              _dayNames[dayIndex],
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 10,
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 34,
                              decoration: BoxDecoration(
                                color: _shiftColor(shift),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  _shiftAbbr(shift),
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: shift == ShiftType.off
                                        ? AppColors.textSecondary
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Text(msg,
          style: GoogleFonts.beVietnamPro(
              color: AppColors.textSecondary, fontSize: 15)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ViewToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ViewToggleButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ShiftChip extends StatelessWidget {
  final ShiftType shift;
  final Color color;

  const _ShiftChip({required this.shift, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        shift.label,
        style: GoogleFonts.beVietnamPro(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final MemberModel member;
  final double size;

  const _Avatar({required this.member, required this.size});

  @override
  Widget build(BuildContext context) {
    if (member.hasAvatar) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(member.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withOpacity(0.15),
      child: Text(
        member.initials,
        style: GoogleFonts.beVietnamPro(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

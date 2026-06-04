import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/schedule_model.dart';
import '../../../models/store_model.dart';
import '../../store/providers/store_provider.dart';
import '../providers/schedule_provider.dart';
import '../repositories/schedule_repository.dart';
import '../../../models/member_model.dart';

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
  // Local draft: dayIndex (0=Mon..6=Sun) → List of selected shift IDs
  final Map<int, List<String>> _draft = {};
  bool _saving = false;

  static const List<String> _dayNames = [
    'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật',
  ];

  @override
  void initState() {
    super.initState();
    final repo = ScheduleRepository();
    _weeks = repo.getNextWeeks(3);
    _selectedWeekIndex = 0;
  }

  String get _currentWeek => _weeks[_selectedWeekIndex];

  DateTime _parseDate(String s) => DateTime.parse(s);

  String _weekLabel(String weekStart) {
    final monday = _parseDate(weekStart);
    final sunday = monday.add(const Duration(days: 6));
    final mLabel =
        '${monday.day.toString().padLeft(2, '0')}/${monday.month.toString().padLeft(2, '0')}';
    final sLabel =
        '${sunday.day.toString().padLeft(2, '0')}/${sunday.month.toString().padLeft(2, '0')}';
    return '$mLabel → $sLabel';
  }

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
        _draft[i] = [];
      }
      return;
    }
    for (int i = 0; i < 7; i++) {
      _draft[i] = List.from(schedule.shiftForDay(i + 1));
    }
  }

  DaySchedule _buildDaySchedule() {
    return DaySchedule(
      monday: _draft[0] ?? [],
      tuesday: _draft[1] ?? [],
      wednesday: _draft[2] ?? [],
      thursday: _draft[3] ?? [],
      friday: _draft[4] ?? [],
      saturday: _draft[5] ?? [],
      sunday: _draft[6] ?? [],
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

  void _showShiftPicker(int dayIndex, StoreModel store, bool isOwner) {
    var selectedShifts = List<String>.from(_draft[dayIndex] ?? []);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) {
            final hasDelivery = selectedShifts.contains('delivery');
            final hasGiaoHang = selectedShifts.contains('giaohang');
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chọn ca làm cho ${_dayNames[dayIndex]}', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 16),
                  if (store.customShifts.isEmpty)
                    const Text('Chưa có ca làm nào được thiết lập. V vui lòng liên hệ quản lý.'),
                  ...store.customShifts.map((shift) {
                    final currentSelected = selectedShifts.where((s) => s.startsWith('${shift.id}|') || s == shift.id).firstOrNull ?? '';
                    final isSelected = currentSelected.isNotEmpty;
                    String selectedDeptId = (isSelected && currentSelected.contains('|')) ? currentSelected.split('|')[1] : '';
                    return Column(
                      children: [
                        CheckboxListTile(
                          title: Text('${shift.name} (${shift.timeRange})', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                          value: isSelected,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedShifts.add(shift.id);
                              } else {
                                selectedShifts.removeWhere((s) => s.startsWith('${shift.id}|') || s == shift.id);
                              }
                            });
                          },
                        ),
                        if (isSelected && store.departments.isNotEmpty && (isOwner || store.departmentSelectionEnabled))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: DropdownButtonFormField<String>(
                              value: selectedDeptId.isEmpty ? null : selectedDeptId,
                              hint: const Text('Chọn bộ phận'),
                              items: store.departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    selectedShifts.removeWhere((s) => s.startsWith('${shift.id}|') || s == shift.id);
                                    selectedShifts.add('${shift.id}|$val');
                                  });
                                }
                              }
                            ),
                          ),
                        const Divider(),
                      ],
                    );
                  }),
                    if (store.deliveryEnabled)
                      CheckboxListTile(
                        title: Text('🚛 Đăng ký Chở hàng (+${store.deliveryAllowance ?? 0}đ)', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, color: AppColors.primary)),
                        value: hasDelivery,
                        onChanged: (val) {
                          setModalState(() {
                            if (val == true) selectedShifts.add('delivery');
                            else selectedShifts.remove('delivery');
                          });
                        }
                      ),
                    if (store.giaoHangEnabled == true)
                      CheckboxListTile(
                        title: Text('📦 Đăng ký Giao hàng (+${store.giaoHangAllowance ?? 0}đ)', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, color: AppColors.primary)),
                        value: hasGiaoHang,
                        onChanged: (val) {
                          setModalState(() {
                            if (val == true) selectedShifts.add('giaohang');
                            else selectedShifts.remove('giaohang');
                          });
                        }
                      ),
                    const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _draft[dayIndex] = List.from(selectedShifts));
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Xác nhận'),
                    ),
                  )
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(weekScheduleProvider(_currentWeek));
    final storeAsync = ref.watch(currentStoreProvider);
    final store = storeAsync.valueOrNull;
    final currentMember = ref.watch(currentMemberProvider);
    final isOwner = currentMember?.role == UserRole.owner;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (store == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
              data: (_) => _buildScheduleList(store, pastDeadline, isOwner),
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

  Widget _buildScheduleList(StoreModel store, bool pastDeadline, bool isOwner) {
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
          selectedShifts: _draft[dayIndex] ?? [],
          store: store,
          onTap: () {
            if (!pastDeadline) _showShiftPicker(dayIndex, store, isOwner);
          }
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
  final List<String> selectedShifts;
  final StoreModel store;
  final VoidCallback onTap;

  const _DayRow({
    required this.dayName,
    required this.date,
    required this.selectedShifts,
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            if (selectedShifts.isEmpty)
              Text('Nghỉ', style: GoogleFonts.beVietnamPro(fontSize: 13, color: AppColors.textSecondary))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                  children: selectedShifts.map((s) {
                    if (s == 'delivery') {
                      return const _Chip(label: 'Chở hàng', color: AppColors.primary, icon: Icons.local_shipping);
                    }
                    if (s == 'giaohang') {
                      return const _Chip(label: 'Giao hàng', color: Colors.orange, icon: Icons.inventory_2);
                    }
                    final parts = s.split('|');
                  final baseId = parts[0];
                  final deptId = parts.length > 1 ? parts[1] : null;
                  
                  final shiftDef = store.customShifts.where((x) => x.id == baseId).firstOrNull;
                  final deptDef = deptId != null ? store.departments.where((d) => d.id == deptId).firstOrNull : null;
                  
                  if (shiftDef == null) return const SizedBox();
                  
                  final nameStr = deptDef != null ? '[${deptDef.shortName}] ${shiftDef.name}' : shiftDef.name;
                  return _Chip(label: nameStr, color: AppColors.success);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Chip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

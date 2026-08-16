import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/app_permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/export_utils.dart';
import '../../../models/member_model.dart';
import '../../../models/schedule_model.dart';
import '../../../models/store_model.dart';
import '../../store/providers/store_provider.dart';
import '../providers/schedule_provider.dart';
import '../repositories/schedule_repository.dart';

enum _ViewMode { byDay, byEmployee }

class ScheduleManagerScreen extends ConsumerStatefulWidget {
  final int initialWeekIndex;
  final bool showAppBar;
  final bool isReadOnly;
  const ScheduleManagerScreen({
    super.key,
    this.initialWeekIndex = 0,
    this.showAppBar = true,
    this.isReadOnly = false,
  });

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
    _weeks = repo.getWeeksRange(pastWeeks: 8, futureWeeks: 6);
    final currentWeekStr = repo.getWeekStart(DateTime.now());
    final currentIdx = _weeks.indexOf(currentWeekStr);
    final defaultIdx = currentIdx >= 0 ? currentIdx : 8;
    _selectedWeekIndex = (widget.initialWeekIndex >= 0 && widget.initialWeekIndex < _weeks.length)
        ? (widget.initialWeekIndex == 0 ? defaultIdx : widget.initialWeekIndex)
        : defaultIdx;
  }

  int get _thisWeekIndex {
    final currentWeekStr = ScheduleRepository().getWeekStart(DateTime.now());
    final idx = _weeks.indexOf(currentWeekStr);
    return idx >= 0 ? idx : 8;
  }

  bool get _isCurrentWeek => _selectedWeekIndex == _thisWeekIndex;

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

  void _setShift(String userId, int dayIndex, List<String> shifts) {
    final current = _draft[userId] ?? DaySchedule.allOff();
    setState(() {
      _draft[userId] = switch (dayIndex) {
        0 => current.copyWith(monday: shifts),
        1 => current.copyWith(tuesday: shifts),
        2 => current.copyWith(wednesday: shifts),
        3 => current.copyWith(thursday: shifts),
        4 => current.copyWith(friday: shifts),
        5 => current.copyWith(saturday: shifts),
        6 => current.copyWith(sunday: shifts),
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

  void _showShiftPicker(String userId, int dayIndex, StoreModel store, bool isOwner, bool canManageSchedule, bool canTick) {
    if (!canManageSchedule && !canTick) return;
    var selectedShifts = List<String>.from(_draft[userId]?.shiftForDay(dayIndex + 1) ?? []);
    final isLockedForManager = !canManageSchedule;
    
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
                  Text('Chọn ca làm', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 18)),
                  if (!canManageSchedule)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Quản lý 2: Chế độ chỉ xem lịch làm. Bạn chỉ có thể tick chở hàng / giao hàng.', style: GoogleFonts.beVietnamPro(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 16),
                  if (store.customShifts.isEmpty)
                    const Text('Chưa có ca làm nào được thiết lập. Vui lòng tạo trên Web hoặc trong Cài đặt.'),
                  ...store.customShifts.map((shift) {
                    final currentSelected = selectedShifts.where((s) => s.startsWith('${shift.id}|') || s == shift.id).firstOrNull ?? '';
                    final isSelected = currentSelected.isNotEmpty;
                    String selectedDeptId = (isSelected && currentSelected.contains('|')) ? currentSelected.split('|')[1] : '';
                    return Column(
                      children: [
                        CheckboxListTile(
                          title: Text('${shift.name} (${shift.timeRange})', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                          value: isSelected,
                          onChanged: isLockedForManager ? null : (val) {
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
                              onChanged: isLockedForManager ? null : (val) {
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
                  if (canTick || isOwner || canManageSchedule) ...[
                    CheckboxListTile(
                      title: Text('📦 Chở hàng (+${store.deliveryAllowance ?? 0}đ)', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, color: AppColors.primary)),
                      value: hasDelivery,
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) selectedShifts.add('delivery');
                          else selectedShifts.remove('delivery');
                        });
                      }
                    ),
                    CheckboxListTile(
                      title: Text('🛵 Giao hàng (+${store.giaoHangAllowance ?? 0}đ)', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, color: AppColors.primary)),
                      value: hasGiaoHang,
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) selectedShifts.add('giaohang');
                          else selectedShifts.remove('giaohang');
                        });
                      }
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () { _setShift(userId, dayIndex, selectedShifts); Navigator.pop(ctx); },
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
    final storeAsync = ref.watch(currentStoreProvider);
    final scheduleAsync = ref.watch(weekScheduleProvider(_currentWeek));
    final members = ref.watch(activeMembersProvider);
    final currentMember = ref.watch(currentMemberProvider);
    final isOwner = currentMember?.role == UserRole.owner;
    final isManager2 = currentMember?.role == UserRole.manager2;
    final isEmployee = currentMember?.role == UserRole.employee;
    final canManageSchedule = !widget.isReadOnly && AppPermissions.canManageSchedule(currentMember?.role);
    final canTick = !widget.isReadOnly &&
        (AppPermissions.canTickDelivery(currentMember?.role) ||
            AppPermissions.canTickGiaoHang(currentMember?.role));
    final store = storeAsync.valueOrNull;
    if (store == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    scheduleAsync.whenData((schedule) {
      _loadDraft(schedule, members);
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              title: Text(
                canManageSchedule ? 'Quản lý lịch làm' : 'Lịch làm cửa hàng',
                style: GoogleFonts.beVietnamPro(
                    fontWeight: FontWeight.w600, color: Colors.white),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  tooltip: 'Xuất Excel tuần',
                  onPressed: () async {
                    try {
                      final schedule = scheduleAsync.valueOrNull;
                      await ExportUtils.exportWeeklyScheduleToExcel(
                        weekStart: _currentWeek,
                        members: members,
                        schedule: schedule,
                        store: store,
                        storeName: store.name,
                        context: context,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi xuất: $e'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    }
                  },
                ),
                if (canManageSchedule || canTick)
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
            )
          : null,
      body: Column(
        children: [
          _buildHeader(),
          if (!canManageSchedule)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3CD),
                border: Border(bottom: BorderSide(color: Color(0xFFFFEEBA))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF856404), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isManager2
                          ? 'Quản lý 2: Chế độ chỉ xem lịch làm. Bạn có thể tick chọn Chở hàng / Giao hàng.'
                          : 'Chế độ xem: Bạn đang xem lịch làm việc của toàn bộ cửa hàng.',
                      style: GoogleFonts.beVietnamPro(
                        color: const Color(0xFF856404),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: scheduleAsync.when(
              data: (_) => _viewMode == _ViewMode.byDay
                  ? _buildByDayView(members, store, isOwner, canManageSchedule, canTick)
                  : _buildByEmployeeView(members, store, isOwner, canManageSchedule, canTick),
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
                    if (!_isCurrentWeek)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: InkWell(
                          onTap: () => setState(() {
                            _selectedWeekIndex = _thisWeekIndex;
                            _draftLoaded = false;
                            _draft.clear();
                          }),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.today_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Về tuần này',
                                  style: GoogleFonts.beVietnamPro(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Tuần hiện tại',
                            style: GoogleFonts.beVietnamPro(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

  Widget _buildByDayView(List<MemberModel> members, StoreModel store, bool isOwner, bool canManageSchedule, bool canTick) {
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
                    _draft[m.userId]?.shiftForDay(dayIndex + 1) ?? [];
                return ListTile(
                  dense: true,
                  leading: _Avatar(member: m, size: 32),
                  title: Text(m.name,
                      style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w500, fontSize: 13)),
                  trailing: GestureDetector(
                    onTap: () => _showShiftPicker(m.userId, dayIndex, store, isOwner, canManageSchedule, canTick),
                    child: _ShiftChip(shifts: shift, store: store),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildByEmployeeView(List<MemberModel> members, StoreModel store, bool isOwner, bool canManageSchedule, bool canTick) {
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
                            _showShiftPicker(m.userId, dayIndex, store, isOwner, canManageSchedule, canTick),
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
                                color: shift.isEmpty ? const Color(0xFFCCCCCC) : AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: _ShiftChip(shifts: shift, store: store, isCompact: true),
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
  final List<String> shifts;
  final StoreModel store;
  final bool isCompact;

  const _ShiftChip({required this.shifts, required this.store, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    if (shifts.isEmpty) {
      return Text('—', style: GoogleFonts.beVietnamPro(fontSize: 12, color: AppColors.textSecondary));
    }
    
    if (isCompact) {
      return Text('${shifts.length} ca', style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary));
    }

    return Wrap(
      spacing: 4,
      children: shifts.map((s) {
        if (s == 'delivery') {
          return const Icon(Icons.local_shipping, color: AppColors.primary, size: 16);
        }
        if (s == 'giaohang') {
          return const Icon(Icons.two_wheeler, color: AppColors.primary, size: 16);
        }
        final parts = s.split('|');
        final baseId = parts[0];
        final deptId = parts.length > 1 ? parts[1] : null;
        
        final shiftDef = store.customShifts.where((x) => x.id == baseId).firstOrNull;
        final deptDef = deptId != null ? store.departments.where((d) => d.id == deptId).firstOrNull : null;
        
        if (shiftDef == null) return const SizedBox();
        
        final nameStr = deptDef != null ? '[${deptDef.shortName}] ${shiftDef.name}' : shiftDef.name;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            nameStr,
            style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        );
      }).toList(),
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

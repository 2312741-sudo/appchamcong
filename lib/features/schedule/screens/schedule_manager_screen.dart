import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/app_permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../core/utils/export_utils.dart';
import '../../../core/utils/department_utils.dart';
import '../../../models/member_model.dart';
import '../../../models/schedule_model.dart';
import '../../../models/store_model.dart';
import '../../store/providers/store_provider.dart';
import '../providers/schedule_provider.dart';
import '../repositories/schedule_repository.dart';

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

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _showDayDetailModal(MemberModel member, int dayIndex, DateTime dayDate, StoreModel store) {
    final shiftEntries = _draft[member.userId]?.shiftForDay(dayIndex + 1) ?? [];
    final dayFullName = _dayFullNames[dayIndex];
    final dateFormatted = '${_pad(dayDate.day)}/${_pad(dayDate.month)}/${dayDate.year}';
    final hasDelivery = shiftEntries.contains('delivery');
    final hasGiaoHang = shiftEntries.contains('giaohang');

    // Parse work shifts
    final List<Map<String, dynamic>> parsedShifts = [];
    for (final s in shiftEntries) {
      if (s == 'delivery' || s == 'giaohang') continue;
      final parts = s.split('|');
      final baseId = parts[0];
      final deptId = parts.length > 1 ? parts[1] : member.department;

      final shiftDef = store.customShifts.where((x) => x.id == baseId).firstOrNull;
      final deptDef = deptId != null ? store.departments.where((d) => d.id == deptId || d.shortName == deptId).firstOrNull : null;

      final startMin = shiftDef != null ? (shiftDef.startHour * 60 + shiftDef.startMinute) : 9999;
      final deptName = deptDef?.name ?? deptId ?? member.department ?? 'Chung';
      final isProd = (shiftDef?.isProduction ?? false) ||
          DepartmentUtils.isProduction(
            deptId: deptId,
            deptName: deptDef?.name,
            shortName: deptDef?.shortName,
            storeDepartments: store.departments,
          );

      parsedShifts.add({
        'shift': shiftDef,
        'shiftName': shiftDef?.name ?? baseId,
        'timeRange': shiftDef != null
            ? '${_pad(shiftDef.startHour)}:${_pad(shiftDef.startMinute)} – ${_pad(shiftDef.endHour)}:${_pad(shiftDef.endMinute)}'
            : '--:--',
        'startMinutes': startMin,
        'deptName': deptName,
        'isProduction': isProd,
      });
    }

    // Sort shifts by start time
    parsedShifts.sort((a, b) => (a['startMinutes'] as int).compareTo(b['startMinutes'] as int));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Avatar, Member name, Day date
              Row(
                children: [
                  _Avatar(member: member, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dayFullName, $dateFormatted',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Title
              Text(
                'Chi tiết ca làm việc',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C4E6B),
                ),
              ),
              const SizedBox(height: 10),

              if (parsedShifts.isEmpty && !hasDelivery && !hasGiaoHang)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9ECEF)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.nightlight_round, color: Colors.grey, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Không có ca làm trong ngày này',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // Work shift cards
                ...parsedShifts.map((s) {
                  final shiftName = s['shiftName'] as String;
                  final timeRange = s['timeRange'] as String;
                  final deptName = s['deptName'] as String;
                  final isProd = s['isProduction'] as bool;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isProd ? const Color(0xFFE8F5E9) : const Color(0xFFF0F7FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isProd ? const Color(0xFFA5D6A7) : const Color(0xFFBEE3F8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isProd
                                ? const Color(0xFF2E7D32).withOpacity(0.12)
                                : AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.access_time_filled_rounded,
                            size: 22,
                            color: isProd ? const Color(0xFF2E7D32) : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shiftName,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 14, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Giờ làm: $timeRange',
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1C4E6B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.badge_outlined, size: 14, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Bộ phận: ',
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 12.5,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isProd ? const Color(0xFF2E7D32) : AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      deptName,
                                      style: GoogleFonts.beVietnamPro(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Delivery / Giao hàng badges
                if (hasDelivery)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF90CAF9)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping_rounded, color: Color(0xFF1565C0), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Phụ cấp chở hàng: Có lịch chở hàng trong ngày',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (hasGiaoHang)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.two_wheeler_rounded, color: Color(0xFFE65100), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Phụ cấp giao hàng: Có lịch giao hàng trong ngày',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Đóng',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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

    final hiddenIds = store.hiddenScheduleUserIds;
    final visibleMembers = isOwner
        ? members
        : members
            .where((m) =>
                !hiddenIds.contains(m.userId) ||
                m.userId == currentMember?.userId)
            .toList();

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
                        members: visibleMembers,
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
          _buildHeader(store, visibleMembers, scheduleAsync.valueOrNull, canManageSchedule, canTick),
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
              data: (_) => _buildByEmployeeView(visibleMembers, store, isOwner, canManageSchedule, canTick),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(StoreModel store, List<MemberModel> members, ScheduleModel? schedule, bool canManageSchedule, bool canTick) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        children: [
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
          if (!widget.showAppBar) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
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
                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                  label: Text('Xuất Excel', style: GoogleFonts.beVietnamPro(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                  ),
                ),
                if (canManageSchedule || canTick) ...[
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _saveAll,
                    icon: _saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        : const Icon(Icons.save_alt_rounded, color: AppColors.primary, size: 16),
                    label: Text('Lưu thay đổi', style: GoogleFonts.beVietnamPro(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildByEmployeeView(List<MemberModel> members, StoreModel store, bool isOwner, bool canManageSchedule, bool canTick) {
    if (members.isEmpty) {
      return _emptyState('Chưa có nhân viên nào');
    }
    final monday = _parseDate(_currentWeek);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: members.length,
      itemBuilder: (_, i) {
        final m = members[i];
        final schedule = _draft[m.userId] ?? DaySchedule.allOff();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(member: m, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              style: GoogleFonts.beVietnamPro(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (store.hiddenScheduleUserIds.contains(m.userId)) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: const Color(0xFFFFEEBA)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_off_rounded,
                                      size: 10, color: Color(0xFFD9480F)),
                                  SizedBox(width: 2),
                                  Text(
                                    'Ẩn',
                                    style: TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD9480F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isOwner) ...[
                      IconButton(
                        icon: Icon(
                          store.hiddenScheduleUserIds.contains(m.userId)
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 18,
                          color: store.hiddenScheduleUserIds.contains(m.userId)
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                        tooltip: store.hiddenScheduleUserIds.contains(m.userId)
                            ? 'Đang ẩn với người khác (Bấm để hiện)'
                            : 'Đang hiện (Bấm để ẩn khỏi người khác)',
                        onPressed: () {
                          final currentlyHidden =
                              store.hiddenScheduleUserIds.contains(m.userId);
                          ref
                              .read(storeRepositoryProvider)
                              .toggleHideMemberSchedule(
                                  store.id, m.userId, !currentlyHidden);
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(7, (dayIndex) {
                    final shift = schedule.shiftForDay(dayIndex + 1);
                    final dayDate = monday.add(Duration(days: dayIndex));
                    final dateLabel = '${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}';

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: GestureDetector(
                          onTap: () {
                            if (canManageSchedule || canTick) {
                              _showShiftPicker(m.userId, dayIndex, store, isOwner, canManageSchedule, canTick);
                            } else {
                              _showDayDetailModal(m, dayIndex, dayDate, store);
                            }
                          },
                          child: Column(
                            children: [
                              Text(
                                _dayNames[dayIndex],
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                dateLabel,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _DayShiftCell(
                                shifts: shift,
                                store: store,
                                memberDept: m.department,
                              ),
                            ],
                          ),
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

class _ShiftInfo {
  final String shiftId;
  final String? deptId;
  final String deptAbbreviation;
  final String shiftName;
  final int startMinutes;
  final bool isProduction;

  _ShiftInfo({
    required this.shiftId,
    this.deptId,
    required this.deptAbbreviation,
    required this.shiftName,
    required this.startMinutes,
    required this.isProduction,
  });
}

class _DayShiftCell extends StatelessWidget {
  final List<String> shifts;
  final StoreModel store;
  final String? memberDept;

  const _DayShiftCell({
    required this.shifts,
    required this.store,
    this.memberDept,
  });

  List<_ShiftInfo> _parseAndSortShifts() {
    final List<_ShiftInfo> result = [];
    for (final s in shifts) {
      if (s == 'delivery' || s == 'giaohang') continue;
      final parts = s.split('|');
      final baseId = parts[0];
      final deptId = parts.length > 1 ? parts[1] : memberDept;

      final shiftDef = store.customShifts.where((x) => x.id == baseId).firstOrNull;
      final deptDef = deptId != null ? store.departments.where((d) => d.id == deptId).firstOrNull : null;

      String abbr = '';
      if (deptDef != null) {
        abbr = deptDef.shortName.trim().isNotEmpty
            ? deptDef.shortName.trim()
            : deptDef.name.trim();
      } else if (shiftDef != null) {
        abbr = shiftDef.name.trim();
      } else {
        abbr = baseId;
      }

      final startMin = shiftDef != null
          ? (shiftDef.startHour * 60 + shiftDef.startMinute)
          : 9999;

      final isProd = (shiftDef?.isProduction ?? false) ||
          DepartmentUtils.isProduction(
            deptId: deptId,
            deptName: deptDef?.name,
            shortName: deptDef?.shortName,
            storeDepartments: store.departments,
          );

      result.add(_ShiftInfo(
        shiftId: baseId,
        deptId: deptId,
        deptAbbreviation: abbr,
        shiftName: shiftDef?.name ?? baseId,
        startMinutes: startMin,
        isProduction: isProd,
      ));
    }

    // Sort earlier start time on top, later start time below
    result.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final hasDelivery = shifts.contains('delivery');
    final hasGiaoHang = shifts.contains('giaohang');
    final sortedShifts = _parseAndSortShifts();
    final isEmpty = sortedShifts.isEmpty && !hasDelivery && !hasGiaoHang;

    if (isEmpty) {
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE9ECEF), width: 0.8),
        ),
        child: const Center(
          child: Text(
            '—',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFADB5BD),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: sortedShifts.isNotEmpty
            ? AppColors.primary.withOpacity(0.05)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: sortedShifts.isNotEmpty
              ? AppColors.primary.withOpacity(0.25)
              : const Color(0xFFDEE2E6),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Department badges (earlier on top, later below)
          if (sortedShifts.isEmpty)
            const SizedBox(
              height: 16,
              child: Center(
                child: Text('—', style: TextStyle(fontSize: 11, color: Color(0xFFADB5BD))),
              ),
            )
          else
            ...sortedShifts.map((info) {
              return Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                decoration: BoxDecoration(
                  color: info.isProduction
                      ? const Color(0xFFE8F5E9)
                      : AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: info.isProduction
                        ? const Color(0xFFA5D6A7)
                        : AppColors.primary.withOpacity(0.2),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  info.deptAbbreviation,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: info.isProduction
                        ? const Color(0xFF2E7D32)
                        : AppColors.primary,
                  ),
                ),
              );
            }),

          // 2. Separate dedicated section for Delivery (Chở hàng) & Giao hàng
          if (hasDelivery || hasGiaoHang)
            Padding(
              padding: const EdgeInsets.only(top: 1.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasDelivery)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF90CAF9), width: 0.5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_shipping_rounded, size: 9.5, color: Color(0xFF1565C0)),
                        ],
                      ),
                    ),
                  if (hasGiaoHang)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFFFFCC80), width: 0.5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.two_wheeler_rounded, size: 9.5, color: Color(0xFFE65100)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
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
    final avatarProvider = getAvatarImageProvider(member.avatarUrl);
    if (avatarProvider != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: avatarProvider,
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

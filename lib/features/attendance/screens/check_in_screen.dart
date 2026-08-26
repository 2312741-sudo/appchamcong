import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/location_utils.dart';
import '../../../core/utils/department_utils.dart';
import '../../../core/utils/production_checklist_utils.dart';
import '../../../models/attendance_model.dart';
import '../../../models/store_model.dart';
import '../../../models/production_model.dart';
import '../../../models/schedule_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../store/providers/store_provider.dart';
import '../../store/screens/shift_settings_screen.dart';
import '../repositories/attendance_repository.dart';
import '../../production/providers/production_provider.dart';
import '../../schedule/providers/schedule_provider.dart';

// File-local provider (private) to avoid name collision with the global
// todayAttendanceProvider in attendance_provider.dart (which has a different signature).
// Uses watchActiveAttendance to handle cross-midnight shifts correctly.
final _localTodayAttendanceProvider = StreamProvider.family<AttendanceModel?, String>((ref, userId) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value(null);
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.watchActiveAttendance(storeId, userId);
});


class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  CheckInMethod _selectedMethod = CheckInMethod.wifi;
  bool _isLoading = false;
  DateTime _currentTime = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleAttendanceAction(
    AttendanceModel? attendance,
    StoreModel store,
    String userId,
    AttendanceRepository repo,
  ) async {
    setState(() => _isLoading = true);

    try {
      final hasCheckedIn = attendance != null && attendance.checkOut == null;

      if (hasCheckedIn) {
        // 1. Resolve member's department and active attendance check-in time
        final membersList = ref.read(storeMembersProvider).valueOrNull ?? [];
        final currentMember = membersList.where((m) => m.userId == userId).firstOrNull;
        final memberDepartmentId = currentMember?.department;

        final checkInTime = attendance.checkIn;

        // 2. Fetch weekly schedule for check-in week
        final checkInVN = checkInTime.toUtc().add(const Duration(hours: 7));
        final mondayOfCheckIn = checkInVN.subtract(Duration(days: checkInVN.weekday - 1));
        final weekStartStr =
            '${mondayOfCheckIn.year}-${mondayOfCheckIn.month.toString().padLeft(2, '0')}-${mondayOfCheckIn.day.toString().padLeft(2, '0')}';

        ScheduleModel? schedule;
        try {
          final scheduleRepo = ref.read(scheduleRepositoryProvider);
          schedule = await scheduleRepo.getWeekSchedule(store.id, weekStartStr);
        } catch (_) {}

        // 3. Check if a report was already submitted for this workday
        final workdayDateStr =
            '${checkInVN.year}-${checkInVN.month.toString().padLeft(2, '0')}-${checkInVN.day.toString().padLeft(2, '0')}';
        final productionRepo = ref.read(productionRepositoryProvider);
        final hasAlreadyReported =
            await productionRepo.hasReportToday(store.id, userId, workdayDateStr);

        // 4. Evaluate checklist requirement via ProductionChecklistUtils
        final eval = ProductionChecklistUtils.evaluateChecklistRequirement(
          checkInTime: checkInTime,
          now: DateTime.now(),
          userId: userId,
          store: store,
          memberDepartmentId: memberDepartmentId,
          schedule: schedule,
          hasAlreadyReportedForWorkday: hasAlreadyReported,
        );

        if (eval.isRequired) {
          final tasks = await productionRepo.getActiveTasks(store.id);

          if (!mounted) return;
          setState(() => _isLoading = false);
          final result = await _showProductionChecklist(
            context,
            tasks,
            eval.resolvedShift,
            store,
            userId,
            eval.workdayDate,
          );
          if (result != true) {
            // User cancelled/closed checklist modal -> halt checkout
            return;
          }
          if (!mounted) return;
          setState(() => _isLoading = true);
        }

        await repo.checkOut(store.id, userId, isProductionShift: eval.hasProductionShiftOnWorkday);
        _showSuccess('Chấm ra thành công!');
        return;
      }

      // Handle check-in
      bool canCheckIn = false;

      if (_selectedMethod == CheckInMethod.wifi) {
        final allowedIPs = <String>[];
        if (store.networkIP != null && store.networkIP!.trim().isNotEmpty) {
          allowedIPs.add(store.networkIP!.trim());
        }
        for (final wifi in store.wifis) {
          if (wifi.ip.trim().isNotEmpty && !allowedIPs.contains(wifi.ip.trim())) {
            allowedIPs.add(wifi.ip.trim());
          }
        }

        if (allowedIPs.isEmpty) {
          if (!store.hasWifi) throw Exception('Cửa hàng chưa cấu hình WiFi chấm công.');
        } else {
          final isWifiCorrect = await LocationUtils.isOnStoreNetwork(allowedIPs);
          if (!isWifiCorrect) {
            throw Exception('Bạn chưa kết nối đúng mạng WiFi của cửa hàng (hoặc đang dùng 4G/5G). Vui lòng kết nối WiFi tại nơi làm việc để chấm công.');
          }
        }
        canCheckIn = true;
      } else if (_selectedMethod == CheckInMethod.gps) {
        if (store.latitude == null || store.longitude == null) throw Exception('Cửa hàng chưa cấu hình Vị trí.');
        canCheckIn = await LocationUtils.isInStoreRange(store.latitude!, store.longitude!, store.radiusMeters.toDouble());
        if (!canCheckIn) throw Exception('Bạn không ở trong phạm vi cửa hàng.');
      } else {
        canCheckIn = true; // qr or manual
      }

      await repo.checkIn(store.id, userId, _selectedMethod);
      _showSuccess('Chấm công thành công!');
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showProductionChecklist(
    BuildContext context,
    List<ProductionTask> tasks,
    ShiftDefinition shift,
    StoreModel store,
    String userId,
    String workdayDate,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ProductionChecklistDialog(
          tasks: tasks,
          shift: shift,
          storeId: store.id,
          userId: userId,
          workdayDate: workdayDate,
          onSubmitted: () => Navigator.pop(ctx, true),
        );
      },
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final storeAsync = ref.watch(currentStoreProvider);
    if (userId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return storeAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
      data: (store) {
        if (store == null) return const Scaffold(body: Center(child: Text('Không tìm thấy cửa hàng')));
        final attAsync = ref.watch(_localTodayAttendanceProvider(userId));

        return attAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, s) => Scaffold(body: Center(child: Text('Lỗi điểm danh: $e'))),
          data: (attendance) {
            final isCheckedIn = attendance?.isActive ?? false;

            return Scaffold(
              backgroundColor: const Color(0xFFF5F6FA),
              appBar: AppBar(
                title: const Text('Chấm công', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
                centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A1A1A),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => context.pop(),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header Status Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isCheckedIn
                              ? [const Color(0xFF1A6B5A), const Color(0xFF0F4C3F)]
                              : [const Color(0xFF1A1A1A), const Color(0xFF2C2C2C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: (isCheckedIn ? const Color(0xFF1A6B5A) : Colors.black).withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isCheckedIn ? const Color(0xFF63E6BE) : Colors.orangeAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isCheckedIn ? 'ĐANG TRONG CA' : 'CHƯA VÀO CA',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, fontFamily: 'BeVietnamPro'),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy').format(_currentTime),
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontFamily: 'BeVietnamPro'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            DateFormat('HH:mm:ss').format(_currentTime),
                            style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, fontFamily: 'BeVietnamPro', letterSpacing: 1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            store.name,
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'BeVietnamPro'),
                          ),
                          if (isCheckedIn && attendance?.checkIn != null) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.login_rounded, color: Colors.white70, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Giờ vào ca: ${DateFormat('HH:mm').format(attendance!.checkIn.toLocal())}',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'BeVietnamPro'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Method Selector (Only for check-in)
                    if (!isCheckedIn) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Phương thức xác thực',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro', color: Color(0xFF1A1A1A)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MethodCard(
                              icon: Icons.wifi_rounded,
                              label: 'WiFi Cửa hàng',
                              isSelected: _selectedMethod == CheckInMethod.wifi,
                              onTap: () => setState(() => _selectedMethod = CheckInMethod.wifi),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MethodCard(
                              icon: Icons.location_on_rounded,
                              label: 'Định vị GPS',
                              isSelected: _selectedMethod == CheckInMethod.gps,
                              onTap: () => setState(() => _selectedMethod = CheckInMethod.gps),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _handleAttendanceAction(attendance, store, userId, ref.read(attendanceRepositoryProvider)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCheckedIn ? const Color(0xFFC8102E) : const Color(0xFF1A6B5A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(isCheckedIn ? Icons.logout_rounded : Icons.login_rounded),
                                  const SizedBox(width: 10),
                                  Text(
                                    isCheckedIn ? 'KẾT THÚC CA (CHẤM RA)' : 'BẮT ĐẦU CA (CHẤM VÀO)',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro'),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Method Selector Card ──────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A6B5A).withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A6B5A) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1A6B5A) : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF1A6B5A) : Colors.grey.shade700,
                fontFamily: 'BeVietnamPro',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Production Checklist BottomSheet ─────────────────────────────────────────

class _ProductionChecklistDialog extends ConsumerStatefulWidget {
  final List<ProductionTask> tasks;
  final ShiftDefinition shift;
  final String storeId;
  final String userId;
  final String workdayDate;
  final VoidCallback onSubmitted;

  const _ProductionChecklistDialog({
    required this.tasks,
    required this.shift,
    required this.storeId,
    required this.userId,
    required this.workdayDate,
    required this.onSubmitted,
  });

  @override
  ConsumerState<_ProductionChecklistDialog> createState() => _ProductionChecklistDialogState();
}

class _ProductionChecklistDialogState extends ConsumerState<_ProductionChecklistDialog> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _selected = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final t in widget.tasks) {
      _controllers[t.id] = TextEditingController();
      _selected[t.id] = false;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final selectedTasks = widget.tasks.where((t) => _selected[t.id] == true).toList();
    if (selectedTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ít nhất 1 công việc đã hoàn thành')));
      return;
    }

    final entries = <ProductionTaskEntry>[];
    for (final t in selectedTasks) {
      final hasUnit = t.unitLabel.trim().isNotEmpty;
      double val = 1.0;
      if (hasUnit) {
        final valStr = (_controllers[t.id]?.text ?? '0').replaceAll(',', '.');
        val = double.tryParse(valStr) ?? 0.0;
        if (val <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vui lòng nhập số lượng hợp lệ cho ${t.name}')));
          return;
        }
      }
      entries.add(ProductionTaskEntry(
        taskId: t.id,
        taskName: t.name,
        unit: t.unit,
        unitLabel: t.unitLabel,
        value: val,
      ));
    }

    setState(() => _isSubmitting = true);
    try {
      final members = ref.read(storeMembersProvider).valueOrNull ?? [];
      final member = members.where((m) => m.userId == widget.userId).firstOrNull;
      final memberName = member?.name ?? 'Nhân viên';

      final report = ProductionReport(
        id: '',
        userId: widget.userId,
        memberName: memberName,
        date: widget.workdayDate,
        shiftId: widget.shift.id,
        shiftName: widget.shift.name,
        checkoutTime: DateTime.now(),
        note: '',
        tasks: entries,
      );

      await ref.read(productionRepositoryProvider).submitReport(widget.storeId, report);
      if (mounted) {
        widget.onSubmitted(); // Tell parent to continue checkout
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Báo cáo sản xuất', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Text('Vui lòng đánh dấu các công việc đã làm trong ca và nhập số lượng để hệ thống ghi nhận.', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.tasks.length,
              itemBuilder: (ctx, i) {
                final t = widget.tasks[i];
                final isSelected = _selected[t.id] ?? false;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFC8102E).withOpacity(0.05) : Colors.white,
                    border: Border.all(color: isSelected ? const Color(0xFFC8102E) : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    value: isSelected,
                    activeColor: const Color(0xFFC8102E),
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: isSelected ? Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: t.unitLabel.trim().isNotEmpty ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllers[t.id],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                              ],
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Nhập số lượng (${t.unitLabel})...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(t.unitLabel, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                        ],
                      ) : const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF1A6B5A), size: 16),
                          SizedBox(width: 6),
                          Text('Đã hoàn thành', style: TextStyle(color: Color(0xFF1A6B5A), fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ) : null,
                    onChanged: (val) {
                      setState(() => _selected[t.id] = val ?? false);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8102E),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('HOÀN TẤT & RA CA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

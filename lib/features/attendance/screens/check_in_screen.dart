import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/location_utils.dart';
import '../../../models/attendance_model.dart';
import '../../../models/store_model.dart';
import '../../../models/production_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../store/providers/store_provider.dart';
import '../../store/screens/shift_settings_screen.dart';
import '../repositories/attendance_repository.dart';
import '../../production/providers/production_provider.dart';
import '../../production/repositories/production_repository.dart';

final todayAttendanceProvider = StreamProvider.family<AttendanceModel?, String>((ref, userId) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null || storeId.isEmpty) return Stream.value(null);
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.watchTodayAttendance(storeId, userId);
});

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  CheckInMethod _selectedMethod = CheckInMethod.wifi;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckIn(StoreModel store, String userId, bool isCheckedIn) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      
      if (isCheckedIn) {
        // Handle checkout - CHECK IF PRODUCTION SHIFT
        final shifts = ref.read(storeShiftsProvider);
        ShiftDefinition? currentShift;
        final nowTime = TimeOfDay(hour: _currentTime.hour, minute: _currentTime.minute);
        final nowMinutes = nowTime.hour * 60 + nowTime.minute;
        
        for (final s in shifts) {
          final sStart = s.startHour * 60 + s.startMinute;
          var sEnd = s.endHour * 60 + s.endMinute;
          if (sEnd < sStart) sEnd += 24 * 60; // qua ngày
          
          if (nowMinutes >= sStart - 60 && nowMinutes <= sEnd + 60) {
            currentShift = s;
            break;
          }
        }

        bool requiresChecklist = currentShift?.isProduction ?? false;

        if (requiresChecklist) {
          setState(() => _isLoading = false); // Pause loading to show dialog
          final tasks = ref.read(activeProductionTasksProvider).valueOrNull ?? [];
          
          if (tasks.isNotEmpty) {
            final result = await _showProductionChecklist(context, tasks, currentShift!, store, userId);
            if (result != true) return; // User cancelled checkout
            setState(() => _isLoading = true); // Resume loading if submitted
          }
        }

        await repo.checkOut(store.id, userId);
        _showSuccess('Chấm ra thành công!');
        return;
      }

      // Handle check-in
      bool canCheckIn = false;

      if (_selectedMethod == CheckInMethod.wifi) {
        if (!store.hasWifi) throw Exception('Cửa hàng chưa cấu hình WiFi.');
        final allowedIPs = <String>[];
        if (store.networkIP != null && store.networkIP!.isNotEmpty) allowedIPs.add(store.networkIP!);
        for (final wifi in store.wifis) {
          if (wifi.ip.isNotEmpty) allowedIPs.add(wifi.ip);
        }

        final isWifiCorrect = await LocationUtils.isOnStoreNetwork(allowedIPs);
        if (!isWifiCorrect) throw Exception('Sai mạng WiFi! Vui lòng kết nối đúng mạng WiFi của cửa hàng.');
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

  Future<bool?> _showProductionChecklist(BuildContext context, List<ProductionTask> tasks, ShiftDefinition shift, StoreModel store, String userId) {
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
        final attAsync = ref.watch(todayAttendanceProvider(userId));

        return attAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, s) => Scaffold(body: Center(child: Text('Lỗi điểm danh: $e'))),
          data: (attendance) {
            final isCheckedIn = attendance?.isActive ?? false;

            return Scaffold(
              backgroundColor: const Color(0xFFF5F6FA),
              appBar: AppBar(
                title: const Text('Chấm Công', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87), onPressed: () => context.pop()),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Glassmorphism Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFC8102E), Color(0xFFE52040)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: const Color(0xFFC8102E).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                          ),
                          child: Column(
                            children: [
                              Text(DateFormat('EEEE, dd/MM/yyyy', 'vi').format(_currentTime), style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Text(DateFormat('HH:mm:ss').format(_currentTime), style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: 2)),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.storefront_rounded, color: Colors.white.withValues(alpha: 0.9), size: 18),
                                    const SizedBox(width: 8),
                                    Text(store.name, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (!isCheckedIn) ...[
                          const Align(alignment: Alignment.centerLeft, child: Text('Phương thức chấm công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87))),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildMethodCard(CheckInMethod.wifi, Icons.wifi, 'WiFi', store.hasWifi),
                              const SizedBox(width: 16),
                              _buildMethodCard(CheckInMethod.gps, Icons.location_on, 'Vị trí', store.latitude != null),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.login_rounded, color: Colors.green, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Giờ vào ca', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Text(DateFormat('HH:mm').format(attendance!.checkIn.toLocal()), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Check Button
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: isCheckedIn ? 1.0 : _pulseAnimation.value,
                              child: GestureDetector(
                                onTap: _isLoading ? null : () => _handleCheckIn(store, userId, isCheckedIn),
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: isCheckedIn 
                                          ? [const Color(0xFF888780), const Color(0xFF666560)]
                                          : [const Color(0xFF1A6B5A), const Color(0xFF124D41)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isCheckedIn ? const Color(0xFF888780) : const Color(0xFF1A6B5A)).withValues(alpha: 0.4),
                                        blurRadius: 30,
                                        spreadRadius: 10,
                                      )
                                    ],
                                  ),
                                  child: Center(
                                    child: _isLoading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(isCheckedIn ? Icons.logout_rounded : Icons.fingerprint_rounded, color: Colors.white, size: 64),
                                              const SizedBox(height: 12),
                                              Text(isCheckedIn ? 'RA CA' : 'VÀO CA', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 2)),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(isCheckedIn ? 'Bạn đang trong ca làm việc' : 'Nhấn để bắt đầu ca làm việc', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMethodCard(CheckInMethod method, IconData icon, String label, bool isAvailable) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: isAvailable ? () => setState(() => _selectedMethod = method) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1C4E6B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? const Color(0xFF1C4E6B) : Colors.grey.shade300, width: 2),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF1C4E6B).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: isAvailable ? (isSelected ? Colors.white : Colors.grey.shade600) : Colors.grey.shade300, size: 32),
              const SizedBox(height: 12),
              Text(label, style: TextStyle(color: isAvailable ? (isSelected ? Colors.white : Colors.black87) : Colors.grey.shade400, fontWeight: FontWeight.w600)),
            ],
          ),
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
  final VoidCallback onSubmitted;

  const _ProductionChecklistDialog({
    required this.tasks,
    required this.shift,
    required this.storeId,
    required this.userId,
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
      final valStr = _controllers[t.id]?.text ?? '0';
      final val = double.tryParse(valStr) ?? 0.0;
      if (val <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vui lòng nhập số lượng hợp lệ cho ${t.name}')));
        return;
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
      final member = ref.read(storeMembersProvider).valueOrNull?.firstWhere((m) => m.userId == widget.userId);
      final memberName = member?.name ?? 'Nhân viên';
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final report = ProductionReport(
        id: '',
        userId: widget.userId,
        memberName: memberName,
        date: dateStr,
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
                    color: isSelected ? const Color(0xFFC8102E).withValues(alpha: 0.05) : Colors.white,
                    border: Border.all(color: isSelected ? const Color(0xFFC8102E) : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    value: isSelected,
                    activeColor: const Color(0xFFC8102E),
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: isSelected ? Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllers[t.id],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Nhập số lượng...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(t.unitLabel, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
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

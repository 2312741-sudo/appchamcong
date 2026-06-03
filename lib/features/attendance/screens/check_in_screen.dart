import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/check_in_button.dart';
import '../../../core/utils/location_utils.dart';
import '../../../models/attendance_model.dart';
import '../../../models/store_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../store/providers/store_provider.dart';
import '../repositories/attendance_repository.dart';

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

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  bool _isLoading = false;
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  CheckInMethod? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _handleCheckIn(StoreModel store, String userId, bool isCheckedIn) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      
      if (isCheckedIn) {
        // Handle checkout (don't strictly need location/IP, but let's allow it easily)
        await repo.checkOut(store.id, userId);
        _showSuccess('Chấm ra thành công!');
        return;
      }

      // Handle check-in
      bool canCheckIn = false;
      CheckInMethod method = _selectedMethod ?? CheckInMethod.wifi;

      if (method == CheckInMethod.wifi) {
        if (store.networkIP == null || store.networkIP!.isEmpty) {
          throw Exception('Cửa hàng chưa cấu hình WiFi.');
        }
        final isWifiCorrect = await LocationUtils.isOnStoreNetwork(store.networkIP!);
        if (!isWifiCorrect) {
          throw Exception('Sai mạng WiFi! Vui lòng kết nối đúng mạng WiFi của cửa hàng để chấm công.');
        }
        canCheckIn = true;
      } else if (method == CheckInMethod.gps) {
        if (store.latitude == null || store.longitude == null) {
          throw Exception('Cửa hàng chưa cấu hình Vị trí.');
        }
        canCheckIn = await LocationUtils.isInStoreRange(store.latitude!, store.longitude!, store.radiusMeters.toDouble());
        if (!canCheckIn) {
          throw Exception('Bạn không ở trong phạm vi cửa hàng.');
        }
      }

      await repo.checkIn(store.id, userId, method);
      _showSuccess('Chấm công thành công!');

    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final store = ref.watch(currentStoreProvider).value;
    
    if (user == null || store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final attendanceStream = ref.watch(todayAttendanceProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chấm công', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: attendanceStream.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => Center(child: Text('Lỗi: $err')),
          data: (attendance) {
            final isCheckedIn = attendance != null && attendance.isActive;
            final timeString = '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}';
            final dateString = '${_currentTime.day.toString().padLeft(2, '0')}/${_currentTime.month.toString().padLeft(2, '0')}/${_currentTime.year}';
            final secondString = _currentTime.second.toString().padLeft(2, '0');

            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dateString,
                          style: const TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              timeString,
                              style: const TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 64,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              '.$secondString',
                              style: const TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (!isCheckedIn) ...[
                          SegmentedButton<CheckInMethod>(
                            segments: const [
                              ButtonSegment(
                                value: CheckInMethod.wifi,
                                label: Text('WiFi', style: TextStyle(fontFamily: 'BeVietnamPro')),
                                icon: Icon(Icons.wifi),
                              ),
                              ButtonSegment(
                                value: CheckInMethod.gps,
                                label: Text('Vị trí', style: TextStyle(fontFamily: 'BeVietnamPro')),
                                icon: Icon(Icons.location_on),
                              ),
                            ],
                            selected: { _selectedMethod ?? CheckInMethod.wifi },
                            onSelectionChanged: (Set<CheckInMethod> newSelection) {
                              setState(() {
                                _selectedMethod = newSelection.first;
                              });
                            },
                            style: SegmentedButton.styleFrom(
                              backgroundColor: Colors.white,
                              selectedForegroundColor: Colors.white,
                              selectedBackgroundColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ] else ...[
                          const SizedBox(height: 48),
                        ],
                        CheckInButton(
                          isCheckedIn: isCheckedIn,
                          isLoading: _isLoading,
                          onPressed: () => _handleCheckIn(store, user.id, isCheckedIn),
                        ),
                      ],
                    ),
                  ),
                ),
                // Additional Info
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (attendance != null) ...[
                        _buildInfoRow('Giờ vào', '${attendance.checkIn.toLocal().hour.toString().padLeft(2, '0')}:${attendance.checkIn.toLocal().minute.toString().padLeft(2, '0')}'),
                        const Divider(height: 24),
                        _buildInfoRow('Phương thức', attendance.checkInMethod.label),
                      ] else ...[
                        const Text(
                          'Bạn chưa chấm công hôm nay.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'BeVietnamPro', color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontFamily: 'BeVietnamPro', color: AppColors.textSecondary, fontSize: 15),
        ),
        Text(
          value,
          style: const TextStyle(fontFamily: 'BeVietnamPro', color: AppColors.neutral, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

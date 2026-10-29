import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Nhắc đặt hàng trước giờ chốt (thông báo cục bộ trên máy):
/// chỉ khi đang trong ca và phiếu NGÀY MAI còn trống. Thêm hàng vào phiếu → hủy nhắc.
class SupplyReminderService {
  SupplyReminderService._();
  static final SupplyReminderService instance = SupplyReminderService._();

  static const int notifId = 880021;
  static const int minutesBefore = 30;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _tzReady = false;
  String? _lastKey;

  /// Mốc nhắc của HÔM NAY: [cutoff] "HH:mm" (giờ VN) trừ [minutesBefore] phút; đã qua → null. Thuần, để test.
  static DateTime? reminderTime(String? cutoff, DateTime nowUtc, {int before = minutesBefore}) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch((cutoff ?? '').trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final mi = int.parse(m.group(2)!);
    if (h > 23 || mi > 59) return null;
    final vn = nowUtc.toUtc().add(const Duration(hours: 7));
    final at = DateTime.utc(vn.year, vn.month, vn.day, h, mi)
        .subtract(const Duration(hours: 7))
        .subtract(Duration(minutes: before));
    return at.isAfter(nowUtc.toUtc()) ? at : null;
  }

  /// Đặt hoặc hủy nhắc theo tình trạng hiện tại (gọi lại nhiều lần an toàn)
  Future<void> sync({required String? cutoff, required bool onShift, required bool tomorrowEmpty}) async {
    final at = (onShift && tomorrowEmpty) ? reminderTime(cutoff, DateTime.now().toUtc()) : null;
    final key = at?.toIso8601String() ?? 'none';
    if (key == _lastKey) return;
    _lastKey = key;
    try {
      await _plugin.cancel(notifId);
      if (at == null) return;
      if (!_tzReady) {
        tz.initializeTimeZones();
        _tzReady = true;
      }
      await _plugin.zonedSchedule(
        notifId,
        'Sắp chốt đặt hàng',
        'Còn $minutesBefore phút nữa chốt đặt hàng ngày mai ($cutoff). Phiếu ngày mai vẫn trống — vào "Đặt & soạn hàng" nếu cần đặt.',
        tz.TZDateTime.from(at, tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'supply_reminders',
            'Nhắc đặt hàng',
            channelDescription: 'Nhắc đặt hàng trước giờ chốt',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: '/supply-order',
      );
    } catch (e) {
      debugPrint('SupplyReminderService sync error: $e');
    }
  }

  /// Gọi khi lịch nhắc ca bị hủy toàn bộ (cancelAll) để lần đồng bộ sau đặt lại
  void reset() => _lastKey = null;
}

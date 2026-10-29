import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Hẹn thông báo hệ thống (hiện ngoài app, kể cả khi app đã tắt).
/// Ưu tiên báo đúng giờ; Android 12+ chưa cấp quyền "Báo thức chính xác" thì lùi về báo gần đúng thay vì bỏ qua.
Future<void> scheduleLocalNotification(
  FlutterLocalNotificationsPlugin plugin, {
  required int id,
  required String title,
  required String body,
  required tz.TZDateTime at,
  required NotificationDetails details,
  String? payload,
}) async {
  Future<void> schedule(AndroidScheduleMode mode) => plugin.zonedSchedule(
        id,
        title,
        body,
        at,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
  try {
    await schedule(AndroidScheduleMode.exactAllowWhileIdle);
  } on PlatformException catch (e) {
    if (e.code != 'exact_alarms_not_permitted') rethrow;
    await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
  }
}

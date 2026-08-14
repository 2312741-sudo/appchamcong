import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Lazy-initialize these - do NOT access FirebaseMessaging.instance at field level
  FirebaseMessaging? _fcm;
  FlutterLocalNotificationsPlugin? _localNotifications;

  bool _initialized = false;

  // Keep track of subscriptions so we can cancel them on dispose
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<String>? _onTokenRefreshSubscription;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _fcm = FirebaseMessaging.instance;
      _localNotifications = FlutterLocalNotificationsPlugin();

      // Request permission
      final settings = await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('User declined notification permission');
        return;
      }

      // Initialize local notifications for foreground display
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications!.initialize(initSettings);

      // Handle foreground messages — store subscription to allow cancellation
      _onMessageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showLocalNotification(message);
        }
      });

      _initialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize NotificationService: $e');
    }
  }

  /// Call this AFTER user logs in to save FCM token
  Future<void> saveTokenForUser(String uid) async {
    if (_fcm == null) return;
    try {
      // On iOS, APNS token may not be ready immediately.
      // Wait up to 10 seconds for it to become available.
      String? apnsToken = await _fcm!.getAPNSToken();
      if (apnsToken == null) {
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(seconds: 1));
          apnsToken = await _fcm!.getAPNSToken();
          if (apnsToken != null) break;
        }
      }

      final token = await _fcm!.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Cancel previous token refresh subscription before creating new one
      await _onTokenRefreshSubscription?.cancel();
      _onTokenRefreshSubscription = _fcm!.onTokenRefresh.listen((newToken) async {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'fcmToken': newToken,
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Failed to update FCM token: $e');
        }
      });
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  Future<void> updateToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await saveTokenForUser(uid);
    }
  }

  /// Call this when the user logs out or app is being cleaned up
  Future<void> dispose() async {
    await _onMessageSubscription?.cancel();
    await _onTokenRefreshSubscription?.cancel();
    _onMessageSubscription = null;
    _onTokenRefreshSubscription = null;
    _initialized = false;
    _fcm = null;
    _localNotifications = null;
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || _localNotifications == null) return;

    const androidDetails = AndroidNotificationDetails(
      'schedule_updates',
      'Cập nhật lịch làm',
      channelDescription: 'Thông báo khi có thay đổi lịch làm',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications!.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }
}

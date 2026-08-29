import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Navigation pending state for cold start
  static String? pendingRoute;
  static Map<String, dynamic>? pendingRouteExtra;

  // Lazy-initialize these - do NOT access FirebaseMessaging.instance at field level
  FirebaseMessaging? _fcm;
  FlutterLocalNotificationsPlugin? _localNotifications;

  bool _initialized = false;

  // Keep track of subscriptions so we can cancel them on dispose
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
  StreamSubscription<String>? _onTokenRefreshSubscription;

  /// Handle navigating to the destination when user taps a notification
  static Future<void> handleNotificationTap({String? routePath, Map<String, dynamic>? extra}) async {
    final targetRoute = (routePath != null && routePath.isNotEmpty) ? routePath : AppRoutes.notifications;
    final targetStoreId = extra?['storeId'] as String? ?? extra?['store_id'] as String?;

    // Auto-switch store if targetStoreId is present in payload
    if (targetStoreId != null && targetStoreId.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            final currentStoreId = userData?['currentStoreId'] as String?;
            final storeIds = List<String>.from(userData?['storeIds'] ?? []);

            // Check if user has access to targetStoreId
            final isMember = storeIds.contains(targetStoreId);
            if (isMember && currentStoreId != targetStoreId) {
              await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                'currentStoreId': targetStoreId,
              });
              debugPrint('Auto-switched current store to: $targetStoreId from notification payload');
            }
          }
        } catch (e) {
          debugPrint('Error auto-switching store from notification: $e');
        }
      }
    }

    final context = rootNavigatorKey.currentContext;
    debugPrint('Notification tapped -> routing to: $targetRoute');

    if (context != null && context.mounted) {
      try {
        if (extra != null) {
          context.push(targetRoute, extra: extra);
        } else {
          context.push(targetRoute);
        }
        pendingRoute = null;
        pendingRouteExtra = null;
        return;
      } catch (e) {
        debugPrint('Direct notification navigation failed: $e, queuing for splash');
      }
    }

    // If navigator context is not ready yet, save as pending route
    pendingRoute = targetRoute;
    pendingRouteExtra = extra;
  }

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

      // Enable foreground notification presentation on iOS
      await _fcm!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Initialize local notifications for foreground display
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications!.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final data = jsonDecode(response.payload!) as Map<String, dynamic>;
              final routePath = data['routePath'] as String?;
              handleNotificationTap(routePath: routePath, extra: data);
            } catch (_) {
              handleNotificationTap(routePath: response.payload);
            }
          } else {
            handleNotificationTap();
          }
        },
      );

      // Create Android Notification Channel
      const androidChannel = AndroidNotificationChannel(
        'cham_cong_notifications',
        'Thông báo Chấm Công',
        description: 'Thông báo lịch làm việc, chấm công, tạm ứng và duyệt đơn',
        importance: Importance.max,
        playSound: true,
      );
      await _localNotifications!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Handle foreground messages — store subscription to allow cancellation
      _onMessageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showLocalNotification(message);
        }
      });

      // Handle notification taps when app is in background
      _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final routePath = message.data['routePath'] as String?;
        handleNotificationTap(routePath: routePath, extra: message.data);
      });

      // Check if app was opened from terminated state via notification click
      final initialMessage = await _fcm!.getInitialMessage();
      if (initialMessage != null) {
        final routePath = initialMessage.data['routePath'] as String?;
        handleNotificationTap(routePath: routePath, extra: initialMessage.data);
      }

      _initialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize NotificationService: $e');
    }
  }

  /// Call this AFTER user logs in to save FCM token and remove stale associations
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

      // 1. Deduplication: Clear this token from any OTHER user documents in Firestore
      try {
        final existingWithToken = await FirebaseFirestore.instance
            .collection('users')
            .where('fcmToken', isEqualTo: token)
            .get();

        if (existingWithToken.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          bool hasOtherUsers = false;
          for (final doc in existingWithToken.docs) {
            if (doc.id != uid) {
              batch.update(doc.reference, {
                'fcmToken': FieldValue.delete(),
                'tokenClearedAt': FieldValue.serverTimestamp(),
              });
              hasOtherUsers = true;
            }
          }
          if (hasOtherUsers) {
            await batch.commit();
            debugPrint('Deduplicated FCM token: cleared from previous accounts on this device');
          }
        }
      } catch (e) {
        debugPrint('Error deduplicating FCM tokens: $e');
      }

      // 2. Save token for the current active user
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Cancel previous token refresh subscription before creating new one
      await _onTokenRefreshSubscription?.cancel();
      _onTokenRefreshSubscription = _fcm!.onTokenRefresh.listen((newToken) async {
        try {
          // Deduplicate new token
          final staleDocs = await FirebaseFirestore.instance
              .collection('users')
              .where('fcmToken', isEqualTo: newToken)
              .get();

          final refreshBatch = FirebaseFirestore.instance.batch();
          for (final doc in staleDocs.docs) {
            if (doc.id != uid) {
              refreshBatch.update(doc.reference, {
                'fcmToken': FieldValue.delete(),
              });
            }
          }
          refreshBatch.set(
            FirebaseFirestore.instance.collection('users').doc(uid),
            {
              'fcmToken': newToken,
              'tokenUpdatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          await refreshBatch.commit();
        } catch (e) {
          debugPrint('Failed to update refreshed FCM token: $e');
        }
      });
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  /// Call this when the user logs out: removes token from Firestore, deletes device token and disposes listeners
  Future<void> clearTokenForUser(String uid) async {
    try {
      if (uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': FieldValue.delete(),
          'tokenClearedAt': FieldValue.serverTimestamp(),
        }).catchError((e) {
          debugPrint('Could not delete fcmToken on user doc: $e');
        });
      }
      if (_fcm != null) {
        await _fcm!.deleteToken().catchError((e) {
          debugPrint('Could not delete FCM device token: $e');
        });
      }
      await dispose();
      debugPrint('FCM token successfully cleared for user $uid on logout');
    } catch (e) {
      debugPrint('Error clearing FCM token for user $uid: $e');
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
    await _onMessageOpenedAppSubscription?.cancel();
    await _onTokenRefreshSubscription?.cancel();
    _onMessageSubscription = null;
    _onMessageOpenedAppSubscription = null;
    _onTokenRefreshSubscription = null;
    _initialized = false;
    _fcm = null;
    _localNotifications = null;
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || _localNotifications == null) return;

    const androidDetails = AndroidNotificationDetails(
      'cham_cong_notifications',
      'Thông báo Chấm Công',
      channelDescription: 'Thông báo lịch làm việc, chấm công, tạm ứng và duyệt đơn',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final payloadStr = jsonEncode(message.data);

    await _localNotifications!.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: payloadStr,
    );
  }
}

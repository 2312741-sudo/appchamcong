import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/app_notification_model.dart';
import '../../../models/member_model.dart';
import '../../../core/auth/app_permissions.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _items(String userId, String storeId) =>
      _firestore.collection('notificationInboxes').doc(userId)
          .collection('stores').doc(storeId).collection('items');
  CollectionReference<Map<String, dynamic>> _account(String userId) =>
      _firestore.collection('notificationInboxes').doc(userId).collection('accountItems');

  static List<String> scopes(UserRole? role, {bool notifyShiftInOut = true}) => [
    if (role != null) 'member',
    if (AppPermissions.canApproveMembers(role)) 'approver',
    if (AppPermissions.canViewAllAttendance(role) && notifyShiftInOut) 'attendance',
    if (role == UserRole.owner) 'owner',
  ];

  Stream<List<AppNotificationModel>> watchNotifications(String storeId,
      String? userId, UserRole? role, {bool notifyShiftInOut = true, int limit = 50,
      bool unreadOnly = false}) {
    if (userId == null || userId.isEmpty) return Stream.value([]);
    final allowed = scopes(role, notifyShiftInOut: notifyShiftInOut);
    final queries = <Query<Map<String, dynamic>>>[_account(userId)];
    if (storeId.isNotEmpty && allowed.isNotEmpty) {
      queries.add(_items(userId, storeId).where('scope', whereIn: allowed));
    }
    final controller = StreamController<List<AppNotificationModel>>();
    final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final pages = <int, List<AppNotificationModel>>{};
    controller.onListen = () {
      for (var index = 0; index < queries.length; index++) {
        final key = index;
        final query = unreadOnly
            ? queries[index].where('readAt', isNull: true)
            : queries[index].orderBy('createdAt', descending: true).limit(limit);
        subscriptions.add(query.snapshots().listen((snapshot) {
          pages[key] = snapshot.docs.map(AppNotificationModel.fromFirestore).toList();
          if (pages.length != queries.length) return;
          final items = pages.values.expand((page) => page).toList()
            ..sort((a, b) {
              final order = b.createdAt.compareTo(a.createdAt);
              return order != 0 ? order : a.id.compareTo(b.id);
            });
          controller.add(items);
        }, onError: controller.addError));
      }
    };
    controller.onCancel = () async {
      for (final subscription in subscriptions) { await subscription.cancel(); }
    };
    return controller.stream;
  }

  Stream<int> watchUnreadCount(String storeId, String? userId, UserRole? role,
      {bool notifyShiftInOut = true}) => watchNotifications(storeId, userId, role,
        notifyShiftInOut: notifyShiftInOut, unreadOnly: true).map((items) => items.length);

  Future<void> markAsRead(String storeId, String notificationId, String userId,
      {bool account = false}) async {
    if (notificationId.isEmpty || userId.isEmpty) return;
    final collection = account ? _account(userId) : _items(userId, storeId);
    await collection.doc(notificationId).update({'readAt': FieldValue.serverTimestamp()});
  }

  /// Mark a snapshot of unread items. New arrivals remain unread; batches stay below 500.
  Future<void> markAllAsRead(String storeId, String userId, UserRole? role,
      {bool notifyShiftInOut = true}) async {
    final allowed = scopes(role, notifyShiftInOut: notifyShiftInOut);
    final queries = <Query<Map<String, dynamic>>>[_account(userId)];
    if (storeId.isNotEmpty && allowed.isNotEmpty) {
      queries.add(_items(userId, storeId).where('scope', whereIn: allowed));
    }
    final snapshots = await Future.wait(queries.map((query) => query.where('readAt', isNull: true).get()));
    final docs = snapshots.expand((snapshot) => snapshot.docs).toList();
    for (var offset = 0; offset < docs.length; offset += 400) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(offset).take(400)) {
        batch.update(doc.reference, {'readAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
    }
  }
}

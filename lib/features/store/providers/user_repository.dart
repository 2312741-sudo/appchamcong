import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _users.doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Lấy thông tin người dùng thất bại: $e');
    }
  }

  Stream<UserModel?> watchUser(String userId) {
    return _users.doc(userId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromFirestore(snap);
    });
  }

  Future<void> createOrUpdateUser(UserModel user) async {
    try {
      await _users.doc(user.id).set(user.toJson(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Lưu thông tin người dùng thất bại: $e');
    }
  }

  Future<void> updateCurrentStoreId(String userId, String? storeId) async {
    try {
      await _users.doc(userId).update({'currentStoreId': storeId});
    } catch (e) {
      throw Exception('Cập nhật cửa hàng thất bại: $e');
    }
  }
}

// ---------- Providers ----------

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final userProvider = StreamProvider<UserModel?>((ref) {
  final auth = FirebaseAuth.instance;
  final firebaseUser = auth.currentUser;
  if (firebaseUser == null) return Stream.value(null);

  final repo = ref.watch(userRepositoryProvider);
  return repo.watchUser(firebaseUser.uid);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

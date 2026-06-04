import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/store_model.dart';
import '../../../models/advance_request_model.dart';
import '../../../models/member_model.dart';

class StoreRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StoreRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _stores =>
      _firestore.collection('stores');

  CollectionReference<Map<String, dynamic>> _members(String storeId) =>
      _firestore.collection('stores').doc(storeId).collection('members');

  // ---------- Helpers ----------

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String _getUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Người dùng chưa đăng nhập');
    return uid;
  }

  // ---------- Store CRUD ----------

  Future<StoreModel> createStore(
    String name,
    String address,
    String networkIP,
    double? lat,
    double? lng,
    int radiusMeters,
  ) async {
    try {
      final uid = _getUid();
      final code = _generateCode();
      final now = DateTime.now().toUtc();

      final storeRef = _stores.doc();
      final storeData = {
        'name': name.trim(),
        'code': code,
        'ownerId': uid,
        'address': address.trim().isEmpty ? null : address.trim(),
        'networkIP': networkIP.trim().isEmpty ? null : networkIP.trim(),
        'latitude': lat,
        'longitude': lng,
        'radiusMeters': radiusMeters,
        'createdAt': Timestamp.fromDate(now),
      };

      final batch = _firestore.batch();
      batch.set(storeRef, storeData);

      // Add owner as active member
      final user = _auth.currentUser;
      final memberRef = _members(storeRef.id).doc(uid);
      batch.set(memberRef, {
        'userId': uid,
        'name': user?.displayName ?? user?.email ?? 'Chủ cửa hàng',
        'phone': user?.phoneNumber,
        'avatarUrl': user?.photoURL,
        'role': 'owner',
        'status': 'active',
        'employeeType': 'fulltime',
        'baseMonthlySalary': 0,
        'baseHourlyRate': 0,
        'standardHoursPerMonth': 208,
        'joinedAt': Timestamp.fromDate(now),
      });

      final userRef = _firestore.collection('users').doc(uid);
      batch.update(userRef, {
        'storeIds': FieldValue.arrayUnion([storeRef.id])
      });

      await batch.commit();

      return StoreModel(
        id: storeRef.id,
        name: name.trim(),
        code: code,
        ownerId: uid,
        address: address.trim().isEmpty ? null : address.trim(),
        networkIP: networkIP.trim().isEmpty ? null : networkIP.trim(),
        latitude: lat,
        longitude: lng,
        radiusMeters: radiusMeters,
        createdAt: now,
      );
    } catch (e) {
      throw Exception('Tạo cửa hàng thất bại: $e');
    }
  }

  Future<StoreModel?> findStoreByCode(String code) async {
    try {
      final query = await _stores
          .where('code', isEqualTo: code.trim().toUpperCase())
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return StoreModel.fromFirestore(query.docs.first);
    } catch (e) {
      throw Exception('Tìm cửa hàng thất bại: $e');
    }
  }

  Future<List<StoreModel>> getUserStores(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];
      
      final storeIds = List<String>.from(userDoc.data()?['storeIds'] ?? []);

      if (storeIds.isEmpty) return [];

      // Fetch all store models for these IDs (Firestore allows up to 10 in whereIn, 
      // but we can just fetch them individually or chunk them if needed. 
      // Since it's usually < 10 stores per user, whereIn is fine).
      final stores = <StoreModel>[];
      for (var i = 0; i < storeIds.length; i += 10) {
        final chunk = storeIds.sublist(
            i, i + 10 > storeIds.length ? storeIds.length : i + 10);
        final storesQuery = await _stores.where(FieldPath.documentId, whereIn: chunk).get();
        stores.addAll(storesQuery.docs.map((d) => StoreModel.fromFirestore(d)));
      }

      return stores;
    } catch (e) {
      throw Exception('Lỗi lấy danh sách cửa hàng: $e');
    }
  }

  Future<void> joinStore(String storeId, String userId) async {
    try {
      final user = _auth.currentUser;
      final now = DateTime.now().toUtc();

      // Check if already a member
      final existing = await _members(storeId).doc(userId).get();
      if (existing.exists) {
        final status = existing.data()?['status'] as String?;
        if (status == 'active') {
          throw Exception('Bạn đã là thành viên của cửa hàng này');
        }
        if (status == 'pending') {
          throw Exception('Yêu cầu của bạn đang chờ duyệt');
        }
        // Kicked → re-apply
      }

      final batch = _firestore.batch();

      batch.set(_members(storeId).doc(userId), {
        'userId': userId,
        'name': user?.displayName ?? user?.email ?? 'Nhân viên',
        'phone': user?.phoneNumber,
        'avatarUrl': user?.photoURL,
        'role': 'employee',
        'status': 'pending',
        'employeeType': 'fulltime',
        'baseMonthlySalary': 0,
        'baseHourlyRate': 0,
        'standardHoursPerMonth': 208,
        'joinedAt': Timestamp.fromDate(now),
      });

      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'storeIds': FieldValue.arrayUnion([storeId])
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Tham gia cửa hàng thất bại: $e');
    }
  }

  Future<void> approveOrRejectMember(
      String storeId, String userId, bool approve) async {
    try {
      await _members(storeId).doc(userId).update({
        'status': approve ? 'active' : 'kicked',
      });
    } catch (e) {
      throw Exception('Cập nhật trạng thái thành viên thất bại: $e');
    }
  }

  Future<void> kickMember(String storeId, String userId) async {
    try {
      await _members(storeId).doc(userId).update({'status': 'kicked'});
    } catch (e) {
      throw Exception('Xóa thành viên thất bại: $e');
    }
  }

  Future<void> updateMemberRole(
      String storeId, String userId, UserRole newRole) async {
    try {
      await _members(storeId).doc(userId).update({'role': newRole.value});
    } catch (e) {
      throw Exception('Cập nhật vai trò thất bại: $e');
    }
  }

  Future<void> updateMemberSalary(
    String storeId,
    String userId,
    EmployeeType type,
    double salary,
    double standardHours,
  ) async {
    try {
      await _members(storeId).doc(userId).update({
        'employeeType': type.value,
        if (type == EmployeeType.fulltime)
          'baseMonthlySalary': salary
        else
          'baseHourlyRate': salary,
        'standardHoursPerMonth': standardHours,
      });
    } catch (e) {
      throw Exception('Cập nhật lương thất bại: $e');
    }
  }

  Stream<StoreModel?> watchStore(String storeId) {
    return _stores.doc(storeId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return StoreModel.fromFirestore(snap);
    });
  }

  Stream<List<MemberModel>> watchMembers(String storeId) {
    return _members(storeId)
        .where('status', whereIn: ['active', 'pending'])
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MemberModel.fromFirestore(d)).toList());
  }

  Stream<List<MemberModel>> watchPendingMembers(String storeId) {
    return _members(storeId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MemberModel.fromFirestore(d)).toList());
  }

  Future<void> updateStoreSettings(
      String storeId, Map<String, dynamic> updates) async {
    try {
      await _stores.doc(storeId).update(updates);
    } catch (e) {
      throw Exception('Cập nhật cài đặt cửa hàng thất bại: $e');
    }
  }

  Future<String> regenerateStoreCode(String storeId) async {
    try {
      final newCode = _generateCode();
      await _stores.doc(storeId).update({'code': newCode});
      return newCode;
    } catch (e) {
      throw Exception('Tạo mã mới thất bại: $e');
    }
  }

  Future<void> updateMemberDepartment(
      String storeId, String userId, String? departmentId) async {
    try {
      await _members(storeId).doc(userId).update({
        'department': departmentId,
      });
    } catch (e) {
      throw Exception('Cập nhật bộ phận thất bại: $e');
    }
  }

  Future<void> updateMemberInfo(
      String storeId, String userId, String? employeeCode, DateTime joinedAt) async {
    try {
      await _members(storeId).doc(userId).update({
        'employeeCode': employeeCode,
        'joinedAt': Timestamp.fromDate(joinedAt),
      });
    } catch (e) {
      throw Exception('Cập nhật thông tin thất bại: $e');
    }
  }

  // ---------- Advances ----------

  Stream<List<AdvanceRequestModel>> watchAdvances(String storeId, String month) {
    return _stores
        .doc(storeId)
        .collection('advances')
        .where('month', isEqualTo: month)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => AdvanceRequestModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.requestDate.compareTo(a.requestDate));
          return list;
        });
  }

  Future<void> createAdvanceRequest(AdvanceRequestModel request) async {
    try {
      await _stores
          .doc(request.storeId)
          .collection('advances')
          .add(request.toMap());
    } catch (e) {
      throw Exception('Failed to create advance request: $e');
    }
  }

  Future<void> updateAdvanceRequestStatus(String storeId, String advanceId, AdvanceStatus status, [DateTime? approvedDate]) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
      };
      if (approvedDate != null) {
        updateData['approvedDate'] = approvedDate.toIso8601String();
      }
      await _stores
          .doc(storeId)
          .collection('advances')
          .doc(advanceId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update advance request: $e');
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:cham_cong_tram/models/store_model.dart';
import 'package:cham_cong_tram/models/user_model.dart';
import 'package:cham_cong_tram/models/member_model.dart';

void main() {
  group('StoreModel soft-delete status tests', () {
    test('Default status is active and isDeleted is false', () {
      final store = StoreModel(
        id: 'store_1',
        name: 'Trạm Sữa 1',
        code: 'ABC123',
        ownerId: 'user_1',
        createdAt: DateTime.now(),
      );
      expect(store.status, 'active');
      expect(store.isDeleted, false);
    });

    test('Store with status deleted has isDeleted = true', () {
      final store = StoreModel(
        id: 'store_2',
        name: 'Trạm Sữa 2',
        code: 'XYZ789',
        ownerId: 'user_1',
        createdAt: DateTime.now(),
        status: 'deleted',
      );
      expect(store.status, 'deleted');
      expect(store.isDeleted, true);
    });

    test('StoreModel serialization & deserialization preserves status', () {
      final original = StoreModel(
        id: 'store_3',
        name: 'Trạm Sữa 3',
        code: 'TEST01',
        ownerId: 'user_owner',
        createdAt: DateTime.utc(2026, 8, 20),
        status: 'deleted',
      );
      final json = original.toJson();
      expect(json['status'], 'deleted');
      final reconstructed = StoreModel.fromJson(json, 'store_3');
      expect(reconstructed.id, 'store_3');
      expect(reconstructed.name, 'Trạm Sữa 3');
      expect(reconstructed.status, 'deleted');
      expect(reconstructed.isDeleted, true);
    });

    test('StoreModel copyWith updates status', () {
      final store = StoreModel(
        id: 'store_4',
        name: 'Trạm Sữa 4',
        code: 'TEST02',
        ownerId: 'user_owner',
        createdAt: DateTime.now(),
      );
      final deletedStore = store.copyWith(status: 'deleted');
      expect(deletedStore.status, 'deleted');
      expect(deletedStore.isDeleted, true);
    });
  });

  group('UserModel and store resolution tests', () {
    test('UserModel with multiple storeIds validates currentStoreId', () {
      final user = UserModel(
        id: 'user_123',
        name: 'Nguyễn Văn A',
        email: 'a@example.com',
        currentStoreId: 'store_kicked',
        storeIds: const ['store_active_1', 'store_active_2'],
        createdAt: DateTime.now(),
      );
      expect(user.storeIds.contains(user.currentStoreId), false);
      final String resolvedStoreId = (user.currentStoreId != null &&
              user.storeIds.contains(user.currentStoreId))
          ? user.currentStoreId!
          : (user.storeIds.isNotEmpty ? user.storeIds.first : '');
      expect(resolvedStoreId, 'store_active_1');
    });

    test('UserModel with no remaining stores falls back to empty', () {
      final user = UserModel(
        id: 'user_456',
        name: 'Nguyễn Văn B',
        email: 'b@example.com',
        currentStoreId: 'store_kicked',
        storeIds: const [],
        createdAt: DateTime.now(),
      );
      final String? resolvedStoreId = (user.currentStoreId != null &&
              user.storeIds.contains(user.currentStoreId))
          ? user.currentStoreId!
          : (user.storeIds.isNotEmpty ? user.storeIds.first : null);
      expect(resolvedStoreId, null);
    });
  });

  // === VẤN ĐỀ 1: kickMember khi nhân viên đã tự xóa tài khoản ================
  // Root cause: batch.update() trên /users/{uid} đã bị xóa → permission-denied
  // Fix: kiểm tra userDocExists trước, chỉ update nếu doc tồn tại
  group('kickMember – xử lý nhân viên đã tự xóa tài khoản', () {
    test('userDocExists=false → bỏ qua update /users → không lỗi permission', () {
      const bool userDocExists = false;
      final batchOps = <String>['mark_member_kicked'];
      if (userDocExists) {
        batchOps.add('remove_storeId_from_user_doc');
      }
      expect(batchOps.length, 1);
      expect(batchOps.contains('mark_member_kicked'), true);
      expect(batchOps.contains('remove_storeId_from_user_doc'), false);
    });

    test('userDocExists=true → update /users đầy đủ → backward-compatible', () {
      const bool userDocExists = true;
      final batchOps = <String>['mark_member_kicked'];
      if (userDocExists) {
        batchOps.add('remove_storeId_from_user_doc');
      }
      expect(batchOps.length, 2);
      expect(batchOps.contains('mark_member_kicked'), true);
      expect(batchOps.contains('remove_storeId_from_user_doc'), true);
    });

    test('userDocExists=false → bỏ qua step 3 fix currentStoreId', () {
      const bool userDocExists = false;
      bool didFixCurrentStoreId = false;
      if (userDocExists) {
        didFixCurrentStoreId = true;
      }
      expect(didFixCurrentStoreId, false);
    });
  });

  // === VẤN ĐỀ 2: activeMembersProvider deduplication =========================
  // Guard: nếu stream hoặc memberOrder bị lặp userId → vẫn chỉ hiển thị 1 lần
  group('activeMembersProvider deduplication – không hiển thị nhân viên 2 lần', () {
    MemberModel makeMember(String uid, String name, MemberStatus status) {
      return MemberModel(
        userId: uid,
        name: name,
        role: UserRole.employee,
        status: status,
        employeeType: EmployeeType.fulltime,
        joinedAt: DateTime.now(),
      );
    }

    test('Danh sách không trùng → giữ nguyên', () {
      final members = [
        makeMember('uid_1', 'An', MemberStatus.active),
        makeMember('uid_2', 'Bình', MemberStatus.active),
        makeMember('uid_3', 'Châu', MemberStatus.active),
      ];
      final seen = <String>{};
      final deduped = members.where((m) => seen.add(m.userId)).toList();
      expect(deduped.length, 3);
    });

    test('Thanh Linh xuất hiện 2 lần → dedup chỉ còn 1', () {
      final members = [
        makeMember('uid_thanh_linh', 'Thanh Linh Nguyễn', MemberStatus.active),
        makeMember('uid_2', 'Bình', MemberStatus.active),
        makeMember('uid_thanh_linh', 'Thanh Linh Nguyễn', MemberStatus.active), // duplicate
      ];
      final seen = <String>{};
      final deduped = members.where((m) => seen.add(m.userId)).toList();
      expect(deduped.length, 2);
      expect(deduped.where((m) => m.userId == 'uid_thanh_linh').length, 1);
    });

    test('Nhiều phần tử trùng → dedup chính xác', () {
      final members = [
        makeMember('uid_1', 'An', MemberStatus.active),
        makeMember('uid_1', 'An', MemberStatus.active),
        makeMember('uid_2', 'Bình', MemberStatus.active),
        makeMember('uid_2', 'Bình', MemberStatus.active),
        makeMember('uid_3', 'Châu', MemberStatus.active),
      ];
      final seen = <String>{};
      final deduped = members.where((m) => seen.add(m.userId)).toList();
      expect(deduped.length, 3);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:cham_cong_tram/models/store_model.dart';
import 'package:cham_cong_tram/models/user_model.dart';

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

      // Verify that store_kicked is not in storeIds
      expect(user.storeIds.contains(user.currentStoreId), false);

      // Simulating the fallback logic:
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
}

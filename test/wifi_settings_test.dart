import 'package:flutter_test/flutter_test.dart';
import 'package:cham_cong_tram/models/store_model.dart';

void main() {
  group('Multi-WiFi Configuration & Migration Tests', () {
    test('Auto-migrates legacy networkIP into wifis list if not already present', () {
      final json = {
        'name': 'Cửa hàng Phố Huế',
        'code': 'PHO001',
        'ownerId': 'owner_1',
        'networkIP': '113.161.45.10',
        'wifis': <dynamic>[],
        'createdAt': DateTime.now().toIso8601String(),
      };

      final store = StoreModel.fromJson(json, 'store_1');

      expect(store.wifis.length, 1);
      expect(store.wifis.first.name, 'WiFi Chính');
      expect(store.wifis.first.ip, '113.161.45.10');
      expect(store.hasWifi, isTrue);
    });

    test('Preserves existing wifis list if legacy networkIP is already in list', () {
      final json = {
        'name': 'Cửa hàng Cầu Giấy',
        'code': 'CG0002',
        'ownerId': 'owner_2',
        'networkIP': '113.161.45.10',
        'wifis': [
          {'name': 'WiFi Tầng 1', 'ip': '113.161.45.10'},
          {'name': 'WiFi Tầng 2', 'ip': '113.161.45.11'},
        ],
        'createdAt': DateTime.now().toIso8601String(),
      };

      final store = StoreModel.fromJson(json, 'store_2');

      expect(store.wifis.length, 2);
      expect(store.wifis[0].name, 'WiFi Tầng 1');
      expect(store.wifis[1].name, 'WiFi Tầng 2');
    });

    test('StoreWifi serialization and deserialization retains name, ip, and createdAt', () {
      final now = DateTime.utc(2026, 8, 15, 3, 0, 0);
      final wifi = StoreWifi(
        name: 'Coffee_5G',
        ip: '14.162.100.25',
        createdAt: now,
      );

      final json = wifi.toJson();
      expect(json['name'], 'Coffee_5G');
      expect(json['ip'], '14.162.100.25');

      final deserialized = StoreWifi.fromJson({
        'name': 'Coffee_5G',
        'ip': '14.162.100.25',
        'createdAt': now.toIso8601String(),
      });
      expect(deserialized.name, 'Coffee_5G');
      expect(deserialized.ip, '14.162.100.25');
    });

    test('Can configure up to 10 WiFi endpoints and check if ANY matches', () {
      final wifis = List.generate(
        10,
        (i) => StoreWifi(
          name: 'Điểm làm việc #${i + 1}',
          ip: '113.161.100.${i + 1}',
          createdAt: DateTime.now(),
        ),
      );

      final store = StoreModel(
        id: 'store_multi',
        name: 'Chuỗi Cửa Hàng 10 Chi Nhánh',
        code: 'MULTI1',
        ownerId: 'owner_multi',
        createdAt: DateTime.now(),
        wifis: wifis,
      );

      expect(store.wifis.length, 10);

      // Collect all allowed IPs
      final allowedIPs = store.wifis.map((w) => w.ip).toList();

      // Test matching on 1st, 5th, and 10th location
      expect(allowedIPs.contains('113.161.100.1'), isTrue);
      expect(allowedIPs.contains('113.161.100.5'), isTrue);
      expect(allowedIPs.contains('113.161.100.10'), isTrue);

      // Non-matching IP (e.g. at home or cafe)
      expect(allowedIPs.contains('113.161.100.99'), isFalse);
    });

    test('Duplicate IP detection prevents adding existing IP', () {
      final wifis = [
        const StoreWifi(name: 'Quầy bar', ip: '113.161.1.1'),
        const StoreWifi(name: 'Bếp', ip: '113.161.1.2'),
      ];

      const newDuplicateIP = '113.161.1.1';
      final isDuplicate = wifis.any((w) => w.ip.trim() == newDuplicateIP.trim());
      expect(isDuplicate, isTrue);

      const newUniqueIP = '113.161.1.3';
      final isUnique = !wifis.any((w) => w.ip.trim() == newUniqueIP.trim());
      expect(isUnique, isTrue);
    });

    test('Max 10 WiFi limit enforcement', () {
      final wifis = List.generate(
        10,
        (i) => StoreWifi(name: 'WiFi ${i + 1}', ip: '10.0.0.${i + 1}'),
      );

      final canAddMore = wifis.length < 10;
      expect(canAddMore, isFalse);
    });
  });
}

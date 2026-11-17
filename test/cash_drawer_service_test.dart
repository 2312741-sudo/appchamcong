import 'package:flutter_test/flutter_test.dart';
import 'package:cham_cong_tram/core/services/cash_drawer_service.dart';
import 'package:cham_cong_tram/core/auth/app_permissions.dart';
import 'package:cham_cong_tram/models/member_model.dart';

void main() {
  group('Mở két tiền', () {
    test('băm PIN khớp web (sha256 "tram-mo-ket|store|uid|pin")', () {
      expect(CashDrawerService.pinHash('S1', 'U1', '1234'),
          'e8db9b8fd89f06fd5c5661ea3ae2b2a96c402e347107bd20b3bc60b4dd1f0939');
    });

    test('kiểm tra PIN: đúng / sai / chưa đặt / sai định dạng', () {
      final cfg = CashDrawerConfig.fromMap({
        'token': 't',
        'pins': {'U1': CashDrawerService.pinHash('S1', 'U1', '1234')},
      });
      expect(CashDrawerService.checkPin(cfg, 'S1', 'U1', '1234'), isTrue);
      expect(CashDrawerService.checkPin(cfg, 'S1', 'U1', '4321'), isFalse);
      expect(CashDrawerService.checkPin(cfg, 'S2', 'U1', '1234'), isFalse); // PIN gắn với cửa hàng
      expect(CashDrawerService.checkPin(cfg, 'S1', 'U2', '1234'), isFalse); // chưa đặt PIN
      expect(CashDrawerService.isValidPin('12a4'), isFalse);
      expect(CashDrawerService.isValidPin('123'), isFalse);
      expect(CashDrawerService.isValidPin('123456'), isTrue);
    });

    test('đọc cấu hình: IP dạng chuỗi hoặc mảng, cổng mặc định 8787', () {
      final a = CashDrawerConfig.fromMap({'token': 'x', 'lanIps': '192.168.1.5'});
      expect(CashDrawerService.agentUrls(a), ['http://192.168.1.5:8787']);
      final b = CashDrawerConfig.fromMap({'token': 'x', 'port': 9000, 'lanIps': ['10.0.0.2', '10.0.0.2', '192.168.1.9']});
      expect(CashDrawerService.agentUrls(b), ['http://10.0.0.2:9000', 'http://192.168.1.9:9000']);
      expect(CashDrawerConfig.fromMap(null).isPaired, isFalse);
    });

    test('lý do mở két', () {
      expect(CashDrawerService.fullReason('Đổi tiền lẻ', ''), 'Đổi tiền lẻ');
      expect(CashDrawerService.fullReason('Đổi tiền lẻ', ' 500k '), 'Đổi tiền lẻ — 500k');
      expect(CashDrawerService.fullReason('Khác', ''), 'Khác');
      expect(CashDrawerService.fullReason('Khác', 'Rút về ngân hàng'), 'Rút về ngân hàng');
    });

    test('chỉ Chủ / Quản lý 1 mở két', () {
      expect(AppPermissions.canOpenCashDrawer(UserRole.owner), isTrue);
      expect(AppPermissions.canOpenCashDrawer(UserRole.manager1), isTrue);
      expect(AppPermissions.canOpenCashDrawer(UserRole.legacyManager), isTrue);
      expect(AppPermissions.canOpenCashDrawer(UserRole.manager2), isFalse);
      expect(AppPermissions.canOpenCashDrawer(UserRole.employee), isFalse);
      expect(AppPermissions.canOpenCashDrawer(null), isFalse);
    });
  });
}

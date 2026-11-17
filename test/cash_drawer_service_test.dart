import 'package:flutter_test/flutter_test.dart';
import 'package:cham_cong_tram/core/services/cash_drawer_service.dart';
import 'package:cham_cong_tram/core/auth/app_permissions.dart';
import 'package:cham_cong_tram/models/member_model.dart';

void main() {
  group('Mở két tiền — mã dùng 1 lần', () {
    test('mã 6 số khớp phần mềm laptop và web (HMAC-SHA256)', () {
      // Cùng mẫu đã đối chiếu với web (lib/cashDrawer.ts otpFor) và thuật toán Get-Otp của laptop
      expect(CashDrawerService.otpFor('secret-abc', 'REQ123abc.1793606400000'), '910788');
    });

    test('mã khác nhau theo yêu cầu và theo khóa; luôn đủ 6 số', () {
      final a = CashDrawerService.otpFor('k1', 'A1b2.1793606400000');
      final b = CashDrawerService.otpFor('k1', 'A1b2.1793606400001');
      final c = CashDrawerService.otpFor('k2', 'A1b2.1793606400000');
      expect(a == b && a == c, isFalse);
      for (var i = 0; i < 200; i++) {
        expect(CashDrawerService.isValidOtp(CashDrawerService.otpFor('k$i', 'R$i.1793606400000')), isTrue);
      }
      expect(CashDrawerService.isValidOtp('12345'), isFalse);
      expect(CashDrawerService.isValidOtp('12a456'), isFalse);
    });

    test('yêu cầu còn hạn 15 phút, chỉ khi đang chờ', () {
      const t0 = 1793606400000;
      const r = CashDrawerRequest(id: 'x', uid: 'u', name: 'A', reason: 'r', nonce: 'x.$t0', createdAtMs: t0, status: 'pending');
      expect(r.isAlive(t0 + 14 * 60000), isTrue);
      expect(r.minutesLeft(t0 + 14 * 60000), 1);
      expect(r.isAlive(t0 + 15 * 60000), isFalse);
      const done = CashDrawerRequest(id: 'x', uid: 'u', name: 'A', reason: 'r', nonce: 'x.$t0', createdAtMs: t0, status: 'opened');
      expect(done.isAlive(t0), isFalse);
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

    test('chỉ Chủ / Quản lý (QL1, QL2, Quản lý cũ) dùng được két', () {
      expect(AppPermissions.canOpenCashDrawer(UserRole.owner), isTrue);
      expect(AppPermissions.canOpenCashDrawer(UserRole.manager1), isTrue);
      expect(AppPermissions.canOpenCashDrawer(UserRole.manager2), isTrue);
      expect(AppPermissions.canOpenCashDrawer(UserRole.legacyManager), isTrue);
      expect(AppPermissions.canOpenCashDrawer(UserRole.employee), isFalse);
      expect(AppPermissions.canOpenCashDrawer(null), isFalse);
    });
  });
}

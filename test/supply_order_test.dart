import 'package:flutter_test/flutter_test.dart';
import 'package:cham_cong_tram/core/utils/supply_date_utils.dart';
import 'package:cham_cong_tram/models/supply_order_model.dart';
import 'package:cham_cong_tram/features/supply_order/supply_export.dart';
import 'package:cham_cong_tram/features/supply_order/supply_reminder_service.dart';

void main() {
  group('SupplyDateUtils (giờ Việt Nam)', () {
    test('23:30 giờ VN vẫn là hôm nay; ngày mai là ngày kế tiếp', () {
      final t = DateTime.utc(2026, 10, 29, 16, 30); // 23:30 ngày 29/10 VN
      expect(SupplyDateUtils.today(t), '2026-10-29');
      expect(SupplyDateUtils.tomorrow(t), '2026-10-30');
    });
    test('00:30 giờ VN đã sang ngày mới', () {
      final t = DateTime.utc(2026, 10, 29, 17, 30); // 00:30 ngày 30/10 VN
      expect(SupplyDateUtils.today(t), '2026-10-30');
    });
    test('cuối tháng / cuối năm', () {
      expect(SupplyDateUtils.addDays('2026-12-31', 1), '2027-01-01');
      expect(SupplyDateUtils.addDays('2026-03-01', -1), '2026-02-28');
    });
    test('số lượng chấp nhận dấu phẩy, từ chối <= 0', () {
      expect(SupplyDateUtils.parseQty('2,5'), 2.5);
      expect(SupplyDateUtils.parseQty('10'), 10);
      expect(SupplyDateUtils.parseQty('0'), isNull);
      expect(SupplyDateUtils.parseQty('abc'), isNull);
      expect(SupplyDateUtils.formatQty(3), '3');
      expect(SupplyDateUtils.formatQty(2.5), '2.5');
    });
  });

  group('SupplyOrder.fromJson', () {
    test('gộp nhiều người đặt, đếm đã soạn', () {
      final o = SupplyOrder.fromJson('2026-10-30', {
        'date': '2026-10-30',
        'lines': {
          'ly500': {
            'name': 'Ly 500ml',
            'unit': 'cây',
            'group': 'Bao bì',
            'qty': 7,
            'contributors': [
              {'uid': 'a', 'name': 'An', 'qty': 5, 'at': 1},
              {'uid': 'b', 'name': 'Bình', 'qty': 2, 'at': 2},
              {'uid': 'a', 'name': 'An', 'qty': 0, 'at': 3},
            ],
            'prepared': true,
            'preparedByName': 'Chi',
          },
          'ongHut': {'name': 'Ống hút', 'unit': 'bịch', 'group': 'Bao bì', 'qty': 2},
        },
      });
      expect(o.lines.length, 2);
      final ly = o.lines.firstWhere((l) => l.itemId == 'ly500');
      expect(ly.qty, 7);
      expect(ly.contributorNames, ['An', 'Bình']);
      expect(o.preparedCount, 1);
      expect(o.isAllPrepared, isFalse);
    });
    test('phiếu trống / chưa tồn tại', () {
      final o = SupplyOrder.fromJson('2026-10-30', null);
      expect(o.isEmpty, isTrue);
      expect(o.isAllPrepared, isFalse);
    });
  });

  group('Giờ chốt đặt hàng', () {
    test('phiếu ngày 30 chốt lúc 21:00 ngày 29 (giờ VN)', () {
      final d = SupplyDateUtils.cutoffDeadline('2026-10-30', '21:00')!;
      expect(d, DateTime.utc(2026, 10, 29, 14, 0)); // 21:00 VN = 14:00 UTC
      expect(SupplyDateUtils.isOrderLocked('2026-10-30', '21:00', DateTime.utc(2026, 10, 29, 13, 59)), isFalse);
      expect(SupplyDateUtils.isOrderLocked('2026-10-30', '21:00', DateTime.utc(2026, 10, 29, 14, 0)), isTrue);
      expect(SupplyDateUtils.cutoffLabel('2026-10-30', '21:00'), '21:00 ngày 29/10/2026');
    });
    test('không có giờ chốt / sai định dạng → không khóa', () {
      expect(SupplyDateUtils.isOrderLocked('2026-10-30', null), isFalse);
      expect(SupplyDateUtils.isOrderLocked('2026-10-30', '25:00'), isFalse);
      expect(SupplyDateUtils.cutoffLabel('2026-10-30', ''), isNull);
    });
    test('đầu tháng: chốt rơi vào ngày cuối tháng trước', () {
      expect(SupplyDateUtils.cutoffDeadline('2026-11-01', '22:30'), DateTime.utc(2026, 10, 31, 15, 30));
    });
  });

  group('SupplySettings.fromJson', () {
    test('đọc giờ chốt và bộ phận soạn hàng', () {
      final s = SupplySettings.fromJson({'cutoffTime': '21:00', 'preparerDepartmentIds': ['lobby', '']});
      expect(s.cutoffTime, '21:00');
      expect(s.preparerDepartmentIds, ['lobby']);
      expect(SupplySettings.fromJson(null).cutoffTime, isNull);
      expect(SupplySettings.fromJson({'cutoffTime': 'abc'}).cutoffTime, isNull);
    });
  });

  group('Nhắc đặt hàng trước giờ chốt', () {
    test('chốt 21:00 → nhắc 20:30 giờ VN hôm nay', () {
      final now = DateTime.utc(2026, 10, 29, 5, 0); // 12:00 VN
      expect(SupplyReminderService.reminderTime('21:00', now), DateTime.utc(2026, 10, 29, 13, 30));
    });
    test('đã qua giờ nhắc / không có giờ chốt → null', () {
      expect(SupplyReminderService.reminderTime('21:00', DateTime.utc(2026, 10, 29, 13, 31)), isNull);
      expect(SupplyReminderService.reminderTime(null, DateTime.utc(2026, 10, 29, 5)), isNull);
    });
  });

  group('Xuất Excel', () {
    test('mỗi món của mỗi phiếu một dòng, có người đặt và trạng thái soạn', () {
      final o = SupplyOrder.fromJson('2026-10-30', {
        'lines': {
          'ly': {
            'name': 'Ly 500ml', 'unit': 'cây', 'group': 'Bao bì', 'qty': 3,
            'contributors': [{'uid': 'a', 'name': 'An', 'qty': 3, 'at': 1}],
            'prepared': true, 'preparedByName': 'Chi', 'preparedAt': DateTime.utc(2026, 10, 30, 1, 5).millisecondsSinceEpoch,
          },
        },
      });
      final rows = SupplyExport.rows([o]);
      expect(rows.length, 1);
      expect(rows.first, ['30/10/2026', 'Bao bì', 'Ly 500ml', 'cây', 3.0, 'An', '', 'Đã soạn', 'Chi', '08:05 30/10']);
      expect(SupplyExport.headers.length, rows.first.length);
    });
  });
}

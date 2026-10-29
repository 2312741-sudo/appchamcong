import 'package:flutter_test/flutter_test.dart';
import 'package:cham_cong_tram/core/utils/supply_date_utils.dart';
import 'package:cham_cong_tram/models/supply_order_model.dart';

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
}

// Ngày của phiếu đặt hàng / soạn hàng tính theo giờ Việt Nam (UTC+7), dạng yyyy-MM-dd.
class SupplyDateUtils {
  SupplyDateUtils._();

  static DateTime vnNow([DateTime? now]) => (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Hôm nay theo giờ Việt Nam
  static String today([DateTime? now]) => ymd(vnNow(now));

  /// Ngày mai theo giờ Việt Nam (ngày nhận hàng mặc định khi đặt)
  static String tomorrow([DateTime? now]) {
    final d = vnNow(now);
    return ymd(DateTime.utc(d.year, d.month, d.day + 1));
  }

  static String addDays(String ymdStr, int days) {
    final p = ymdStr.split('-').map(int.parse).toList();
    return ymd(DateTime.utc(p[0], p[1], p[2] + days));
  }

  /// "dd/MM/yyyy" để hiển thị
  static String display(String ymdStr) {
    final p = ymdStr.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : ymdStr;
  }

  /// Nhãn thân thiện: Hôm nay / Ngày mai / Hôm qua / dd/MM/yyyy
  static String label(String ymdStr, [DateTime? now]) {
    final t = today(now);
    if (ymdStr == t) return 'Hôm nay (${display(ymdStr)})';
    if (ymdStr == tomorrow(now)) return 'Ngày mai (${display(ymdStr)})';
    if (ymdStr == addDays(t, -1)) return 'Hôm qua (${display(ymdStr)})';
    return display(ymdStr);
  }

  /// Chuẩn hóa số lượng người dùng nhập ("2,5" → 2.5); không hợp lệ hoặc <= 0 → null
  static double? parseQty(String text) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    if (v == null || v.isNaN || v <= 0) return null;
    return v;
  }

  /// Hạn chốt đặt hàng (mốc UTC) cho phiếu ngày [date]: [cutoff] "HH:mm" của NGÀY HÔM TRƯỚC, giờ Việt Nam.
  /// [cutoff] null / sai định dạng → null (không chốt).
  static DateTime? cutoffDeadline(String date, String? cutoff) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch((cutoff ?? '').trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final mi = int.parse(m.group(2)!);
    if (h > 23 || mi > 59) return null;
    final p = date.split('-').map(int.parse).toList();
    // Ngày hôm trước lúc h:mi giờ VN = (… − 7 giờ) theo UTC
    return DateTime.utc(p[0], p[1], p[2] - 1, h, mi).subtract(const Duration(hours: 7));
  }

  /// Phiếu ngày [date] đã khóa đặt hàng chưa (qua giờ chốt). Không có giờ chốt → không khóa.
  static bool isOrderLocked(String date, String? cutoff, [DateTime? now]) {
    final d = cutoffDeadline(date, cutoff);
    if (d == null) return false;
    return !(now ?? DateTime.now()).toUtc().isBefore(d);
  }

  /// Mô tả giờ chốt để hiển thị: "21:00 ngày 29/10/2026"
  static String? cutoffLabel(String date, String? cutoff) {
    if (cutoffDeadline(date, cutoff) == null) return null;
    return '${cutoff!.trim()} ngày ${display(addDays(date, -1))}';
  }

  static String formatQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/excel_export_service.dart';
import '../../core/utils/share_utils.dart';
import '../../core/utils/supply_date_utils.dart';
import '../../models/supply_order_model.dart';

/// Xuất lịch sử đặt & soạn hàng ra Excel
class SupplyExport {
  SupplyExport._();

  static const headers = [
    'Ngày nhận', 'Nhóm', 'Mã hàng', 'Mặt hàng', 'Đơn vị', 'Số lượng', 'Người đặt', 'Ghi chú', 'Đã soạn', 'Người soạn', 'Giờ soạn',
  ];

  /// Dòng dữ liệu (thuần, để test): mỗi món của mỗi phiếu một dòng
  static List<List<Object>> rows(List<SupplyOrder> orders) {
    String time(int? ms) {
      if (ms == null) return '';
      final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).add(const Duration(hours: 7));
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    }

    return [
      for (final o in orders)
        for (final l in o.lines)
          [
            SupplyDateUtils.display(o.date),
            l.group,
            l.code,
            l.name,
            l.unit,
            l.qty,
            l.contributorNames.join(', '),
            l.note,
            l.prepared ? 'Đã soạn' : 'Chưa soạn',
            l.prepared ? (l.preparedByName.isEmpty ? l.preparedBy : l.preparedByName) : '',
            l.prepared ? time(l.preparedAt) : '',
          ],
    ];
  }

  static Future<void> exportToExcel(
    List<SupplyOrder> orders, {
    required String fromDate,
    required String toDate,
    String storeName = '',
    BuildContext? context,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'DatSoanHang';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final r in rows(orders)) {
      sheet.appendRow(r.map<CellValue>((c) => c is double ? DoubleCellValue(c) : TextCellValue(c.toString())).toList());
    }
    final bytes = excel.save();
    if (bytes == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final storePart = ExcelExportService.sanitize(storeName);
    final fileName = 'DatSoanHang_${storePart.isNotEmpty ? '${storePart}_' : ''}${fromDate}_$toDate.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await ShareUtils.shareFiles(
      [file.path],
      context: context,
      text: 'Đặt & soạn hàng ${SupplyDateUtils.display(fromDate)} - ${SupplyDateUtils.display(toDate)}',
      subject: 'Đặt & soạn hàng $storeName',
    );
  }
}

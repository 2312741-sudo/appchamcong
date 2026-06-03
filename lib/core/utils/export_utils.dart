import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_model.dart';
import '../../models/member_model.dart';
import '../../features/salary/providers/salary_provider.dart';

class ExportUtils {
  static Future<void> exportMonthlyAttendanceToExcel(
    String storeId,
    DateTime dateInMonth,
    List<MemberModel> members,
    SalaryRepository repo,
  ) async {
    try {
      final monthStr = '${dateInMonth.year}-${dateInMonth.month.toString().padLeft(2, '0')}';
      final allAttendances = await repo.getAllMonthAttendances(storeId, monthStr);
      final daysInMonth = DateUtils.getDaysInMonth(dateInMonth.year, dateInMonth.month);

      final excel = Excel.createExcel();
      final sheetName = 'BangCong';
      excel.rename('Sheet1', sheetName);
      final sheet = excel[sheetName];

      // Build Headers: Tên nhân viên, Vai trò, Ngày 1..31, Tổng giờ
      final headers = [
        TextCellValue('Tên nhân viên'),
        TextCellValue('Vai trò'),
      ];
      for (int i = 1; i <= daysInMonth; i++) {
        headers.add(TextCellValue('Ngày $i'));
      }
      headers.add(TextCellValue('Tổng giờ'));
      sheet.appendRow(headers);

      // Add Data for each member
      for (final member in members) {
        final attendances = allAttendances[member.userId] ?? [];
        
        final row = <CellValue>[
          TextCellValue(member.name),
          TextCellValue(member.role.label),
        ];

        double totalMonthHours = 0.0;

        for (int day = 1; day <= daysInMonth; day++) {
          final dayStr = '$monthStr-${day.toString().padLeft(2, '0')}';
          // Calculate total hours for this day
          final dayAttendances = attendances.where((a) => a.date == dayStr);
          final dayHours = dayAttendances.fold(0.0, (sum, a) => sum + a.totalHours);
          
          totalMonthHours += dayHours;
          
          if (dayHours > 0) {
            row.add(TextCellValue('${dayHours.toStringAsFixed(1)}h'));
          } else {
            row.add(TextCellValue('0h'));
          }
        }

        row.add(TextCellValue('${totalMonthHours.toStringAsFixed(1)}h'));
        sheet.appendRow(row);
      }

      // Save file
      final fileBytes = excel.save();
      if (fileBytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/BangCong_Thang_$monthStr.xlsx');
        
        await file.writeAsBytes(fileBytes);
        
        // Share file
        await Share.shareXFiles([XFile(file.path)], text: 'Bảng công tháng $monthStr');
      }
    } catch (e) {
      throw Exception('Lỗi xuất file: $e');
    }
  }
}

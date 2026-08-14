import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../models/member_model.dart';
import '../../models/schedule_model.dart';
import '../../features/salary/providers/salary_provider.dart';
import 'excel_export_service.dart';

class ExportUtils {
  static Future<void> exportMonthlyAttendanceToExcel(
    String storeId,
    DateTime dateInMonth,
    List<MemberModel> members,
    SalaryRepository repo, {
    String storeName = '',
  }) async {
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
          final dayAttendances = attendances.where((a) => a.date == dayStr);
          final dayHours = dayAttendances.fold(0.0, (sum, a) => sum + a.totalHours);
          
          totalMonthHours += dayHours;
          
          if (dayHours > 0) {
            row.add(DoubleCellValue(dayHours));
          } else {
            row.add(IntCellValue(0));
          }
        }

        row.add(DoubleCellValue(totalMonthHours));
        sheet.appendRow(row);
      }

      // Save file
      final fileBytes = excel.save();
      if (fileBytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final storePart = ExcelExportService.sanitize(storeName);
        final timePart = 'T${dateInMonth.month.toString().padLeft(2, '0')}-${dateInMonth.year}';
        final storePrefix = storePart.isNotEmpty ? '${storePart}_' : '';
        final fileName = 'BangCong_$storePrefix$timePart.xlsx';
        final file = File('${dir.path}/$fileName');
        
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Bảng công tháng $monthStr');
      }
    } catch (e) {
      throw Exception('Lỗi xuất file: $e');
    }
  }

  static Future<void> exportWeeklyScheduleToExcel({
    required String weekStart,
    required List<MemberModel> members,
    required ScheduleModel? schedule,
    String storeName = '',
  }) async {
    try {
      final monday = DateTime.parse(weekStart);
      final days = List.generate(7, (i) => monday.add(Duration(days: i)));
      final dayLabels = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];

      final excel = Excel.createExcel();
      final sheetName = 'LichLam';
      excel.rename('Sheet1', sheetName);
      final sheet = excel[sheetName];

      // Header row: week label
      final sundayDate = days.last;
      final weekLabel =
          'Tuần: ${DateFormat('dd/MM').format(monday)} - ${DateFormat('dd/MM/yyyy').format(sundayDate)}';
      sheet.appendRow([TextCellValue(weekLabel)]);

      // Column headers: Nhân viên + 7 days
      final headers = <CellValue>[TextCellValue('Nhân viên')];
      for (int i = 0; i < 7; i++) {
        headers.add(TextCellValue('${dayLabels[i]}\n${DateFormat('dd/MM').format(days[i])}'));
      }
      sheet.appendRow(headers);

      // Data rows
      for (final member in members) {
        final daySchedule = schedule?.getScheduleForUser(member.userId);
        final row = <CellValue>[TextCellValue(member.name)];
        for (int i = 0; i < 7; i++) {
          final shifts = daySchedule?.shiftForDay(i + 1) ?? [];
          final cellText = shifts.isEmpty ? 'Nghỉ' : '${shifts.length} ca';
          row.add(TextCellValue(cellText));
        }
        sheet.appendRow(row);
      }

      // Save and share
      final fileBytes = excel.save();
      if (fileBytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final storePart = ExcelExportService.sanitize(storeName);
        final sundayStr = '${days.last.day.toString().padLeft(2, '0')}.${days.last.month.toString().padLeft(2, '0')}.${days.last.year}';
        final mondayStr = '${monday.day.toString().padLeft(2, '0')}.${monday.month.toString().padLeft(2, '0')}';
        final storePrefix = storePart.isNotEmpty ? '${storePart}_' : '';
        final fileName = 'LichLam_${storePrefix}Tuan_$mondayStr-$sundayStr.xlsx';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Lịch làm tuần $weekLabel',
        );
      }
    } catch (e) {
      throw Exception('Lỗi xuất lịch: $e');
    }
  }
}

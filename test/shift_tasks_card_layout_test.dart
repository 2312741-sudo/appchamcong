import 'package:cham_cong_tram/features/attendance/providers/attendance_provider.dart';
import 'package:cham_cong_tram/features/auth/providers/auth_provider.dart';
import 'package:cham_cong_tram/features/store/providers/store_provider.dart';
import 'package:cham_cong_tram/features/task_assignment/providers/task_provider.dart';
import 'package:cham_cong_tram/features/task_assignment/widgets/shift_tasks_card.dart';
import 'package:cham_cong_tram/models/attendance_model.dart';
import 'package:cham_cong_tram/models/task_assignment_model.dart';
import 'package:cham_cong_tram/models/member_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Thẻ "Công việc được giao" không được tràn chữ trên màn hẹp (ca qua đêm, tên việc dài)
void main() {
  String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
  final yesterday = ymd(DateTime(vn.year, vn.month, vn.day - 1));

  AssignedTask task(String id, String title) => AssignedTask(
        id: id,
        storeId: 's1',
        title: title,
        description: '',
        createdBy: 'm1',
        createdByName: 'Nguyễn Văn Quản Lý Ca Đêm Rất Dài Tên',
        createdByRole: UserRole.manager1,
        targetType: TaskTargetType.individual,
        assignedUserIds: const ['u1'],
        repeatDaily: true,
        requirePhoto: true,
        createdAt: DateTime(2026, 1, 1),
      );

  Future<void> pump(WidgetTester t, double width, {required List<AssignedTask> tasks}) async {
    t.view.physicalSize = Size(width * 3, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    // Ca vào hôm qua, chưa ra ca → ca qua đêm
    final att = AttendanceModel(id: 'a1', userId: 'u1', storeId: 's1', date: yesterday, checkIn: DateTime.now().toUtc().subtract(const Duration(hours: 10)));
    await t.pumpWidget(ProviderScope(
      overrides: [
        currentStoreIdProvider.overrideWithValue('s1'),
        currentUserIdProvider.overrideWithValue('u1'),
        activeAttendancesProvider.overrideWith((ref) => Stream.value([att])),
        todayAttendanceProvider.overrideWith((ref) => Stream.value(att)),
        todayUserTasksProvider.overrideWith((ref, args) => Stream.value(tasks)),
        unfinishedUserTasksProvider.overrideWith((ref, args) async => tasks),
      ],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(padding: EdgeInsets.all(16), child: ShiftTasksCard()))),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  for (final w in [320.0, 360.0, 390.0]) {
    testWidgets('không tràn ở bề ngang $w (có việc)', (t) async {
      await pump(t, w, tasks: [task('t1', 'Kiểm kê kho đá, syrup, ly nhựa và bao bì cuối ca đêm trước khi bàn giao')]);
      expect(find.textContaining('Ca làm việc qua đêm'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
    testWidgets('không tràn ở bề ngang $w (chưa có việc)', (t) async {
      await pump(t, w, tasks: const []);
      expect(t.takeException(), isNull);
    });
  }
}

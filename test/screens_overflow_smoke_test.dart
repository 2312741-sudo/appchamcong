import 'package:cham_cong_tram/features/attendance/providers/attendance_provider.dart';
import 'package:cham_cong_tram/features/auth/providers/auth_provider.dart';
import 'package:cham_cong_tram/features/members/screens/members_list_screen.dart';
import 'package:cham_cong_tram/features/supply_order/providers/supply_order_provider.dart';
import 'package:cham_cong_tram/features/supply_order/screens/supply_order_screen.dart';
import 'package:cham_cong_tram/models/supply_order_model.dart';
import 'package:cham_cong_tram/features/store/providers/store_provider.dart';
import 'package:cham_cong_tram/features/task_assignment/providers/task_provider.dart';
import 'package:cham_cong_tram/features/task_assignment/screens/task_detail_screen.dart';
import 'package:cham_cong_tram/features/task_assignment/screens/task_management_screen.dart';
import 'package:cham_cong_tram/features/schedule/providers/schedule_provider.dart';
import 'package:cham_cong_tram/core/theme/app_theme.dart';
import 'package:cham_cong_tram/models/member_model.dart';
import 'package:cham_cong_tram/models/store_model.dart';
import 'package:cham_cong_tram/models/task_assignment_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/real_fonts.dart';

/// Dựng các màn có nhãn/tên dài ở màn hẹp: không được tràn chữ, không lỗi layout.
void main() {
  setUpAll(loadRealFonts);
  const longDept = 'Phục vụ lobby và quầy bar tầng hai khu sân vườn';
  final store = StoreModel(
    id: 's1', name: 'Trạm Cà Phê Chi Nhánh Nguyễn Văn Linh Quận 7', code: 'TRAM01', ownerId: 'o1',
    createdAt: DateTime(2026, 1, 1),
    departments: const [DepartmentDefinition(id: 'd1', name: longDept, shortName: 'PV')],
  );
  final members = [
    for (final r in [UserRole.owner, UserRole.manager1, UserRole.employee])
      MemberModel(
        userId: 'u_${r.name}', name: 'Nguyễn Thị Thanh Hương Ngọc Bích ${r.name}', role: r,
        status: MemberStatus.active, employeeType: EmployeeType.parttime, joinedAt: DateTime(2026, 1, 1), department: 'd1',
      ),
  ];
  final task = AssignedTask(
    id: 't1', storeId: 's1',
    title: 'Kiểm kê toàn bộ kho đá, syrup, ly nhựa, ống hút và bao bì trước khi bàn giao ca đêm',
    description: 'Đếm và ghi lại số lượng còn tồn, chụp ảnh khu vực kho sau khi sắp xếp gọn gàng.',
    createdBy: 'u_manager1', createdByName: 'Nguyễn Văn Quản Lý Ca Đêm Rất Dài Tên Người Giao',
    createdByRole: UserRole.manager1, targetType: TaskTargetType.department,
    targetDepartmentIds: const ['d1'], targetDepartmentNames: const [longDept],
    repeatDaysOfWeek: const [1, 2, 3, 4, 5, 6, 7], requirePhoto: true, createdAt: DateTime(2026, 1, 1),
  );

  final employee = members.last;
  const items = [
    SupplyItem(id: 'i1', name: 'Ly nhựa 500ml có nắp cầu in logo Trạm', unit: 'thùng', group: 'Bao bì & dụng cụ dùng một lần'),
    SupplyItem(id: 'i2', name: 'Sữa tươi thanh trùng không đường', unit: 'hộp 1 lít', group: 'Nguyên liệu pha chế'),
  ];

  final overrides = [
    currentUserIdProvider.overrideWithValue('u_employee'),
    currentMemberProvider.overrideWithValue(employee),
    todayAttendanceProvider.overrideWith((ref) => Stream.value(null)),
    activeAttendancesProvider.overrideWith((ref) => Stream.value(const [])),
    todayUserTasksProvider.overrideWith((ref, a) => Stream.value([task])),
    unfinishedUserTasksProvider.overrideWith((ref, a) async => [task]),
    supplyItemsProvider.overrideWith((ref) => Stream.value(items)),
    allSupplyItemsProvider.overrideWith((ref) => Stream.value(items)),
    supplyOrderProvider.overrideWith((ref, d) => Stream.value(SupplyOrder(date: d, lines: const []))),
    recentSupplyOrdersProvider.overrideWith((ref) => Stream.value(const [])),
    supplySettingsProvider.overrideWith((ref) => Stream.value(const SupplySettings(cutoffTime: '21:00', preparerDepartmentIds: ['d1']))),
    currentStoreIdProvider.overrideWithValue('s1'),
    currentStoreProvider.overrideWith((ref) => Stream.value(store)),
    activeMembersProvider.overrideWithValue(members),
    currentMemberStreamProvider.overrideWith((ref) => Stream.value(members.first)),
    ghostMemberCleanupProvider.overrideWith((ref) async => 0),
    storeTasksProvider.overrideWith((ref, id) => Stream.value([task])),
    singleTaskProvider.overrideWith((ref, a) => Stream.value(task)),
    allTaskSubmissionsProvider.overrideWith((ref, a) => Stream.value(const [])),
    weekScheduleProvider.overrideWith((ref, w) => Stream.value(null)),
  ];

  Future<void> pump(WidgetTester t, Widget screen, double width) async {
    t.view.physicalSize = Size(width * 3, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: screen)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Nút bị ép cao 46–50 không cắt chữ (theme chung)', (t) async {
    for (final h in [46.0, 48.0, 50.0]) {
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.tramTheme,
        home: Scaffold(body: Center(child: SizedBox(width: 340, height: h, child: ElevatedButton(onPressed: () {}, child: const Text('Đặt 2 món cho Ngày mai (31/10/2026)'))))),
      ));
      final button = t.getSize(find.byType(ElevatedButton));
      final style = AppTheme.tramTheme.elevatedButtonTheme.style!;
      final pad = style.padding!.resolve({})!.vertical;
      // Chiều cao thật của một dòng chữ (đo bằng TextPainter, không bị co theo chỗ trống)
      final ts = DefaultTextStyle.of(t.element(find.text('Đặt 2 món cho Ngày mai (31/10/2026)'))).style;
      final tp = TextPainter(text: TextSpan(text: 'Đặt 2 món cho Ngày mai (31/10/2026)', style: ts), textDirection: TextDirection.ltr)..layout();
      expect(button.height - pad, greaterThanOrEqualTo(tp.height), reason: 'nút cao $h: còn ${button.height - pad}px, chữ cần ${tp.height}px');
    }
  });

  for (final w in [320.0, 390.0]) {
    testWidgets('Danh sách nhân viên ($w)', (t) async {
      await pump(t, const MembersListScreen(), w);
      expect(t.takeException(), isNull);
    });
    testWidgets('Danh sách giao việc ($w)', (t) async {
      await pump(t, const TaskManagementScreen(), w);
      expect(t.takeException(), isNull);
    });
    testWidgets('Đặt & soạn hàng ($w)', (t) async {
      await pump(t, const SupplyOrderScreen(), w);
      expect(t.takeException(), isNull);
    });
    testWidgets('Chi tiết việc ($w)', (t) async {
      await pump(t, TaskDetailScreen(task: task), w);
      expect(t.takeException(), isNull);
    });
  }
}

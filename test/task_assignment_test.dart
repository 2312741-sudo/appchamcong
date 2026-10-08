import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cham_cong_tram/models/member_model.dart';
import 'package:cham_cong_tram/models/task_assignment_model.dart';
import 'package:cham_cong_tram/features/task_assignment/repositories/task_repository.dart';

/// Test double cho TaskRepository để kiểm thử logic nghiệp vụ
class TestTaskRepository extends TaskRepository {
  final List<AssignedTask> mockTasks;
  final Map<String, TaskSubmission?> mockSubmissions; // key: taskId

  TestTaskRepository({
    required this.mockTasks,
    required this.mockSubmissions,
  });

  @override
  Future<List<AssignedTask>> getTasksForUserOnDate(
    String storeId,
    String userId,
    String dateStr,
  ) async {
    return mockTasks
        .where((task) =>
            task.storeId == storeId &&
            task.isApplicableForUserOnDate(userId: userId, dateStr: dateStr))
        .toList();
  }

  @override
  Future<TaskSubmission?> getUserSubmission(
    String storeId,
    String taskId,
    String userId,
    String workDate,
  ) async {
    return mockSubmissions[taskId];
  }
}

void main() {
  group('1. TaskTargetType & TaskStatus Enum Tests', () {
    test('TaskTargetType parse from string & value conversion', () {
      expect(TaskTargetTypeExtension.fromString('individual'),
          equals(TaskTargetType.individual));
      expect(TaskTargetTypeExtension.fromString('allStore'),
          equals(TaskTargetType.allStore));
      expect(TaskTargetTypeExtension.fromString('all_store'),
          equals(TaskTargetType.allStore));
      expect(TaskTargetTypeExtension.fromString('all'),
          equals(TaskTargetType.allStore));
      expect(TaskTargetTypeExtension.fromString(null),
          equals(TaskTargetType.individual));

      expect(TaskTargetType.individual.value, equals('individual'));
      expect(TaskTargetType.allStore.value, equals('allStore'));
      expect(TaskTargetType.individual.label, equals('Cá nhân'));
      expect(TaskTargetType.allStore.label, equals('Toàn cửa hàng'));
    });

    test('TaskStatus parse from string & value conversion', () {
      expect(TaskStatusExtension.fromString('active'), equals(TaskStatus.active));
      expect(TaskStatusExtension.fromString('completed'),
          equals(TaskStatus.completed));
      expect(TaskStatusExtension.fromString('done'),
          equals(TaskStatus.completed));
      expect(TaskStatusExtension.fromString('cancelled'),
          equals(TaskStatus.cancelled));
      expect(TaskStatusExtension.fromString('canceled'),
          equals(TaskStatus.cancelled));
      expect(TaskStatusExtension.fromString('archived'),
          equals(TaskStatus.archived));
      expect(TaskStatusExtension.fromString(null), equals(TaskStatus.active));

      expect(TaskStatus.active.value, equals('active'));
      expect(TaskStatus.completed.value, equals('completed'));
      expect(TaskStatus.cancelled.value, equals('cancelled'));
      expect(TaskStatus.archived.value, equals('archived'));
    });
  });

  group('2. AssignedTask Serialization & Deserialization Tests', () {
    final fixedCreatedAt = DateTime(2026, 10, 8, 8, 30);
    final fixedUpdatedAt = DateTime(2026, 10, 8, 12, 0);

    final sampleTask = AssignedTask(
      id: 'task_001',
      storeId: 'store_alpha',
      title: 'Kiểm kê kho đá và syrup',
      description: 'Đếm số bao đá và chai syrup còn tồn cuối ca',
      createdBy: 'uid_manager_1',
      createdByName: 'Nguyễn Văn Quản Lý',
      createdByRole: UserRole.manager1,
      targetType: TaskTargetType.individual,
      assignedUserIds: const ['uid_user_1', 'uid_user_2'],
      assignedNames: const ['Trần Nhân Viên', 'Lê Phục Vụ'],
      executionDates: const ['2026-10-08', '2026-10-09'],
      requirePhoto: true,
      status: TaskStatus.active,
      createdAt: fixedCreatedAt,
      updatedAt: fixedUpdatedAt,
    );

    test('toJson with Timestamp and fromJson roundtrip', () {
      final json = sampleTask.toJson(useTimestamp: true);

      expect(json['id'], equals('task_001'));
      expect(json['storeId'], equals('store_alpha'));
      expect(json['title'], equals('Kiểm kê kho đá và syrup'));
      expect(json['targetType'], equals('individual'));
      expect(json['requirePhoto'], isTrue);
      expect(json['status'], equals('active'));
      expect(json['createdAt'], isA<Timestamp>());
      expect(json['updatedAt'], isA<Timestamp>());

      final deserialized = AssignedTask.fromJson(json, 'task_001');
      expect(deserialized.id, equals(sampleTask.id));
      expect(deserialized.storeId, equals(sampleTask.storeId));
      expect(deserialized.title, equals(sampleTask.title));
      expect(deserialized.description, equals(sampleTask.description));
      expect(deserialized.createdBy, equals(sampleTask.createdBy));
      expect(deserialized.createdByRole, equals(sampleTask.createdByRole));
      expect(deserialized.targetType, equals(sampleTask.targetType));
      expect(deserialized.assignedUserIds, equals(sampleTask.assignedUserIds));
      expect(deserialized.assignedNames, equals(sampleTask.assignedNames));
      expect(deserialized.executionDates, equals(sampleTask.executionDates));
      expect(deserialized.requirePhoto, equals(sampleTask.requirePhoto));
      expect(deserialized.status, equals(sampleTask.status));
      expect(deserialized.createdAt, equals(sampleTask.createdAt));
      expect(deserialized.updatedAt, equals(sampleTask.updatedAt));
      expect(deserialized, equals(sampleTask));
    });

    test('toJson with ISO8601 string and fromJson roundtrip', () {
      final json = sampleTask.toJson(useTimestamp: false);

      expect(json['createdAt'], equals(fixedCreatedAt.toIso8601String()));
      expect(json['updatedAt'], equals(fixedUpdatedAt.toIso8601String()));

      final deserialized = AssignedTask.fromJson(json, 'task_001');
      expect(deserialized.createdAt, equals(fixedCreatedAt));
      expect(deserialized.updatedAt, equals(fixedUpdatedAt));
      expect(deserialized, equals(sampleTask));
    });

    test('copyWith creates modified clone correctly', () {
      final updated = sampleTask.copyWith(
        title: 'Tiêu đề mới',
        status: TaskStatus.completed,
        requirePhoto: false,
      );

      expect(updated.title, equals('Tiêu đề mới'));
      expect(updated.status, equals(TaskStatus.completed));
      expect(updated.requirePhoto, isFalse);
      expect(updated.id, equals(sampleTask.id));
      expect(updated.storeId, equals(sampleTask.storeId));
      expect(updated.assignedUserIds, equals(sampleTask.assignedUserIds));
    });
  });

  group('3. TaskSubmission Serialization & Deserialization Tests', () {
    final fixedSavedAt = DateTime(2026, 10, 8, 17, 30);
    final fixedCompletedAt = DateTime(2026, 10, 8, 17, 45);

    final sampleSubmission = TaskSubmission(
      id: 'uid_user_1_2026-10-08',
      taskId: 'task_001',
      storeId: 'store_alpha',
      userId: 'uid_user_1',
      userName: 'Trần Nhân Viên',
      workDate: '2026-10-08',
      reportText: 'Đã đếm xong: 15 bao đá và 20 chai syrup.',
      photoUrls: const [
        'https://storage.googleapis.com/test_photo1.jpg',
        'https://storage.googleapis.com/test_photo2.jpg',
      ],
      isCompleted: true,
      completedAt: fixedCompletedAt,
      lastSavedAt: fixedSavedAt,
    );

    test('toJson and fromJson roundtrip', () {
      final json = sampleSubmission.toJson(useTimestamp: true);

      expect(json['id'], equals('uid_user_1_2026-10-08'));
      expect(json['taskId'], equals('task_001'));
      expect(json['userId'], equals('uid_user_1'));
      expect(json['isCompleted'], isTrue);
      expect(json['photoUrls'], hasLength(2));
      expect(json['completedAt'], isA<Timestamp>());
      expect(json['lastSavedAt'], isA<Timestamp>());

      final deserialized =
          TaskSubmission.fromJson(json, 'uid_user_1_2026-10-08');
      expect(deserialized.id, equals(sampleSubmission.id));
      expect(deserialized.taskId, equals(sampleSubmission.taskId));
      expect(deserialized.storeId, equals(sampleSubmission.storeId));
      expect(deserialized.userId, equals(sampleSubmission.userId));
      expect(deserialized.userName, equals(sampleSubmission.userName));
      expect(deserialized.workDate, equals(sampleSubmission.workDate));
      expect(deserialized.reportText, equals(sampleSubmission.reportText));
      expect(deserialized.photoUrls, equals(sampleSubmission.photoUrls));
      expect(deserialized.isCompleted, equals(sampleSubmission.isCompleted));
      expect(deserialized.completedAt, equals(sampleSubmission.completedAt));
      expect(deserialized.lastSavedAt, equals(sampleSubmission.lastSavedAt));
      expect(deserialized, equals(sampleSubmission));
      expect(deserialized.hasPhotos, isTrue);
    });

    test('toJson with String timestamps and fromJson', () {
      final json = sampleSubmission.toJson(useTimestamp: false);

      expect(json['completedAt'], equals(fixedCompletedAt.toIso8601String()));
      expect(json['lastSavedAt'], equals(fixedSavedAt.toIso8601String()));

      final deserialized =
          TaskSubmission.fromJson(json, 'uid_user_1_2026-10-08');
      expect(deserialized.completedAt, equals(fixedCompletedAt));
      expect(deserialized.lastSavedAt, equals(fixedSavedAt));
    });

    test('copyWith creates modified clone correctly', () {
      final cloned = sampleSubmission.copyWith(
        isCompleted: false,
        reportText: 'Bản thảo mới',
        photoUrls: const [],
      );

      expect(cloned.isCompleted, isFalse);
      expect(cloned.reportText, equals('Bản thảo mới'));
      expect(cloned.photoUrls, isEmpty);
      expect(cloned.hasPhotos, isFalse);
      expect(cloned.id, equals(sampleSubmission.id));
    });
  });

  group('4. isApplicableForUserOnDate Logic Tests', () {
    final baseTime = DateTime(2026, 10, 8);

    final individualTask = AssignedTask(
      id: 'task_indiv',
      storeId: 'store_1',
      title: 'Dọn dẹp quầy pha chế',
      description: 'Vệ sinh máy pha cà phê',
      createdBy: 'uid_admin',
      createdByName: 'Admin',
      createdByRole: UserRole.owner,
      targetType: TaskTargetType.individual,
      assignedUserIds: const ['u_alice', 'u_bob'],
      executionDates: const ['2026-10-08', '2026-10-10'],
      createdAt: baseTime,
    );

    final allStoreTask = AssignedTask(
      id: 'task_all_store',
      storeId: 'store_1',
      title: 'Vệ sinh tổng thể cửa hàng',
      description: 'Tổng vệ sinh cuối tuần',
      createdBy: 'uid_admin',
      createdByName: 'Admin',
      createdByRole: UserRole.owner,
      targetType: TaskTargetType.allStore,
      assignedUserIds: const [], // Toàn cửa hàng không cần chỉ định user cụ thể
      executionDates: const ['2026-10-08', '2026-10-15'],
      createdAt: baseTime,
    );

    test('Individual task: returns true when user is assigned AND date matches', () {
      expect(
        individualTask.isApplicableForUserOnDate(
          userId: 'u_alice',
          dateStr: '2026-10-08',
        ),
        isTrue,
      );
      expect(
        individualTask.isApplicableForUserOnDate(
          userId: 'u_bob',
          dateStr: '2026-10-10',
        ),
        isTrue,
      );
    });

    test('Individual task: returns false when user is NOT assigned even if date matches', () {
      expect(
        individualTask.isApplicableForUserOnDate(
          userId: 'u_charlie',
          dateStr: '2026-10-08',
        ),
        isFalse,
      );
    });

    test('Individual task: returns false when date does NOT match even if user is assigned', () {
      expect(
        individualTask.isApplicableForUserOnDate(
          userId: 'u_alice',
          dateStr: '2026-10-09', // Ngày không nằm trong executionDates
        ),
        isFalse,
      );
    });

    test('AllStore task: returns true for ANY user when date matches', () {
      expect(
        allStoreTask.isApplicableForUserOnDate(
          userId: 'u_alice',
          dateStr: '2026-10-08',
        ),
        isTrue,
      );
      expect(
        allStoreTask.isApplicableForUserOnDate(
          userId: 'u_anyone',
          dateStr: '2026-10-08',
        ),
        isTrue,
      );
      expect(
        allStoreTask.isApplicableForUserOnDate(
          userId: 'u_charlie',
          dateStr: '2026-10-15',
        ),
        isTrue,
      );
    });

    test('AllStore task: returns false when date does NOT match', () {
      expect(
        allStoreTask.isApplicableForUserOnDate(
          userId: 'u_alice',
          dateStr: '2026-10-09',
        ),
        isFalse,
      );
    });
  });

  group('5. getUnfinishedTasksForUserOnDate Logic Tests', () {
    final baseTime = DateTime(2026, 10, 8);
    const storeId = 'store_test';
    const userId = 'u_target';
    const dateStr = '2026-10-08';

    final task1Completed = AssignedTask(
      id: 'task_1',
      storeId: storeId,
      title: 'Task 1 - Đã hoàn thành',
      description: 'User đã nộp báo cáo hoàn tất',
      createdBy: 'uid_admin',
      createdByName: 'Admin',
      createdByRole: UserRole.owner,
      targetType: TaskTargetType.individual,
      assignedUserIds: const [userId],
      executionDates: const [dateStr],
      createdAt: baseTime,
    );

    final task2InProgress = AssignedTask(
      id: 'task_2',
      storeId: storeId,
      title: 'Task 2 - Chưa hoàn thành',
      description: 'User đã lưu nháp nhưng chưa bấm Hoàn thành',
      createdBy: 'uid_admin',
      createdByName: 'Admin',
      createdByRole: UserRole.owner,
      targetType: TaskTargetType.individual,
      assignedUserIds: const [userId],
      executionDates: const [dateStr],
      createdAt: baseTime,
    );

    final task3NoSubmission = AssignedTask(
      id: 'task_3',
      storeId: storeId,
      title: 'Task 3 - Chưa làm',
      description: 'User chưa có submission nào',
      createdBy: 'uid_admin',
      createdByName: 'Admin',
      createdByRole: UserRole.owner,
      targetType: TaskTargetType.allStore,
      executionDates: const [dateStr],
      createdAt: baseTime,
    );

    final task4Cancelled = AssignedTask(
      id: 'task_4',
      storeId: storeId,
      title: 'Task 4 - Đã bị hủy',
      description: 'Quản lý đã hủy task này',
      createdBy: 'uid_admin',
      createdByName: 'Admin',
      createdByRole: UserRole.owner,
      targetType: TaskTargetType.individual,
      assignedUserIds: const [userId],
      executionDates: const [dateStr],
      status: TaskStatus.cancelled,
      createdAt: baseTime,
    );

    final task5Archived = AssignedTask(
      id: 'task_5',
      storeId: storeId,
      title: 'Task 5 - Đã lưu trữ',
      description: 'Task cũ đã archived',
      createdBy: 'uid_admin',
      createdByName: 'Admin',
      createdByRole: UserRole.owner,
      targetType: TaskTargetType.individual,
      assignedUserIds: const [userId],
      executionDates: const [dateStr],
      status: TaskStatus.archived,
      createdAt: baseTime,
    );

    test('filters out completed, cancelled and archived tasks, keeping unfinished ones',
        () async {
      final repo = TestTaskRepository(
        mockTasks: [
          task1Completed,
          task2InProgress,
          task3NoSubmission,
          task4Cancelled,
          task5Archived,
        ],
        mockSubmissions: {
          'task_1': TaskSubmission(
            id: '${userId}_$dateStr',
            taskId: 'task_1',
            storeId: storeId,
            userId: userId,
            userName: 'Target User',
            workDate: dateStr,
            isCompleted: true, // Đã hoàn thành
            lastSavedAt: DateTime.now(),
          ),
          'task_2': TaskSubmission(
            id: '${userId}_$dateStr',
            taskId: 'task_2',
            storeId: storeId,
            userId: userId,
            userName: 'Target User',
            workDate: dateStr,
            isCompleted: false, // Chưa hoàn thành
            lastSavedAt: DateTime.now(),
          ),
          // task_3: null (không có submission)
        },
      );

      final unfinished =
          await repo.getUnfinishedTasksForUserOnDate(storeId, userId, dateStr);

      // Mong đợi: task_2 (chưa hoàn thành) và task_3 (chưa có báo cáo)
      expect(unfinished.map((t) => t.id).toList(),
          unorderedEquals(['task_2', 'task_3']));
    });

    test('returns empty list when all tasks are completed', () async {
      final repo = TestTaskRepository(
        mockTasks: [task1Completed],
        mockSubmissions: {
          'task_1': TaskSubmission(
            id: '${userId}_$dateStr',
            taskId: 'task_1',
            storeId: storeId,
            userId: userId,
            userName: 'Target User',
            workDate: dateStr,
            isCompleted: true,
            lastSavedAt: DateTime.now(),
          ),
        },
      );

      final unfinished =
          await repo.getUnfinishedTasksForUserOnDate(storeId, userId, dateStr);

      expect(unfinished, isEmpty);
    });

    test('returns empty list when no tasks exist on that date', () async {
      final repo = TestTaskRepository(
        mockTasks: [task1Completed],
        mockSubmissions: {},
      );

      final unfinished = await repo.getUnfinishedTasksForUserOnDate(
          storeId, userId, '2026-12-31');

      expect(unfinished, isEmpty);
    });
  });
}

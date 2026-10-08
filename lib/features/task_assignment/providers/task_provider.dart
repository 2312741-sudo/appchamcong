import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/task_assignment_model.dart';
import '../repositories/task_repository.dart';

/// Tham số truy vấn task cho nhân viên theo ngày
typedef UserTaskParams = ({String storeId, String userId, String dateStr});

/// Tham số truy vấn báo cáo theo task và ngày làm việc
typedef TaskSubmissionParams = ({String storeId, String taskId, String workDate});

/// Provider quản lý đối tượng TaskRepository
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

/// Tham số truy vấn task cho cửa hàng theo ngày tùy chọn
typedef StoreTasksFilterParams = ({String storeId, String? dateStr});

/// Stream danh sách các task của cửa hàng
final storeTasksProvider =
    StreamProvider.family<List<AssignedTask>, String>((ref, storeId) {
  if (storeId.isEmpty) return Stream.value([]);
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchTasksForStore(storeId);
});

/// Stream danh sách các task của cửa hàng có thể lọc theo ngày
final storeTasksFilteredProvider =
    StreamProvider.family<List<AssignedTask>, StoreTasksFilterParams>((ref, args) {
  if (args.storeId.isEmpty) return Stream.value([]);
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchTasksForStore(args.storeId, dateStr: args.dateStr);
});

/// Stream chi tiết một task theo ID
final singleTaskProvider =
    StreamProvider.family<AssignedTask?, ({String storeId, String taskId})>((ref, args) {
  if (args.storeId.isEmpty || args.taskId.isEmpty) return Stream.value(null);
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchTask(args.storeId, args.taskId);
});

/// Provider lấy các task áp dụng cho user trong ngày làm việc
final todayUserTasksProvider =
    FutureProvider.family<List<AssignedTask>, UserTaskParams>((ref, args) async {
  if (args.storeId.isEmpty || args.userId.isEmpty) return [];
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getTasksForUserOnDate(args.storeId, args.userId, args.dateStr);
});

/// Provider lấy danh sách task chưa hoàn thành của user trong ngày làm việc
final unfinishedUserTasksProvider =
    FutureProvider.family<List<AssignedTask>, UserTaskParams>((ref, args) async {
  if (args.storeId.isEmpty || args.userId.isEmpty) return [];
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getUnfinishedTasksForUserOnDate(
      args.storeId, args.userId, args.dateStr);
});

/// Stream danh sách báo cáo tiến độ/kết quả của một task trong ngày làm việc
final taskSubmissionsProvider =
    StreamProvider.family<List<TaskSubmission>, TaskSubmissionParams>((ref, args) {
  if (args.storeId.isEmpty || args.taskId.isEmpty) return Stream.value([]);
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchSubmissionsForTask(args.storeId, args.taskId,
      workDate: args.workDate);
});

/// Stream danh sách TẤT CẢ báo cáo của một task
final allTaskSubmissionsProvider =
    StreamProvider.family<List<TaskSubmission>, ({String storeId, String taskId})>((ref, args) {
  if (args.storeId.isEmpty || args.taskId.isEmpty) return Stream.value([]);
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchSubmissionsForTask(args.storeId, args.taskId);
});

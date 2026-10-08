import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../models/task_assignment_model.dart';

/// Repository quản lý giao việc và báo cáo hoàn thành công việc
class TaskRepository {
  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;

  TaskRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore,
        _storage = storage;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _tasksRef(String storeId) =>
      firestore.collection('stores').doc(storeId).collection('assigned_tasks');

  CollectionReference<Map<String, dynamic>> _submissionsRef(
          String storeId, String taskId) =>
      _tasksRef(storeId).doc(taskId).collection('submissions');

  /// Tạo task mới và lưu vào stores/{storeId}/assigned_tasks/{taskId}
  Future<String> createTask(AssignedTask task) async {
    final docRef = task.id.isNotEmpty
        ? _tasksRef(task.storeId).doc(task.id)
        : _tasksRef(task.storeId).doc();
    final finalTask = task.id.isNotEmpty ? task : task.copyWith(id: docRef.id);
    await docRef.set(finalTask.toJson());
    return docRef.id;
  }

  /// Cập nhật task đã có
  Future<void> updateTask(AssignedTask task) async {
    final updatedTask = task.copyWith(updatedAt: DateTime.now());
    await _tasksRef(task.storeId)
        .doc(task.id)
        .set(updatedTask.toJson(), SetOptions(merge: true));
  }

  /// Xóa task khỏi cửa hàng
  Future<void> deleteTask(String storeId, String taskId) async {
    await _tasksRef(storeId).doc(taskId).delete();
  }

  /// Lấy thông tin 1 task theo ID
  Future<AssignedTask?> getTask(String storeId, String taskId) async {
    final doc = await _tasksRef(storeId).doc(taskId).get();
    if (!doc.exists || doc.data() == null) return null;
    return AssignedTask.fromJson(doc.data()!, doc.id);
  }

  /// Theo dõi 1 task theo ID theo thời gian thực
  Stream<AssignedTask?> watchTask(String storeId, String taskId) {
    return _tasksRef(storeId).doc(taskId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AssignedTask.fromJson(doc.data()!, doc.id);
    });
  }

  /// Theo dõi danh sách task của cửa hàng theo thời gian thực (tùy chọn lọc theo ngày)
  Stream<List<AssignedTask>> watchTasksForStore(
    String storeId, {
    String? dateStr,
  }) {
    Query<Map<String, dynamic>> query = _tasksRef(storeId);
    if (dateStr != null && dateStr.isNotEmpty) {
      query = query.where('executionDates', arrayContains: dateStr);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => AssignedTask.fromJson(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Lấy các task có executionDates chứa dateStr và thỏa mãn targetType / assignedUserIds
  Future<List<AssignedTask>> getTasksForUserOnDate(
    String storeId,
    String userId,
    String dateStr,
  ) async {
    try {
      final snap = await _tasksRef(storeId)
          .where('executionDates', arrayContains: dateStr)
          .get();

      final tasks = snap.docs
          .map((doc) => AssignedTask.fromJson(doc.data(), doc.id))
          .where((task) =>
              task.isApplicableForUserOnDate(userId: userId, dateStr: dateStr))
          .toList();
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tasks;
    } catch (_) {
      return [];
    }
  }

  /// Theo dõi danh sách báo cáo tiến độ/kết quả của một task (từ subcollection submissions)
  Stream<List<TaskSubmission>> watchSubmissionsForTask(
    String storeId,
    String taskId, {
    String? workDate,
  }) {
    Query<Map<String, dynamic>> query = _submissionsRef(storeId, taskId);
    if (workDate != null && workDate.isNotEmpty) {
      query = query.where('workDate', isEqualTo: workDate);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => TaskSubmission.fromJson(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.lastSavedAt.compareTo(a.lastSavedAt));
      return list;
    });
  }

  /// Lấy báo cáo của một user cho một task vào ngày làm việc cụ thể
  Future<TaskSubmission?> getUserSubmission(
    String storeId,
    String taskId,
    String userId,
    String workDate,
  ) async {
    try {
      final docId = '${userId}_$workDate';
      final docSnap = await _submissionsRef(storeId, taskId).doc(docId).get();
      if (docSnap.exists && docSnap.data() != null) {
        return TaskSubmission.fromJson(docSnap.data()!, docSnap.id);
      }

      final querySnap = await _submissionsRef(storeId, taskId)
          .where('userId', isEqualTo: userId)
          .where('workDate', isEqualTo: workDate)
          .limit(1)
          .get();

      if (querySnap.docs.isNotEmpty) {
        return TaskSubmission.fromJson(
          querySnap.docs.first.data(),
          querySnap.docs.first.id,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Lưu hoặc cập nhật báo cáo của user vào submissions/{submission.id}
  Future<void> saveSubmission(TaskSubmission submission) async {
    final docId = submission.id.isNotEmpty
        ? submission.id
        : '${submission.userId}_${submission.workDate}';
    final toSave = submission.id.isNotEmpty
        ? submission
        : submission.copyWith(id: docId);
    await _submissionsRef(submission.storeId, submission.taskId)
        .doc(docId)
        .set(toSave.toJson(), SetOptions(merge: true));
  }

  /// Upload ảnh minh chứng lên Firebase Storage
  /// Đường dẫn: stores/{storeId}/task_reports/{dateStr}/{taskId}/{userId}_${millisecondsSinceEpoch}.$fileExtension
  Future<String> uploadTaskPhoto(
    String storeId,
    String taskId,
    String userId,
    String dateStr,
    List<int> imageBytes,
    String fileExtension,
  ) async {
    final cleanExt = fileExtension.replaceAll('.', '').toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        'stores/$storeId/task_reports/$dateStr/$taskId/${userId}_$timestamp.$cleanExt';
    final ref = storage.ref().child(path);

    final contentType = (cleanExt == 'png')
        ? 'image/png'
        : (cleanExt == 'webp' ? 'image/webp' : 'image/jpeg');

    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'storeId': storeId,
        'taskId': taskId,
        'userId': userId,
        'workDate': dateStr,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    final uploadTask =
        await ref.putData(Uint8List.fromList(imageBytes), metadata);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Tìm các task áp dụng cho user vào ngày dateStr. Với mỗi task, kiểm tra submission của user ngày đó.
  /// Nếu không có submission hoặc submission.isCompleted != true, đưa vào danh sách trả về.
  Future<List<AssignedTask>> getUnfinishedTasksForUserOnDate(
    String storeId,
    String userId,
    String dateStr,
  ) async {
    final tasks = await getTasksForUserOnDate(storeId, userId, dateStr);
    final List<AssignedTask> unfinished = [];

    for (final task in tasks) {
      if (task.status == TaskStatus.cancelled ||
          task.status == TaskStatus.archived) {
        continue;
      }
      final submission =
          await getUserSubmission(storeId, task.id, userId, dateStr);
      if (submission == null || !submission.isCompleted) {
        unfinished.add(task);
      }
    }

    return unfinished;
  }
}

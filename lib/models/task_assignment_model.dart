import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'member_model.dart';

/// Phạm vi giao việc: Cho cá nhân hoặc toàn bộ nhân viên cửa hàng
enum TaskTargetType {
  individual,
  allStore,
}

extension TaskTargetTypeExtension on TaskTargetType {
  String get value {
    switch (this) {
      case TaskTargetType.individual:
        return 'individual';
      case TaskTargetType.allStore:
        return 'allStore';
    }
  }

  String get label {
    switch (this) {
      case TaskTargetType.individual:
        return 'Cá nhân';
      case TaskTargetType.allStore:
        return 'Toàn cửa hàng';
    }
  }

  static TaskTargetType fromString(String? val) {
    if (val == null) return TaskTargetType.individual;
    final normalized = val.trim().toLowerCase();
    if (normalized == 'allstore' || normalized == 'all_store' || normalized == 'all') {
      return TaskTargetType.allStore;
    }
    return TaskTargetType.individual;
  }
}

/// Trạng thái của công việc giao
enum TaskStatus {
  active,
  completed,
  cancelled,
  archived,
}

extension TaskStatusExtension on TaskStatus {
  String get value {
    switch (this) {
      case TaskStatus.active:
        return 'active';
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.cancelled:
        return 'cancelled';
      case TaskStatus.archived:
        return 'archived';
    }
  }

  String get label {
    switch (this) {
      case TaskStatus.active:
        return 'Đang thực hiện';
      case TaskStatus.completed:
        return 'Đã hoàn thành';
      case TaskStatus.cancelled:
        return 'Đã hủy';
      case TaskStatus.archived:
        return 'Lưu trữ';
    }
  }

  static TaskStatus fromString(String? val) {
    if (val == null) return TaskStatus.active;
    switch (val.trim().toLowerCase()) {
      case 'completed':
      case 'done':
        return TaskStatus.completed;
      case 'cancelled':
      case 'canceled':
        return TaskStatus.cancelled;
      case 'archived':
        return TaskStatus.archived;
      case 'active':
      default:
        return TaskStatus.active;
    }
  }
}

DateTime _parseDateTime(dynamic val, {DateTime? fallback}) {
  if (val is Timestamp) return val.toDate();
  if (val is DateTime) return val;
  if (val is String) {
    final parsed = DateTime.tryParse(val);
    if (parsed != null) return parsed;
  }
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  return fallback ?? DateTime.now();
}

DateTime? _parseNullableDateTime(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is DateTime) return val;
  if (val is String) return DateTime.tryParse(val);
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  return null;
}

/// Model công việc được giao trong cửa hàng
class AssignedTask extends Equatable {
  final String id;
  final String storeId;
  final String title;
  final String description;
  final String createdBy; // uid
  final String createdByName;
  final UserRole createdByRole;
  final TaskTargetType targetType;
  final List<String> assignedUserIds;
  final List<String> assignedNames;
  /// Danh sách ngày thực hiện định dạng YYYY-MM-DD
  final List<String> executionDates;
  final bool requirePhoto;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AssignedTask({
    required this.id,
    required this.storeId,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdByName,
    required this.createdByRole,
    required this.targetType,
    this.assignedUserIds = const [],
    this.assignedNames = const [],
    this.executionDates = const [],
    this.requirePhoto = false,
    this.status = TaskStatus.active,
    required this.createdAt,
    this.updatedAt,
  });

  /// Kiểm tra xem task có áp dụng cho nhân viên [userId] vào ngày [dateStr] không
  bool isApplicableForUserOnDate({
    required String userId,
    required String dateStr,
  }) {
    final hasDate = executionDates.contains(dateStr);
    if (!hasDate) return false;
    return targetType == TaskTargetType.allStore || assignedUserIds.contains(userId);
  }

  bool get isActive => status == TaskStatus.active;
  bool get isCompleted => status == TaskStatus.completed;
  bool get isCancelled => status == TaskStatus.cancelled;
  bool get isArchived => status == TaskStatus.archived;
  bool get isAllStore => targetType == TaskTargetType.allStore;
  bool get isIndividual => targetType == TaskTargetType.individual;

  factory AssignedTask.fromJson(Map<String, dynamic> json, String id) {
    final effectiveId = id.isNotEmpty ? id : (json['id'] as String? ?? '');
    return AssignedTask(
      id: effectiveId,
      storeId: json['storeId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      createdByName: json['createdByName'] as String? ?? '',
      createdByRole: UserRoleExtension.fromString(json['createdByRole'] as String?),
      targetType: TaskTargetTypeExtension.fromString(json['targetType'] as String?),
      assignedUserIds: (json['assignedUserIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      assignedNames: (json['assignedNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      executionDates: (json['executionDates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      requirePhoto: json['requirePhoto'] as bool? ?? false,
      status: TaskStatusExtension.fromString(json['status'] as String?),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseNullableDateTime(json['updatedAt']),
    );
  }

  factory AssignedTask.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AssignedTask.fromJson(data, doc.id);
  }

  Map<String, dynamic> toJson({bool useTimestamp = true}) {
    return {
      'id': id,
      'storeId': storeId,
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdByRole': createdByRole.value,
      'targetType': targetType.value,
      'assignedUserIds': assignedUserIds,
      'assignedNames': assignedNames,
      'executionDates': executionDates,
      'requirePhoto': requirePhoto,
      'status': status.value,
      'createdAt': useTimestamp ? Timestamp.fromDate(createdAt) : createdAt.toIso8601String(),
      if (updatedAt != null)
        'updatedAt': useTimestamp ? Timestamp.fromDate(updatedAt!) : updatedAt!.toIso8601String(),
    };
  }

  AssignedTask copyWith({
    String? id,
    String? storeId,
    String? title,
    String? description,
    String? createdBy,
    String? createdByName,
    UserRole? createdByRole,
    TaskTargetType? targetType,
    List<String>? assignedUserIds,
    List<String>? assignedNames,
    List<String>? executionDates,
    bool? requirePhoto,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssignedTask(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdByRole: createdByRole ?? this.createdByRole,
      targetType: targetType ?? this.targetType,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
      assignedNames: assignedNames ?? this.assignedNames,
      executionDates: executionDates ?? this.executionDates,
      requirePhoto: requirePhoto ?? this.requirePhoto,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        storeId,
        title,
        description,
        createdBy,
        createdByName,
        createdByRole,
        targetType,
        assignedUserIds,
        assignedNames,
        executionDates,
        requirePhoto,
        status,
        createdAt,
        updatedAt,
      ];
}

/// Model báo cáo tiến độ / hoàn thành công việc của từng nhân viên theo ca/ngày
class TaskSubmission extends Equatable {
  final String id; // format: ${userId}_${workDate}
  final String taskId;
  final String storeId;
  final String userId;
  final String userName;
  final String workDate; // YYYY-MM-DD
  final String reportText; // Văn bản báo cáo tiến độ/kết quả
  final List<String> photoUrls; // Danh sách ảnh chụp minh chứng
  final bool isCompleted; // true khi người dùng bấm Hoàn thành
  final DateTime? completedAt;
  final DateTime lastSavedAt;

  const TaskSubmission({
    required this.id,
    required this.taskId,
    required this.storeId,
    required this.userId,
    required this.userName,
    required this.workDate,
    this.reportText = '',
    this.photoUrls = const [],
    this.isCompleted = false,
    this.completedAt,
    required this.lastSavedAt,
  });

  bool get hasPhotos => photoUrls.isNotEmpty;

  factory TaskSubmission.fromJson(Map<String, dynamic> json, String id) {
    final effectiveId = id.isNotEmpty ? id : (json['id'] as String? ?? '');
    return TaskSubmission(
      id: effectiveId,
      taskId: json['taskId'] as String? ?? '',
      storeId: json['storeId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      workDate: json['workDate'] as String? ?? '',
      reportText: json['reportText'] as String? ?? '',
      photoUrls: (json['photoUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: _parseNullableDateTime(json['completedAt']),
      lastSavedAt: _parseDateTime(json['lastSavedAt']),
    );
  }

  factory TaskSubmission.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return TaskSubmission.fromJson(data, doc.id);
  }

  Map<String, dynamic> toJson({bool useTimestamp = true}) {
    return {
      'id': id,
      'taskId': taskId,
      'storeId': storeId,
      'userId': userId,
      'userName': userName,
      'workDate': workDate,
      'reportText': reportText,
      'photoUrls': photoUrls,
      'isCompleted': isCompleted,
      if (completedAt != null)
        'completedAt': useTimestamp ? Timestamp.fromDate(completedAt!) : completedAt!.toIso8601String(),
      'lastSavedAt': useTimestamp ? Timestamp.fromDate(lastSavedAt) : lastSavedAt.toIso8601String(),
    };
  }

  TaskSubmission copyWith({
    String? id,
    String? taskId,
    String? storeId,
    String? userId,
    String? userName,
    String? workDate,
    String? reportText,
    List<String>? photoUrls,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? lastSavedAt,
  }) {
    return TaskSubmission(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      storeId: storeId ?? this.storeId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      workDate: workDate ?? this.workDate,
      reportText: reportText ?? this.reportText,
      photoUrls: photoUrls ?? this.photoUrls,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        taskId,
        storeId,
        userId,
        userName,
        workDate,
        reportText,
        photoUrls,
        isCompleted,
        completedAt,
        lastSavedAt,
      ];
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum UserRole { owner, manager, employee }

enum MemberStatus { pending, active, kicked }

enum EmployeeType { fulltime, parttime }

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.owner:
        return 'Chủ';
      case UserRole.manager:
        return 'Quản lý';
      case UserRole.employee:
        return 'Nhân viên';
    }
  }

  String get value {
    switch (this) {
      case UserRole.owner:
        return 'owner';
      case UserRole.manager:
        return 'manager';
      case UserRole.employee:
        return 'employee';
    }
  }

  static UserRole fromString(String? value) {
    switch (value) {
      case 'owner':
        return UserRole.owner;
      case 'manager':
        return UserRole.manager;
      case 'employee':
      default:
        return UserRole.employee;
    }
  }
}

extension MemberStatusExtension on MemberStatus {
  String get label {
    switch (this) {
      case MemberStatus.pending:
        return 'Chờ duyệt';
      case MemberStatus.active:
        return 'Hoạt động';
      case MemberStatus.kicked:
        return 'Đã xóa';
    }
  }

  String get value {
    switch (this) {
      case MemberStatus.pending:
        return 'pending';
      case MemberStatus.active:
        return 'active';
      case MemberStatus.kicked:
        return 'kicked';
    }
  }

  static MemberStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return MemberStatus.active;
      case 'kicked':
        return MemberStatus.kicked;
      case 'pending':
      default:
        return MemberStatus.pending;
    }
  }
}

extension EmployeeTypeExtension on EmployeeType {
  String get label {
    switch (this) {
      case EmployeeType.fulltime:
        return 'Toàn thời gian';
      case EmployeeType.parttime:
        return 'Bán thời gian';
    }
  }

  String get shortLabel {
    switch (this) {
      case EmployeeType.fulltime:
        return 'Full-time';
      case EmployeeType.parttime:
        return 'Part-time';
    }
  }

  String get value {
    switch (this) {
      case EmployeeType.fulltime:
        return 'fulltime';
      case EmployeeType.parttime:
        return 'parttime';
    }
  }

  static EmployeeType fromString(String? value) {
    switch (value) {
      case 'parttime':
        return EmployeeType.parttime;
      case 'fulltime':
      default:
        return EmployeeType.fulltime;
    }
  }
}

class MemberModel extends Equatable {
  final String userId;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final MemberStatus status;
  final EmployeeType employeeType;
  final double baseMonthlySalary; // fulltime: monthly salary in VND (thousands)
  final double baseHourlyRate; // parttime: per hour in VND (thousands)
  final double standardHoursPerMonth; // default 208
  final DateTime joinedAt;
  final String? department; // Department ID (from store.departments)

  const MemberModel({
    required this.userId,
    required this.name,
    this.phone,
    this.avatarUrl,
    required this.role,
    required this.status,
    required this.employeeType,
    this.baseMonthlySalary = 0,
    this.baseHourlyRate = 0,
    this.standardHoursPerMonth = 208,
    required this.joinedAt,
    this.department,
  });

  // Convenience getters
  bool get isOwner => role == UserRole.owner;
  bool get isManager => role == UserRole.manager;
  bool get isEmployee => role == UserRole.employee;
  bool get isActive => status == MemberStatus.active;
  bool get isPending => status == MemberStatus.pending;
  bool get isKicked => status == MemberStatus.kicked;
  bool get isFulltime => employeeType == EmployeeType.fulltime;
  bool get isParttime => employeeType == EmployeeType.parttime;
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory MemberModel.fromJson(Map<String, dynamic> json, String userId) {
    return MemberModel(
      userId: userId,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      role: UserRoleExtension.fromString(json['role'] as String?),
      status: MemberStatusExtension.fromString(json['status'] as String?),
      employeeType:
          EmployeeTypeExtension.fromString(json['employeeType'] as String?),
      baseMonthlySalary:
          (json['baseMonthlySalary'] as num?)?.toDouble() ?? 0.0,
      baseHourlyRate: (json['baseHourlyRate'] as num?)?.toDouble() ?? 0.0,
      standardHoursPerMonth:
          (json['standardHoursPerMonth'] as num?)?.toDouble() ?? 208.0,
      joinedAt: json['joinedAt'] is Timestamp
          ? (json['joinedAt'] as Timestamp).toDate().toUtc()
          : DateTime.tryParse(json['joinedAt'] as String? ?? '') ??
              DateTime.now().toUtc(),
      department: json['department'] as String?,
    );
  }

  factory MemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MemberModel.fromJson(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'role': role.value,
      'status': status.value,
      'employeeType': employeeType.value,
      'baseMonthlySalary': baseMonthlySalary,
      'baseHourlyRate': baseHourlyRate,
      'standardHoursPerMonth': standardHoursPerMonth,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'department': department,
    };
  }

  MemberModel copyWith({
    String? userId,
    String? name,
    String? phone,
    String? avatarUrl,
    UserRole? role,
    MemberStatus? status,
    EmployeeType? employeeType,
    double? baseMonthlySalary,
    double? baseHourlyRate,
    double? standardHoursPerMonth,
    DateTime? joinedAt,
    String? department,
    bool clearPhone = false,
    bool clearAvatarUrl = false,
    bool clearDepartment = false,
  }) {
    return MemberModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: clearPhone ? null : (phone ?? this.phone),
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      role: role ?? this.role,
      status: status ?? this.status,
      employeeType: employeeType ?? this.employeeType,
      baseMonthlySalary: baseMonthlySalary ?? this.baseMonthlySalary,
      baseHourlyRate: baseHourlyRate ?? this.baseHourlyRate,
      standardHoursPerMonth:
          standardHoursPerMonth ?? this.standardHoursPerMonth,
      joinedAt: joinedAt ?? this.joinedAt,
      department: clearDepartment ? null : (department ?? this.department),
    );
  }

  @override
  List<Object?> get props => [
        userId,
        name,
        phone,
        avatarUrl,
        role,
        status,
        employeeType,
        baseMonthlySalary,
        baseHourlyRate,
        standardHoursPerMonth,
        joinedAt,
        department,
      ];

  @override
  String toString() =>
      'MemberModel(userId: $userId, name: $name, role: ${role.value}, status: ${status.value})';
}

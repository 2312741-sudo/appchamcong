import '../../models/member_model.dart';

/// Centralized Role-Based Access Control (RBAC) Permission Matrix
///
/// Matrix:
/// | Chức năng                      | Chủ | Quản lý 1 | Quản lý 2 | Quản lý cũ (tạm thời) | Nhân viên |
/// |--------------------------------|-----|-----------|-----------|------------------------|-----------|
/// | Xếp/sửa lịch làm cả cửa hàng   |  ✓  |     ✓     |     ✗     |           ✓            |     ✗     |
/// | Xem lịch làm cả cửa hàng        |  ✓  |     ✓     |     ✓     |           ✓            |     ✗ (*) |
/// | Xếp/tick chở hàng               |  ✓  |     ✓     |     ✓     |           ✓            |     ✗ (*) |
/// | Xếp/tick giao hàng              |  ✓  |     ✓     |     ✓     |           ✓            |     ✗ (*) |
/// | Chấp nhận (duyệt) TV mới       |  ✓  |  ✓ (MỚI)  |     ✗     |           ✓            |     ✗     |
/// | Quản lý vai trò / nhân sự      |  ✓  |     ✗     |     ✗     |           ✗            |     ✗     |
/// | Cài đặt cửa hàng                |  ✓  |     ✗     |     ✗     |           ✗            |     ✗     |
class AppPermissions {
  const AppPermissions._();

  /// Quyền Xếp / tạo / sửa / xóa / lưu lịch làm việc cho toàn bộ cửa hàng
  static bool canManageSchedule(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.owner ||
        role == UserRole.manager1 ||
        role == UserRole.legacyManager;
  }

  /// Quyền Xem lịch làm việc của toàn bộ cửa hàng
  static bool canViewStoreSchedule(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.owner ||
        role == UserRole.manager1 ||
        role == UserRole.manager2 ||
        role == UserRole.legacyManager;
  }

  /// Quyền Xếp / tick phụ cấp Chở hàng
  static bool canTickDelivery(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.owner ||
        role == UserRole.manager1 ||
        role == UserRole.manager2 ||
        role == UserRole.legacyManager;
  }

  /// Quyền Xếp / tick phụ cấp Giao hàng
  static bool canTickGiaoHang(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.owner ||
        role == UserRole.manager1 ||
        role == UserRole.manager2 ||
        role == UserRole.legacyManager;
  }

  /// Quyền Chấp nhận (duyệt) hoặc từ chối thành viên mới gia nhập
  /// Áp dụng cho: Chủ, Quản lý 1, và Quản lý cũ (tạm thời)
  static bool canApproveMembers(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.owner ||
        role == UserRole.manager1 ||
        role == UserRole.legacyManager;
  }

  /// Quyền quản lý phân vai trò nhân viên (Chỉ dành cho Chủ)
  static bool canAssignRoles(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.owner;
  }

  /// Quyền chỉnh sửa cấu hình / cài đặt cửa hàng
  static bool canManageStoreSettings(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.owner;
  }

  /// Kiểm tra có phải cấp Quản lý trở lên hay không
  static bool isManagerOrAbove(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.owner ||
        role == UserRole.manager1 ||
        role == UserRole.manager2 ||
        role == UserRole.legacyManager;
  }

  /// Kiểm tra tài khoản Quản lý cũ chưa được phân loại
  static bool isUnclassifiedManager(UserRole? role) {
    return role == UserRole.legacyManager;
  }
}

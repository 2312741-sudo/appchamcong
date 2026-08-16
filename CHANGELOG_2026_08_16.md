# NHẬT KÝ THAY ĐỔI & NÂNG CẤP (CHANGELOG) - 16/08/2026

Dự án: **Chấm Công Trạm** (`com.chamcong.chamCongTram`)

---

## 1. Khắc Phục Triệt Để Lỗi Đồng Bộ Firebase & Lỗi "Mất Cửa Hàng" / Loading Chậm
- **Vấn đề**:
  - Đăng nhập vào app bị quay loading lâu.
  - Vừa đăng nhập xong vào màn hình báo "Bạn chưa tham gia cửa hàng nào" dù tài khoản đã thuộc cửa hàng (chỉ khi kill app mở lại mới nhận).
  - Khi chủ đổi vai trò (Owner -> Manager -> Employee), app không tự đổi giao diện theo thời gian thực mà phải đăng xuất/đăng nhập lại.
- **Khắc phục**:
  - **Hợp nhất Provider người dùng**: Chuẩn hóa `userProvider` về `currentUserProvider` trong `lib/features/store/providers/user_repository.dart`, loại bỏ phân mảnh cache dữ liệu.
  - **Tự phục hồi dữ liệu cửa hàng (Self-healing)**: Cập nhật `StoreRepository.getUserStores` sử dụng `collectionGroup('members')` để tự phát hiện và sửa chữa `storeIds` trong Firestore của tài khoản nếu bị lệch.
  - **Lắng nghe vai trò theo thời gian thực (< 100ms)**: Tạo mới `currentMemberStreamProvider` trong `lib/features/store/providers/store_provider.dart` để tự động chuyển đổi giao diện Dashboard tức thì khi quyền hạn thay đổi trên Firestore.
  - **Đăng xuất sạch (Clean State Invalidation)**: Bổ sung logic `ref.invalidate()` toàn bộ store, member, attendance, schedule providers khi người dùng đăng xuất trong `AuthNotifier.signOut()`.
  - **Tối ưu SplashScreen**: Loại bỏ các bước timeout tuần tự gây trễ khởi động app.

---

## 2. Phân Cấp Role Quản Lý Thành 2 Cấp Độ (Quản Lý 1 & Quản Lý 2)
- **Yêu cầu**: Tách vai trò "Quản lý" thành 2 cấp độ với phân quyền độc lập, minh bạch:
  - **Quản lý 1 (`UserRole.manager1`)**: Quyền đầy đủ (Xếp lịch làm, Xem lịch, Chở hàng, Giao hàng, **MỚI: Duyệt thành viên mới**).
  - **Quản lý 2 (`UserRole.manager2`)**: Quyền hỗ trợ (Xem lịch, Chở hàng, Giao hàng; **KHÔNG** được xếp lịch làm, **KHÔNG** được duyệt thành viên).
- **Triển khai**:
  - Cập nhật model `MemberModel`, `UserRole`, `UserRoleExtension` trong `lib/models/member_model.dart` tương thích ngược hoàn toàn với dữ liệu cũ (`manager`).
  - Xây dựng module kiểm soát quyền hạn tập trung `lib/core/auth/app_permissions.dart`:
    - `canManageSchedule(role)`: Chỉ Chủ và Quản lý 1.
    - `canApproveMembers(role)`: Chỉ Chủ và Quản lý 1.
    - `canAssignDelivery(role)`: Chủ, Quản lý 1, Quản lý 2.
  - Cập nhật giao diện gán vai trò trong `MemberDetailScreen` và hiển thị huy hiệu `RoleBadge` với mã màu riêng biệt (Quản lý 1: Xanh dương đậm, Quản lý 2: Xanh Teal).
  - Bổ sung bộ kiểm thử tự động `test/manager_roles_permissions_test.dart`.

---

## 3. Mở Quyền Sửa Lịch Tuần & Tối Ưu Màn Hình Quản Lý Lịch
- **Khắc phục**:
  - Gỡ bỏ giới hạn khóa sửa lịch tuần hiện tại `_isCurrentWeek` trong `ScheduleManagerScreen` để Chủ và Quản lý 1 có thể linh hoạt điều chỉnh ca trực khi có phát sinh.
  - Dọn dẹp nút shortcut "Sửa lịch tuần này" ở màn hình tổng quan theo yêu cầu, tập trung thao tác chỉnh sửa lịch làm việc trong màn hình quản lý lịch chuyên dụng.

---

## 4. Tái Cấu Trúc & Nâng Cấp Toàn Diện Hệ Thống Thông Báo (Real-Time Notification System)
- **Yêu cầu & Nâng cấp**:
  - **Nút chuông thông báo dùng chung (`NotificationBellIcon`)**:
    - Đặt tại góc trên bên phải AppBar / Header của **tất cả 4 vai trò** (Chủ quán, Quản lý 1, Quản lý 2, Nhân viên).
    - Tích hợp Badge đỏ hiển thị số lượng thông báo chưa đọc theo thời gian thực (`snapshots()`).
  - **Xoá bỏ nút thông báo cũ**: Xoá hoàn toàn nút thông báo không hoạt động ở Tab Hồ sơ của Nhân viên trong `employee_dashboard.dart`.
  - **Màn hình thông báo (`NotificationsScreen`)**:
    - Thiết kế giao diện chuẩn phong cách Trắng - Đỏ - Xanh của ứng dụng.
    - Phân biệt rõ rệt giữa thông báo Chưa đọc (chấm đỏ, viền nổi bật, chữ đậm) và Đã đọc.
    - Nút "Đã đọc tất cả" trên AppBar.
    - Chạm vào thông báo: tự động đánh dấu đã đọc và chuyển tiếp tới đúng màn hình nghiệp vụ liên quan.
  - **Đầy đủ các luồng thông báo nghiệp vụ**:
    1. **Tạm ứng lương**:
       - Nhân viên gửi yêu cầu ứng lương -> Gửi thông báo tới **Chủ quán** (`/manage-advances`).
       - Chủ quán duyệt/từ chối ứng lương -> Gửi thông báo phản hồi tới **Nhân viên** (`/salary`).
    2. **Thành viên & Duyệt đơn**:
       - Nhân viên mới xin vào cửa hàng -> Gửi thông báo tới **Chủ quán & Quản lý 1** (`/pending-members`).
       - Duyệt hoặc từ chối thành viên -> Gửi thông báo tới **Nhân viên**.
    3. **Lịch làm việc**:
       - Cập nhật lịch làm tuần -> Gửi thông báo tới toàn bộ nhân viên & quản lý (`/schedule`).
       - Tự động nhắc nhở đăng ký lịch tuần mới vào Thứ Năm & Thứ Sáu trước hạn chót 23:59 cho nhân viên & quản lý (`/schedule`).
    4. **Báo cáo sản xuất**:
       - Nhắc nhở nộp báo cáo checklist ca SX khi nhân viên quên nộp trước khi bấm ra ca.
    5. **Giao / Chở hàng**:
       - Thông báo phân công phụ cấp giao hàng / chở hàng.

---

## 5. Kết Quả Kiểm Thử & Đảm Bảo Chất Lượng
- **Bộ Unit Tests**:
  - `test/manager_roles_permissions_test.dart`: Kiểm tra logic phân cấp Quản lý 1/2 và phân quyền.
  - `test/notification_system_test.dart`: Kiểm tra logic thông báo, lọc role, unread count, tạm ứng lương và nhắc lịch tuần.
  - **Tổng kết**: **36/36 tests PASSED 100%**.
- **Phân tích mã nguồn (`flutter analyze`)**: **0 Errors**.
- **Đã push code & changelog lên nhánh `main` trên GitHub**.

# BÁO CÁO CẬP NHẬT TÍNH NĂNG & NHẬT KÝ THAY ĐỔI (CHANGELOG)
**Ngày cập nhật:** 22/08/2026  
**Phiên bản:** `v1.0.3` (Mobile App: `1.0.3+4`, Web Dashboard: `1.0.3`)  
**Tác giả:** Nguyễn Thanh Tâm ([nthanhtam.402@gmail.com](mailto:nthanhtam.402@gmail.com))  

---

## 📌 TỔNG HỢP CÁC TÍNH NĂNG & NÂNG CẤP ĐÃ HOÀN TẤT

### 1. Sắp xếp thứ tự nhân viên tùy chỉnh (Drag & Drop + Up/Down)
- **Giao diện & Thao tác:**
  - **Trên Web:** Bảng *Danh sách nhân viên* (`/dashboard/members`) và bảng *Lịch làm việc* (`/dashboard/schedule`) hỗ trợ kéo thả dòng hoặc bấm nút ▲ / ▼ để di chuyển vị trí nhân viên.
  - **Trên Mobile App:** Màn hình *Danh sách nhân viên* (`MembersListScreen`) sử dụng `ReorderableListView` hỗ trợ kéo thả tay cầm ☰ để hoán đổi vị trí trực tiếp.
- **Lưu trữ dữ liệu:** Lưu trữ tập trung vào trường `memberOrder: List<String>` (mảng các `userId`) trong document `stores/{storeId}` trên Cloud Firestore. Tự động đồng bộ và hiển thị nhất quán trên mọi thiết bị.
- **Quy tắc phân quyền (RBAC):**
  - **Chủ cửa hàng (Owner):** Toàn quyền kéo thả, di chuyển và lưu thứ tự hiển thị nhân viên.
  - **Các vai trò khác (Quản lý 1, Quản lý 2, Nhân viên):** Tự động tải và xem danh sách nhân viên theo đúng thứ tự mà Chủ quán đã sắp xếp. Các nút kéo thả, nút di chuyển hoàn toàn ẩn đối với các vai trò này.

---

### 2. Dấu tick ẩn lịch nhân viên tùy chọn trong tab Lịch cửa hàng
- **Giao diện & Thao tác:**
  - Cột thao tác nhanh trên Web và nút gạt Switch trên Mobile cho phép Chủ quán chuyển đổi nhanh giữa trạng thái 👁️ **Hiện** và 🙈 **Ẩn lịch**.
  - Checkbox "Ẩn lịch trên Lịch cửa hàng" được tích hợp trong Modal chỉnh sửa thành viên.
- **Lưu trữ dữ liệu:** Lưu trữ trong trường `hiddenScheduleUserIds: List<String>` trong document `stores/{storeId}`.
- **Quy tắc hiển thị & Bảo mật:**
  - **Chủ cửa hàng (Owner):** Luôn nhìn thấy toàn bộ nhân viên, những nhân viên bị ẩn lịch sẽ được gắn nhãn 🙈 `Ẩn` để dễ dàng nhận biết.
  - **Nhân viên bị ẩn:** Vẫn xem được lịch làm việc cá nhân của chính mình.
  - **Quản lý & Nhân viên khác:** Hoàn toàn **không thấy** dòng lịch của nhân viên bị ẩn trên lịch chung của cửa hàng, đảm bảo tính riêng tư theo yêu cầu quản lý.

---

### 3. Sắp xếp danh mục Checklist sản xuất
- **Giao diện & Thao tác:**
  - **Trên Web:** Trang *Sản xuất* (`/dashboard/production`) hỗ trợ kéo thả hoặc bấm nút ▲ / ▼ tại cột Thứ tự để hoán đổi vị trí các đầu việc checklist.
  - **Trên Mobile App:** Màn hình *Danh mục Checklist Sản xuất* (`ProductionTasksScreen`) hỗ trợ kéo giữ biểu tượng ☰ để sắp xếp thứ tự trực quan.
- **Lưu trữ dữ liệu:** Cập nhật trường `order: number` trong từng document công việc thuộc subcollection `stores/{storeId}/production_tasks/{taskId}`.
- **Quy tắc phân quyền (RBAC):**
  - **Chủ cửa hàng (Owner):** Có toàn quyền tạo mới (+), chỉnh sửa tên/đơn vị, xóa, bật/tắt kích hoạt và kéo sắp xếp thứ tự checklist.
  - **Các vai trò khác (Quản lý 1, Quản lý 2, Nhân viên):** Mở xem danh mục checklist và báo cáo sản xuất theo chế độ chỉ đọc (Read-only), dữ liệu tự động sắp xếp chuẩn theo thứ tự do Chủ quán định cấu hình.

---

### 4. Bổ sung chức năng Chấm công cho tài khoản Chủ cửa hàng (Owner)
- **Thẻ trạng thái chấm công cá nhân:** Đặt ngay trên trang chủ Tổng quan (`_OwnerHomeTab`) của Chủ quán, hiển thị rõ ràng:
  - Trạng thái ca làm việc (Chưa vào ca / Đang trong ca / Đã hoàn thành ca).
  - Giờ bấm vào ca và số giờ làm việc thực tế được cập nhật real-time.
  - Nút bấm nhanh để **Vào ca** hoặc **Ra ca**.
- **Nút nổi Chấm công (Floating Action Button):** Nút Chấm công màu đỏ nổi bật ở góc dưới màn hình giúp Chủ quán có thể điểm danh bất cứ lúc nào qua WiFi, GPS hoặc quét QR Code.
- **Hệ thống Menu & Lối tắt cá nhân:**
  - 🔘 **Chấm công:** Điều hướng tới màn hình `CheckInScreen` xác thực vị trí/WiFi.
  - 🕒 **Lịch sử công của tôi:** Xem chi tiết từng ngày công, giờ vào/ra tại `AttendanceHistoryScreen`.
  - 🗓️ **Lịch làm cá nhân & Đăng ký ca:** Tự do đăng ký và xem ca tại `ScheduleRegisterScreen`.
  - 💰 **Bảng lương & Tạm ứng cá nhân:** Theo dõi chi tiết thu nhập tại `SalaryScreen`.
- **Tổng hợp dữ liệu:** Giờ công và lịch sử chấm công của Chủ quán được tích hợp đầy đủ vào Bảng công tháng và file Excel xuất ra.

---

## 🧪 KẾT QUẢ KIỂM THỬ HỆ THỐNG
- **Web Dashboard (`cham_cong_web`):** Build thành công 100% không cảnh báo (`Compiled successfully, 12/12 static pages generated`).
- **Mobile App (`cham_cong_tram`):** Vượt qua toàn bộ **55/55 test suites (0 lỗi)** (`All tests passed!`).

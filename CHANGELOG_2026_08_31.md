# 📋 NHẬT KÝ THAY ĐỔI CHI TIẾT (CHANGELOG) — 31/08/2026 & 01/09/2026 (v1.0.6)

**Dự án:** Chấm Công Trạm (`cham_cong_tram` Mobile App & `cham_cong_web` Web Dashboard)  
**Tác giả:** Nguyễn Thanh Tâm ([nthanhtam.402@gmail.com](mailto:nthanhtam.402@gmail.com))  
**Phiên bản phát hành:** `v1.0.6` (Mobile: `1.0.6+8`, Web: `1.0.6`)

---

## 🚀 TỔNG HỢP NÂNG CẤP & SỬA LỖI TRONG BẢN PHÁT HÀNH v1.0.6

### 1. [TÍNH NĂNG MỚI] Màn hình "Thông tin ứng dụng" (About App Screen)
- Bổ sung màn hình `/about-app` (`AboutAppScreen`) truy cập nhanh từ Drawer Cài đặt / Hồ sơ.
- Hiển thị logo nhận diện thương hiệu, tên ứng dụng, phiên bản hiện tại và build number động lấy từ `package_info_plus` (ví dụ: `1.0.6 (8)`).
- Tích hợp các liên kết quan trọng: Điều khoản sử dụng, Chính sách bảo mật, Thông tin liên hệ hỗ trợ nhà phát triển.
- Nút "Kiểm tra bản cập nhật mới" kết nối với dịch vụ kiểm tra phiên bản thời gian thực.

### 2. [TÍNH NĂNG MỚI] Dịch vụ kiểm tra & bắt buộc cập nhật (`AppUpdateService`)
- Tích hợp `AppUpdateService` kiểm tra cấu hình phiên bản từ Firestore (`/system/app_version` / cấu hình hệ thống).
- Hiển thị modal cập nhật khi có phiên bản mới:
  - Cho phép người dùng cập nhật tự nguyện hoặc bắt buộc (`forceUpdate`).
  - Hỗ trợ nút dẫn thẳng sang App Store (iOS) hoặc Google Play Store (Android).

### 3. [NÂNG CẤP UI/UX] Mở rộng Box "Nhân viên đang làm" (Active Staff Box)
- Tăng số lượng nhân viên hiển thị đồng thời trong Box "Nhân viên đang làm" trên Dashboard từ 5 lên **8 nhân viên**.
- Nâng cấp nút "Xem tất cả" mở màn hình chuyên biệt `/active-staff` (`ActiveStaffScreen`):
  - Hiển thị đầy đủ 100% danh sách nhân viên đang trong ca làm việc thời gian thực.
  - Hỗ trợ thanh tìm kiếm theo tên và lọc theo bộ phận (`Sản Xuất`, `Bán Hàng`, `Kho`).
  - Hiển thị đầy đủ giờ vào ca, thời gian đã làm việc và cảnh báo đi muộn nếu có.

### 4. [SỬA LỖI CỐT LÕI] Sửa dứt điểm lệch múi giờ 7 tiếng trong Bảng lương (Timezone Fix)
- **Triệu chứng:** Trong màn hình Bảng lương (`SalaryDetailScreen`), khi bấm vào ngày làm việc để xem chi tiết các ca làm trong ngày, giờ vào ca và ra ca bị lệch 7 tiếng so với thực tế (giờ UTC hiển thị trực tiếp thay vì giờ Việt Nam UTC+7).
- **Nguyên nhân gốc:** `AttendanceModel` lưu trữ `checkIn`/`checkOut` dưới dạng UTC (`DateTime.toUtc()`). Tại `salary_detail_screen.dart`, 3 vị trí format giờ đã gọi trực tiếp `DateFormat('HH:mm').format(a.checkIn)` mà thiếu `.toLocal()`.
- **Giải pháp:**
  - Bổ sung `.toLocal()` tại dòng 973 (giờ Check-in trong dialog chi tiết), dòng 974 (giờ Check-out trong dialog chi tiết) và dòng 1058 (giờ Check-in ở bottom floating bar).
  - Rà soát toàn diện 100% codebase để đảm bảo mọi nơi hiển thị giờ đều đồng nhất chuẩn UTC+7.

### 5. [ĐIỀU TRA HỆ THỐNG] Xác minh hiện tượng tự động Out ca lúc 00:00 (Auto-Checkout Investigation)
- **Điều tra thực tế:** Chạy kịch bản truy vấn dữ liệu Firestore trên toàn bộ 93 bản ghi chấm công (30 ngày gần nhất) qua 3 chi nhánh cửa hàng.
- **Kết luận:**
  - Hệ thống **hoàn toàn không có bất kỳ Cloud Functions, Cron Job hay background task** nào tự động đóng ca lúc nửa đêm.
  - Các bản ghi có mốc Check-out `00:00:00.000` đều do Quản lý chỉnh sửa thủ công (`isEdited: true`).
  - Các ca làm xuyên đêm thực tế của nhân viên (`isEdited: false`) có mốc ra ca tự nhiên (có mili-giây, tổng giờ làm hợp lý).
  - Hiện tượng nhìn thấy "00:00" trước đây thực chất là do lỗi múi giờ hiển thị UTC (Lỗi số 4) khi nhân viên ra ca lúc 07:00 sáng VN (= 00:00 UTC). Sau khi sửa lỗi múi giờ, vấn đề đã được giải quyết triệt để.

### 6. [RÀ SOÁT THÔNG BÁO] Tối ưu hóa hệ thống Push Notification & Nhắc nhở
- Chuẩn hóa luồng thông báo nhắc nhở ca làm việc và nhắc nhở báo cáo checklist.
- Đảm bảo token FCM được dọn dẹp sạch sẽ khi đăng xuất và loại trừ trùng lặp khi đăng nhập đa tài khoản trên cùng thiết bị.
- Đồng bộ kênh thông báo và quyền hiển thị cho tất cả các vai trò Quản lý và Chủ cửa hàng.

---

## 🧪 KẾT QUẢ KIỂM THỬ
- `flutter test`: **95/95 test cases passed (100%)**
- `flutter analyze`: **0 errors**

# NHẬT KÝ THAY ĐỔI & NÂNG CẤP (CHANGELOG) - 15/08/2026

Dự án: **Chấm Công Trạm** (`com.chamcong.chamCongTram`)

---

## 1. Khắc Phục Lỗi Checklist Bắt Buộc Bộ Phận SX Không Nhất Quán
- **Vấn đề**: Khi nhân viên Sản xuất (SX) bấm "Out ca", hệ thống có lúc chặn checklist có lúc không chặn do sai lệch nhận diện mã bộ phận (ví dụ: `SX`, `Sản xuất`, `dept_sx`, hoặc ca làm việc được chỉ định bộ phận tạm thời `shiftId|deptId`).
- **Khắc phục**:
  - Tạo mới utility `lib/core/utils/department_utils.dart` chuẩn hóa nhận diện bộ phận SX (hỗ trợ xóa dấu tiếng Việt, không phân biệt hoa thường, so khớp chính xác cả ID, ShortName và Tên bộ phận).
  - Cập nhật `AttendanceRepository.checkOut` và `ProductionRepository.hasCompletedChecklistToday` để nhận diện chính xác ca làm và bộ phận nhân viên trước khi cho phép checkout.
  - Bổ sung bộ kiểm thử tự động `test/department_utils_test.dart`.

---

## 2. Tính Năng Cấu Hình Tối Đa 10 Điểm WiFi Chấm Công
- **Yêu cầu**: Cho phép chủ cửa hàng cấu hình tối đa 10 địa chỉ WiFi/IP. Nhân viên có thể chấm công tại bất kỳ điểm nào trong 10 điểm này. Tự động lấy tên WiFi (SSID) khi thêm mới.
- **Khắc phục & Nâng cấp**:
  - Cập nhật model `StoreWifi` và `StoreModel` lưu trữ danh sách `wifis: List<StoreWifi>` (tối đa 10 phần tử).
  - Hỗ trợ cơ chế tự động tương thích ngược (Auto-migration) từ trường `networkIP` cũ sang danh sách `wifis`.
  - Cập nhật `LocationUtils` và `LocationProvider` kiểm tra IP hiện tại của nhân viên khớp với bất kỳ điểm nào trong danh sách.
  - Thiết kế lại giao diện quản lý WiFi trong `StoreSettingsScreen` và `CreateStoreScreen`: Hiển thị danh sách thẻ WiFi, nút thêm nhanh IP hiện tại kèm tên WiFi, nút xóa, hiển thị trạng thái WiFi hiện tại.
  - Bổ sung bộ kiểm thử tự động `test/wifi_settings_test.dart`.

---

## 3. Sửa Triệt Để Lỗi Xuất File & Chia Sẻ Trên Mobile (`sharePositionOrigin`)
- **Vấn đề**: Khi xuất file Excel hoặc chia sẻ trên iOS/iPadOS, app bị crash với lỗi `PlatformException: sharePositionOrigin: argument must be set, {{0,0}, {0,0}} must be non-zero...`.
- **Khắc phục**:
  - Tạo mới utility `lib/core/utils/share_utils.dart` với hàm `getSharePositionOrigin(BuildContext? context)` tự động trích xuất `RenderBox` chuẩn xác hoặc fallback về `Rect` hợp lệ giữa màn hình.
  - Bọc try-catch và hiển thị thông báo lỗi thân thiện bằng tiếng Việt, không để lộ mã lỗi kỹ thuật.
  - Thay thế toàn bộ các điểm xuất file và chia sẻ trong app:
    - Xuất Excel Bảng chấm công (`ExcelExportService`, `AttendanceTableScreen`).
    - Xuất Excel Báo cáo lương (`ExcelExportService`, `SalaryOverviewScreen`).
    - Xuất Excel Lịch làm việc tuần (`ExportUtils`, `ScheduleManagerScreen`).
    - Xuất Excel Bảng công tổng hợp (`ExportUtils`).
    - Chia sẻ mã QR cửa hàng (`QrDisplayScreen`).
  - Bổ sung bộ kiểm thử `test/share_utils_test.dart`.

---

## 4. Sửa Lỗi Route "Không tìm thấy trang" Khi Bật QR Toàn Màn Hình
- **Vấn đề**: Bấm xem mã QR toàn màn hình bị báo lỗi `no routes for location: /qr-display`.
- **Khắc phục**:
  - Khai báo hằng số `AppRoutes.qrDisplay = '/qr-display'` và đăng ký `GoRoute` vào `lib/app/router.dart`.
  - Cập nhật các nút xem/chia sẻ QR tại `StoreSettingsScreen` và `OwnerDashboard` điều hướng type-safe tới màn hình `QrDisplayScreen`.

---

## 5. Khôi Phục Đúng Thiết Kế & Cấu Trúc File Excel Lịch Làm Việc Tuần
- **Khắc phục**:
  - Thiết kế lại toàn bộ template xuất Excel trong `ExportUtils.exportWeeklyScheduleToExcel` theo đúng chuẩn thiết kế gốc:
    - **Dòng tiêu đề**: `CÔNG VIỆC THÁNG [M] NĂM [YYYY] [TÊN CỬA HÀNG]` (chữ xanh cyan, in đậm, căn giữa).
    - **Header 2 dòng**: Cột `TÍNH CHẤT`, 7 ngày (Monday -> Sunday) kèm ngày/tháng `dd/MM`, cột `TỔNG SỐ GIỜ TRONG TUẦN`.
    - **Cấu trúc 4 cột mỗi ngày**: Giờ bắt đầu, Giờ kết thúc, Tên ca/bộ phận (in đậm SX/DR), Số giờ làm việc.
    - **Dòng dữ liệu nhân viên**: Tên viết hoa in đậm, dữ liệu từng ngày và tổng giờ làm việc trong tuần.

---

## 6. Đáp Ứng 100% Tiêu Chuẩn Nộp Duyệt Lên App Store (Apple Developer)
- **Cải tiến & Bổ sung**:
  - **Xóa tài khoản (Apple Guideline 5.1.1(v))**: Tích hợp tính năng xóa tài khoản vĩnh viễn kèm popup xác thực mật khẩu trong `ProfileSettingsScreen` và `AuthNotifier`.
  - **Cấu hình `ios/Runner/Info.plist`**:
    - Thêm cờ `<key>ITSAppUsesNonExemptEncryption</key><false/>` để tránh thủ tục mã hóa khi upload bản build.
    - Cập nhật các chuỗi quyền (`NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`) đầy đủ và thân thiện.
  - **Kiểm thử & Biên dịch**:
    - `flutter test`: Toàn bộ 17/17 tests passed.
    - `flutter analyze`: 0 errors / 0 warnings.
    - `flutter build ios --release`: Biên dịch thành công gói Release `Runner.app` (44.7MB).

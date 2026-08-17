# Nhật Ký Thay Đổi (Changelog) - Chấm Công Trạm

Tất cả các thay đổi đáng chú ý của dự án **Chấm Công Trạm** sẽ được ghi lại chi tiết trong tài liệu này.

Định dạng dựa trên [Keep a Changelog](https://keepachangelog.com/vi/1.0.0/) và dự án tuân thủ theo [Semantic Versioning](https://semver.org/).

---

## [1.0.1] - 17/08/2026

### 🚀 Phát hành & Cấu hình Google Play
- **Mã phiên bản (Version Code):** Nâng cấp lên `versionCode: 2` (`version: 1.0.1+2`).
- **Khóa ký phát hành (Release Signing):** Tạo và tích hợp Khóa ký phát hành (Upload Keystore) chuẩn `PKCS12` cho Android App Bundle (`.aab`).
- **Chính sách an toàn dữ liệu:** Bổ sung trang web hỗ trợ xóa tài khoản & dữ liệu người dùng trực tuyến (`docs/delete-account.html`) đáp ứng chính sách Google Play Console.
- **Tài sản truyền thông:** Thiết kế đồ họa tính năng (Feature Graphic 1024x500) và Biểu tượng ứng dụng (App Icon 512x512) chuẩn Cửa hàng Play.

### ⚡ Tối ưu hóa & Sửa lỗi
- **Trải nghiệm đăng xuất:** Khắc phục triệt để hiện tượng xoay vòng vô tận khi đăng xuất bằng việc lắng nghe luồng trạng thái `authStateChanges` qua `GoRouterRefreshStream`.
- **Lưu hồ sơ cá nhân:** Xử lý lỗi `[firebase_auth/internal-error]` khi cập nhật thông tin cá nhân trên một số thiết bị Android/iOS.
- **Tối ưu dung lượng:** Loại bỏ các thư viện tải ảnh đại diện không cần thiết, chuyển sang hiển thị chữ cái đại diện (Initials Avatar) theo bảng màu thương hiệu giúp ứng dụng nhẹ và mượt mà hơn.

---

## [1.0.0] - 16/08/2026

### ✨ Tính Năng Mới

#### 1. Đăng Nhập & Bảo Mật
- Hỗ trợ đăng nhập nhanh chóng bằng **Tài khoản Google** (`google_sign_in`).
- Hỗ trợ đăng nhập bảo mật bằng **Tài khoản Apple** (`sign_in_with_apple`).
- Đăng nhập và đăng ký bằng Email & Mật khẩu truyền thống qua Firebase Authentication.
- Thiết lập hồ sơ cá nhân lần đầu (Tên, Số điện thoại, Ngày sinh, Vai trò).

#### 2. Chấm Công & Điểm Danh Đa Kênh
- **Chấm công qua WiFi:** Xác thực tức thì thông qua thông tin SSID và BSSID của mạng WiFi cửa hàng.
- **Chấm công qua Vị trí (GPS):** Kiểm tra khoảng cách thực tế giữa thiết bị và tọa độ cửa hàng trong bán kính cho phép.
- **Chấm công qua Mã QR:** Quét mã QR động tại cửa hàng để điểm danh vào/ra ca làm việc.
- Hỗ trợ chỉnh sửa và bổ sung bảng công linh hoạt (chọn ngày và giờ vào/ra riêng biệt cho ca làm xuyên đêm).

#### 3. Quản Lý Ca Làm Việc & Lịch Tuần
- **Phân tab trực quan cho nhân viên:**
  - Tab *Đăng ký lịch làm:* Đăng ký nguyện vọng ca làm việc trong tuần tiếp theo.
  - Tab *Xem lịch cửa hàng:* Theo dõi ca làm đã được duyệt của toàn bộ thành viên trong cửa hàng.
- Hộp thông tin *Ca làm hôm nay* hiển thị ngay trên Dashboard kèm mã bộ phận / vị trí công việc.
- Modal chi tiết ca làm việc hiển thị danh sách nhân sự phụ trách và phân loại riêng biệt cho bộ phận Chờ / Giao hàng.
- Hỗ trợ chuyển đổi qua lại giữa các tuần trước đó để tra cứu lịch sử.

#### 4. Phân Quyền Doanh Nghiệp
- **Chủ cửa hàng (Owner):** Toàn quyền quản lý cửa hàng, cấu hình ca, duyệt nhân sự, duyệt tạm ứng và xem báo cáo tài chính.
- **Quản lý cấp 1 & Cấp 2 (Manager 1 & 2):** Quản lý ca làm việc, giám sát điểm danh và hỗ trợ vận hành hàng ngày.
- **Nhân viên (Employee):** Điểm danh, đăng ký ca, xem công làm và gửi yêu cầu tạm ứng lương.

#### 5. Bảng Lương & Tạm Ứng
- Tự động tính toán số công, giờ làm thực tế và tổng lương dự kiến theo ca.
- Quản lý quy trình yêu cầu tạm ứng lương và xét duyệt trực tiếp trên ứng dụng.
- Hỗ trợ xuất bảng chấm công và bảng lương chi tiết ra định dạng Excel (.xlsx).

#### 6. Thông Báo Tự Động (Push Notifications)
- Tích hợp Firebase Cloud Messaging (FCM) và thông báo nội bộ thiết bị.
- Thông báo duyệt ca làm việc, duyệt thành viên mới và duyệt tạm ứng lương.
- **Thông báo sinh nhật:** Tự động phát thông báo chúc mừng sinh nhật của thành viên đến toàn thể nhân sự trong cửa hàng.

---

## Liên Hệ & Hỗ Trợ
- **Tác giả:** Nguyễn Thanh Tâm
- **Email:** [nthanhtam.402@gmail.com](mailto:nthanhtam.402@gmail.com)
- **Kho mã nguồn:** [GitHub - 2312741-sudo/appchamcong](https://github.com/2312741-sudo/appchamcong)
- **Trang chủ & Chính sách:** [https://2312741-sudo.github.io/appchamcong/](https://2312741-sudo.github.io/appchamcong/)

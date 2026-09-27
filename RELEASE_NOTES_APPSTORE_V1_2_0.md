# 📱 TÀI LIỆU CẬP NHẬT PHÁT HÀNH APP STORE — v1.2.0 (Build 17)

> **Ứng dụng**: Chấm Công Trạm (Smart Attendance for F&B / Retail)  
> **Phiên bản mới**: `1.2.0`  
> **Số bản dựng (Build Number)**: `17`  
> **Bundle Identifier**: `com.chamcong.chamCongTram`  
> **Apple Team ID**: `W97CS7VC54`  
> **Ngày phát hành**: 28/09/2026  

---

## 1. THÔNG TIN ĐIỀN TRÊN APP STORE CONNECT

### 1.1. Phiên bản & Bản dựng
- **Version Number**: `1.2.0`
- **Build Number**: `17`

### 1.2. Có gì mới trong phiên bản này? (What's New in This Version - Tiếng Việt)
*Copy nguyên văn đoạn sau dán vào ô "What's New in This Version" trên App Store Connect:*

```text
Phiên bản 1.2.0 mang đến cuộc nâng cấp toàn diện về giao diện người dùng cùng nhiều cải tiến về độ ổn định:
- Nâng cấp toàn bộ thiết kế giao diện (UI/UX) mới: Hiện đại, trực quan, tối ưu trải nghiệm thao tác một chạm trên mọi kích thước màn hình.
- Đồng bộ bảng màu thương hiệu Trạm: Chuẩn hoá hệ thống màu sắc trên toàn bộ Dashboard Chủ quán, Quản lý và Nhân viên.
- Bảng màu lịch ca trực quan (Schedule Palette): Phân biệt rõ nét từng ca làm việc, hỗ trợ theo dõi và đăng ký ca làm nhanh chóng.
- Hệ thống nhắc ca làm việc thông minh tại máy: Nhắc nhở trước ca làm 15 phút chính xác 100% bằng chuông báo hệ điều hành, hoạt động mượt mà kể cả khi không có mạng.
- Tối ưu tốc độ tải và phản hồi tại màn hình Chấm công và Bảng chấm công chi nhánh.
```

### 1.3. Có gì mới trong phiên bản này? (What's New in This Version - English)
*Nếu tài khoản App Store Connect của bạn đang để ngôn ngữ chính là English (U.S.):*

```text
Version 1.2.0 delivers a complete user interface (UI/UX) redesign along with major performance and usability enhancements:
- Complete UI/UX Redesign: Modernized, streamlined interface tailored for smooth one-touch operations across all screen sizes.
- Unified Brand Theme: Cohesive visual styling and color palette across Store Owner, Manager, and Employee dashboards.
- Intuitive Schedule Palette: Visually distinct shift color-coding for effortless schedule tracking and registration.
- On-Device Smart Shift Reminders: Reliable 15-minute advance shift alerts powered by native notifications, working seamlessly even when offline.
- Performance & Responsiveness: Optimized data rendering and instant transitions on Check-in and Attendance logs.
```

### 1.4. Từ khóa tìm kiếm (Keywords)
```text
cham cong, cham cong tram, cham cong f&b, quan ly ca lam, bang cong, tinh luong, quan ly nhan vien, tram chanh, tram sua
```

### 1.5. Thông tin hỗ trợ (Support Information)
- **Support URL**: `https://chamcongtram.firebaseapp.com`
- **Privacy Policy URL**: `https://chamcongtram.firebaseapp.com/privacy`

---

## 2. GHI CHÚ XÉT DUYỆT GỬI APPLE (APP REVIEW NOTES - ENGLISH)
*Copy đoạn văn bản dưới đây dán vào ô "Review Notes" của App Store Connect:*

```text
Dear Apple App Review Team,

Thank you for reviewing the Cham Cong Tram (Chấm Công Trạm) update (Version 1.2.0, Build 17). 

This release introduces a major user interface redesign, refined brand palettes across dashboards, and on-device shift reminders for verified staff attendance.

1. Test Credentials:
• Role: Store Owner (Full Access)
• Email: [YOUR_TEST_EMAIL_HERE]
• Password: [YOUR_TEST_PASSWORD_HERE]

2. Hardware & Permission Explanations:
• Location (GPS): Required ONLY when tapping Check-in / Check-out to verify physical presence within the designated store radius.
• Push Notifications: Used for shift reminders, team announcements, and schedule updates.

3. Key Areas to Test in v1.2.0:
• Redesigned UI: Notice the updated theme, consistent card layouts, and refined navigation on Owner, Manager, and Employee dashboards.
• Schedule Palette: View weekly shift schedules with clear color-coded time ranges.
• Shift Reminders: Native on-device alerts scheduled 15 minutes before shift starts.

If you have any questions or require additional assistance, please reach out to us at nthanhtam.402@gmail.com.

Best regards,
Nguyen Thanh Tam
Developer of Cham Cong Tram
```

---

## 3. DANH SÁCH CHI TIẾT CÁC MÀN HÌNH NÂNG CẤP GIAO DIỆN (v1.2.0)

| Nhóm chức năng | Màn hình được tái thiết kế | Nội dung cải tiến |
| :--- | :--- | :--- |
| **Theme & Core UI** | `AppColors`, `AppTheme`, `SchedulePalette` | Chuẩn hóa toàn bộ hệ thống màu chủ đạo, màu phụ trợ và bảng màu nhận diện ca làm việc. |
| **Dashboards** | `EmployeeDashboard`, `ManagerDashboard`, `OwnerDashboard` | Thiết kế lại toàn bộ thẻ tổng quan, bố cục chỉ số chấm công, nút hành động nhanh và avatar trạng thái. |
| **Chấm công** | `CheckInScreen`, `ActiveStaffScreen`, `AttendanceTableScreen` | Giao diện định vị GPS & WiFi hiện đại, thẻ nhân sự đang làm việc trực quan, bảng công rõ ràng. |
| **Lịch làm việc** | `EmployeeScheduleTab`, `ScheduleManagerScreen`, `ScheduleRegisterScreen` | Áp dụng bảng màu `SchedulePalette` mới, phân tách thẻ ca sáng/chiều/tối/tăng cường rõ nét. |
| **Thông báo & Lương** | `NotificationsScreen`, `SalaryDetailScreen` | Thiết kế lại danh sách thông báo, thẻ chi tiết lương minh bạch và tối ưu phân cấp thị giác. |
| **Thành viên & Cài đặt** | `MembersListScreen`, `MemberDetailScreen`, `ProfileSettingsScreen` | Tối ưu danh sách nhân sự, thẻ phân quyền và thông tin cá nhân. |

---

## 4. HƯỚNG DẪN ARCHIVE XCODE & TẢI LÊN

1. Mở dự án trong Xcode:
   ```bash
   open "/Users/nthtam/Lưu trữ/app_cham_cong/cham_cong_tram/ios/Runner.xcworkspace"
   ```
2. Trong Xcode, chọn thiết bị đích: **Any iOS Device (arm64)**.
3. Bấm **Product** -> **Clean Build Folder** (`Cmd + Shift + K`).
4. Bấm **Product** -> **Archive**.
5. Trong cửa sổ **Organizer**, bản dựng sẽ hiển thị chuẩn xác **`1.2.0 (17)`**. Bấm **Distribute App** để tải lên App Store Connect.

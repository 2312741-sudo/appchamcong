# 🍎 APPLE APP STORE CONNECT — SUBMISSION PACKAGE & REVIEW NOTES
**Ứng dụng:** Chấm Công Trạm (`cham_cong_tram`)  
**Phiên bản (Version):** `1.0.3`  
**Mã bản dựng (Build):** `5` (`1.0.3+5`)  
**Ngày cập nhật:** 25/08/2026  

---

## 📋 PHẦN 1: BẢN CẬP NHẬT CÓ GÌ MỚI? (WHAT'S NEW IN THIS VERSION)
*(Sao chép nội dung này dán vào ô **What's New in This Version** trên App Store Connect)*

### 🇻🇳 Tiếng Việt (Khuyên dùng cho thị trường Việt Nam):
```text
Phiên bản 1.0.3 mang đến nhiều nâng cấp về hiệu năng và trải nghiệm quản trị:

• [TÍNH NĂNG MỚI] Cảnh báo đi muộn: Tự động đối chiếu thời gian check-in thực tế với lịch ca làm việc và hiển thị cảnh báo "Đi muộn X phút" / "Đi muộn XhYp" trực tiếp trên màn hình Tổng quan.
• Khắc phục hoàn toàn lỗi hiển thị ảnh đại diện (avatar), đồng bộ mượt mà giữa ứng dụng di động và web dashboard.
• Tối ưu hóa điều hướng Đăng xuất: Chuyển về màn hình đăng nhập chỉ với 1 lần chạm duy nhất.
• Nâng cấp hệ thống thông báo đẩy (FCM): Tự động dọn dẹp và phân luồng token trên thiết bị, khắc phục triệt để tình trạng trùng lặp thông báo.
• Tăng độ tương phản nút quay về trên màn hình Thông báo giúp thao tác dễ dàng hơn.
• Nâng cao tốc độ và độ ổn định tổng thể cho hệ thống quản lý ca làm và chấm công.
```

### 🇬🇧 English (Bản tiếng Anh chuẩn):
```text
Version 1.0.3 brings performance improvements and new smart management features:

• [NEW] Real-time Late Check-in Warning: Automatically compares actual check-in time against scheduled shifts and displays late duration badges ("Late 15 mins", "Late 1h20m") on the manager overview screen.
• Fixed user avatar sync and display between mobile app and web dashboard.
• Streamlined sign-out navigation with instant single-tap logout.
• Upgraded push notifications with automatic device token deduplication.
• Improved UI contrast for back navigation buttons on white app bars.
• General performance optimizations and bug fixes across attendance workflows.
```

---

## 🔐 PHẦN 2: THÔNG TIN DÀNH CHO APPLE REVIEW TEAM (APP REVIEW INFORMATION)
*(Sao chép nội dung này dán vào ô **App Review Notes / Review Information**)*

```text
Dear Apple Review Team,

Thank you for reviewing the "Chấm Công Trạm" app (v1.0.3). Below is all the necessary information and test account credentials to test the core features of the application.

1. DEMO TEST ACCOUNT CREDENTIALS:
--------------------------------------------------
Role: Store Owner & Manager (Full Access)
• Email: demo.owner@tramchanh.vn
• Password: Demo@123456
(Note: If testing as employee, you can also use: demo.staff@tramchanh.vn / Demo@123456)

Sign in with Apple and Google Sign-In are also fully integrated and supported.

2. KEY FEATURES & STEP-BY-STEP TESTING GUIDE:
--------------------------------------------------
a) Overview & Real-time Late Warning (New in v1.0.3):
- Log in using the demo account.
- On the Overview screen ("Tổng quan"), locate the "Nhân viên đang làm" (Working Employees) section.
- You can see active employees in shift along with real-time late warning badges (e.g., "Đi muộn 15 phút") if they checked in past their scheduled shift start time.

b) Weekly Shift Schedule Management:
- Navigate to "Quản lý lịch làm" / "Lịch làm việc" tab.
- View and manage weekly shifts for team members (Morning, Afternoon, Evening, Delivery).

c) QR Code Attendance & Check-in:
- Tap the QR Scanner / "Chấm công" icon to scan the store QR code for check-in / check-out.
- View real-time attendance history and monthly summary tables.

d) Sign-out & Profile:
- Open the side drawer or navigate to "Cài đặt" / "Hồ sơ cá nhân".
- Tap "Đăng xuất" (Sign out) to immediately return to the login screen with a single tap.
- Under Profile settings, users can also securely delete their account and personal data per Apple Guideline 5.1.1(v).

3. HARDWARE & PERMISSIONS USAGE (Guideline 5.1.1):
--------------------------------------------------
• Camera (NSCameraUsageDescription): Used solely to scan store QR codes for shift check-in and check-out.
• Location (NSLocationWhenInUseUsageDescription): Used only while checking in to verify that the employee is physically present within the store's designated geofence radius.
• Photo Library (NSPhotoLibraryUsageDescription): Used when the user chooses to upload a custom profile avatar photo.
• Notifications (User Notifications): Used to alert managers and employees about shift assignments, leave approvals, salary advances, and store announcements.

4. SUPPORT & POLICY URLS:
--------------------------------------------------
• Privacy Policy: https://2312741-sudo.github.io/appchamcong/privacy.html
• Account Deletion: https://2312741-sudo.github.io/appchamcong/delete-account.html
• Support URL: https://2312741-sudo.github.io/appchamcong/

Please feel free to reach out if you need any additional information.

Best regards,
Nguyen Thanh Tam - Development Team
Email: nthanhtam.402@gmail.com
```

---

## 📱 PHẦN 3: KIỂM TRA QUY ĐỊNH APP STORE (APP STORE GUIDELINES CHECKLIST)

| Quy định Apple (Guideline) | Trạng thái ứng dụng | Vị trí trong code |
| :--- | :---: | :--- |
| **Guideline 5.1.1(v) — Account Deletion** | ✅ Đạt | Có nút "Xóa tài khoản vĩnh viễn" trong Profile Settings + URL Web xoá tài khoản độc lập. |
| **Guideline 4.8 — Sign in with Apple** | ✅ Đạt | Đã tích hợp nút `Sign in with Apple` nổi bật tại Login & Register. |
| **Guideline 5.1.1 — Data Privacy & Permissions** | ✅ Đạt | Tất cả các quyền Camera, Location, Photo, Notification đều có chuỗi giải trình tiếng Việt & tiếng Anh rõ ràng trong `Info.plist`. |
| **Guideline 2.1 — App Completeness** | ✅ Đạt | 100% không có placeholder, 78/78 Unit tests PASS, không có crash khi đăng xuất hoặc mất mạng. |

# 📱 TÀI LIỆU CẬP NHẬT PHÁT HÀNH APP STORE — v1.1.3 (Build 18)

> **Ứng dụng**: Chấm Công Trạm (Smart Attendance for F&B / Retail)  
> **Phiên bản mới**: `1.1.3`  
> **Số bản dựng (Build Number)**: `18`  
> **Bundle Identifier**: `com.chamcong.chamCongTram`  
> **Apple Team ID**: `W97CS7VC54`  
> **Ngày phát hành**: 30/09/2026  

---

## 1. THÔNG TIN ĐIỀN TRÊN APP STORE CONNECT

### 1.1. Phiên bản & Bản dựng
- **Version Number**: `1.1.3`
- **Build Number**: `18`

### 1.2. Có gì mới trong phiên bản này? (What's New in This Version - Tiếng Việt)
*Copy nguyên văn đoạn sau dán vào ô "What's New in This Version" trên App Store Connect:*

```text
Phiên bản 1.1.3 mang đến các bản vá độ ổn định quan trọng và nâng cấp trải nghiệm:
- Tương thích hoàn toàn với iOS 27+: Khắc phục triệt để sự cố ứng dụng bị thoát đột ngột (crash) khi khởi động trên iOS 27.0.1+ thông qua việc áp dụng chuẩn kiến trúc UIScene lifecycle mới nhất từ Apple.
- Hoàn thiện toàn diện thiết kế giao diện (UI/UX) mới: Tối ưu hiển thị, trực quan hoá các thao tác một chạm trên mọi kích thước màn hình.
- Đồng bộ bảng màu thương hiệu Trạm & Lịch ca (Schedule Palette): Nhận diện ca làm việc rõ ràng, hỗ trợ theo dõi và đăng ký lịch làm việc dễ dàng hơn.
- Hệ thống nhắc ca làm việc thông minh tại máy: Chuông báo chính xác 15 phút trước ca làm ngay cả khi không có kết nối mạng.
- Tối ưu hiệu năng và tốc độ phản hồi trên toàn bộ hệ thống.
```

### 1.3. Có gì mới trong phiên bản này? (What's New in This Version - English)
*Nếu tài khoản App Store Connect của bạn đang để ngôn ngữ chính là English (U.S.):*

```text
Version 1.1.3 brings critical stability fixes and overall user experience improvements:
- Full iOS 27+ Compatibility: Resolves startup crash on iOS 27.0.1+ by adopting Apple's required UIScene lifecycle architecture.
- Modernized UI/UX Redesign: Streamlined interface optimized for smooth one-touch operations across all modern iOS displays.
- Unified Brand Theme & Schedule Palette: Intuitive shift color-coding for effortless schedule registration and tracking.
- On-Device Smart Shift Reminders: Reliable 15-minute advance shift alerts powered by native notifications, working seamlessly offline.
- Performance & Launch Optimization: Enhanced responsiveness and instant data rendering across dashboards.
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

Thank you for reviewing the Cham Cong Tram (Chấm Công Trạm) update (Version 1.1.3, Build 18). 

Key changes in this update:
1. iOS 27 Compatibility & Startup Crash Fix:
   - Successfully migrated to the required UIScene lifecycle architecture (`UIApplicationSceneManifest` & `FlutterSceneDelegate`).
   - Resolves startup crash (`NSInternalInconsistencyException`) experienced on iOS 27.0.1+ devices built with Xcode 27 SDK.
   - Updated iOS deployment target to 16.0.

2. Redesigned Visual Interface & Usability Enhancements:
   - Unified brand design system across Store Owner, Manager, and Employee dashboards.
   - Distinct shift color-coding with Schedule Palette for clear visibility.
   - Local on-device shift reminders scheduled 15 minutes before work begins.

Test Account Credentials:
• Role: Store Owner (Full Access)
• Email: [EMAIL_TEST_CỦA_BẠN]
• Password: [MẬT_KHẨU_TEST_CỦA_BẠN]

Hardware & Permission Explanations:
• Location (GPS): Required ONLY during Check-in / Check-out to verify physical store radius.
• Push Notifications: Used for shift reminders, team announcements, and schedule updates.

If you have any questions or require additional details, please contact us at nthanhtam.402@gmail.com.

Best regards,
Nguyen Thanh Tam
Developer of Cham Cong Tram
```

---

## 3. HƯỚNG DẪN ARCHIVE XCODE & TẢI LÊN APP STORE CONNECT

1. Mở dự án trong Xcode:
   ```bash
   open "/Users/nthtam/Lưu trữ/app_cham_cong/cham_cong_tram/ios/Runner.xcworkspace"
   ```
2. Trong Xcode, chọn thiết bị đích: **Any iOS Device (arm64)**.
3. Bấm **Product** -> **Clean Build Folder** (`Cmd + Shift + K`).
4. Bấm **Product** -> **Archive**.
5. Trong cửa sổ **Organizer**, bản dựng sẽ hiển thị chuẩn xác **`1.1.3 (18)`**. Bấm **Distribute App** để tải lên App Store Connect.

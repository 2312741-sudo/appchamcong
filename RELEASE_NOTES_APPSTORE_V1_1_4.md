# 📱 TÀI LIỆU CẬP NHẬT PHÁT HÀNH APP STORE — v1.1.4 (Build 19)

> **Ứng dụng**: Chấm Công Trạm (Smart Attendance for F&B / Retail)  
> **Phiên bản mới**: `1.1.4`  
> **Số bản dựng (Build Number)**: `19`  
> **Bundle Identifier**: `com.chamcong.chamCongTram`  
> **Apple Team ID**: `W97CS7VC54`  
> **Ngày phát hành**: 01/10/2026  

---

## 1. THÔNG TIN ĐIỀN TRÊN APP STORE CONNECT

### 1.1. Phiên bản & Bản dựng
- **Version Number**: `1.1.4`
- **Build Number**: `19`

### 1.2. Có gì mới trong phiên bản này? (What's New in This Version - Tiếng Việt)
*Copy nguyên văn đoạn sau dán vào ô "What's New in This Version" trên App Store Connect:*

```text
Phiên bản 1.1.4 mang đến bản nâng cấp tối ưu hiệu năng và độ ổn định cao nhất:
- Nâng cấp độ ổn định khởi động: Khắc phục triệt để hiện tượng gián đoạn màn hình khi mở ứng dụng trên các phiên bản iOS mới, đảm bảo trải nghiệm mở app mượt mà và tức thì.
- Giao diện người dùng mới (UI/UX) hoàn thiện: Trực quan, hiện đại, tối ưu thao tác chấm công một chạm tiện lợi.
- Đồng bộ bảng màu thương hiệu & Bảng lịch ca (Schedule Palette): Nhận diện ca làm việc rõ ràng, hỗ trợ theo dõi và đăng ký lịch làm việc dễ dàng hơn.
- Hệ thống nhắc ca làm việc thông minh tại máy: Chuông báo chính xác 15 phút trước ca làm ngay cả khi không có kết nối mạng.
- Tối ưu hóa hiệu năng render đồ họa Metal Impeller: Cuộn lướt danh sách chấm công và bảng lương êm mượt hơn.
```

### 1.3. Có gì mới trong phiên bản này? (What's New in This Version - English)
*Nếu tài khoản App Store Connect của bạn đang để ngôn ngữ chính là English (U.S.):*

```text
Version 1.1.4 brings major performance optimizations, UI enhancements, and rock-solid stability:
- Startup Stability & Fixes: Resolved launch delays and display issues on latest iOS versions, ensuring instant, seamless app opening.
- Modernized UI/UX Redesign: Streamlined interface tailored for effortless one-touch check-ins and operations.
- Unified Brand Palette & Schedule View: Intuitive shift color-coding for rapid shift tracking and weekly schedule registration.
- On-Device Smart Shift Reminders: Reliable 15-minute advance alerts powered by native notifications, working seamlessly even when offline.
- Metal Impeller Rendering Optimization: Ultra-smooth scrolling and responsive transitions across attendance logs and payroll reports.
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

Thank you for reviewing the Cham Cong Tram (Chấm Công Trạm) update (Version 1.1.4, Build 19). 

Key Highlights of this Version:
1. Stability & Launch Improvements:
   - Optimized application launch sequence and lifecycle event handling for the latest iOS versions.
   - Enhanced rendering responsiveness with Metal Impeller backend.

2. Redesigned UI & Feature Highlights:
   - Modernized interface across Store Owner, Manager, and Employee dashboards.
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
5. Trong cửa sổ **Organizer**, bản dựng sẽ hiển thị chuẩn xác **`1.1.4 (19)`**. Bấm **Distribute App** để tải lên App Store Connect.

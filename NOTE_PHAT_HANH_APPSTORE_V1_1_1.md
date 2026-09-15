# 📱 TÀI LIỆU HƯỚNG DẪN PHÁT HÀNH APP STORE — CHẤM CÔNG TRẠM v1.1.1

> **Ứng dụng**: Chấm Công Trạm (Smart Attendance for F&B / Retail)  
> **Phiên bản (Version)**: `1.1.1`  
> **Số bản dựng (Build Number)**: `16`  
> **Bundle Identifier**: `com.chamcong.chamCongTram`  
> **Apple Team ID**: `W97CS7VC54`  
> **Ngày chuẩn bị**: 16/09/2026  

---

## 1. THÔNG TIN ĐIỀN TRÊN APP STORE CONNECT

### 1.1. Phiên bản & Bản dựng
- **Version Number**: `1.1.1`
- **Build**: `16`

### 1.2. Có gì mới trong phiên bản này? (What's New in This Version)
*Copy nguyên văn đoạn sau vào ô "What's New" trên App Store Connect:*

```text
Phiên bản 1.1.1 mang đến diện mạo mới cùng nhiều cải tiến về trải nghiệm, phân quyền và độ ổn định:
- Cập nhật biểu tượng và nhận diện thương hiệu Trạm mới hiện đại, đồng bộ.
- Nâng cấp hệ thống Thông báo: hiển thị tức thì, hỗ trợ đầy đủ các vai trò (Chủ, Quản lý 1, Quản lý 2, Nhân viên).
- Bổ sung tính năng đánh dấu đã đọc một chạm ("Đã đọc tất cả").
- Khắc phục lỗi khi hủy yêu cầu tham gia cửa hàng ở màn hình chờ duyệt.
- Hỗ trợ nhân sự nộp lại đơn tham gia thuận tiện sau khi được quản lý mời lại.
- Bổ sung quyền theo dõi bảng công cho Quản lý 2 để kiểm soát chính xác phụ cấp ca trực.
- Nâng cao tính bảo mật dữ liệu và tối ưu tốc độ đồng bộ thời gian thực.
```

### 1.3. Từ khóa tìm kiếm (Keywords)
```text
cham cong, cham cong tram, cham cong f&b, quan ly ca lam, bang cong, tinh luong, quan ly nhan vien, tram chanh, tram sua
```

### 1.4. Thông tin liên hệ hỗ trợ (Support Information)
- **URL hỗ trợ (Support URL)**: `https://chamcongtram.firebaseapp.com`
- **Chính sách quyền riêng tư (Privacy Policy URL)**: `https://chamcongtram.firebaseapp.com/privacy`

---

## 2. DANH SÁCH CẢI TIẾN & BẢN VÁ TRONG BẢN 1.1.1

| STT | Khu vực | Mô tả thay đổi | Giá trị mang lại |
| :---: | :--- | :--- | :--- |
| 1 | **Brand Identity** | Thay bộ App Icon mới độ phân giải cao cho iOS & Android | Đồng bộ nhận diện thương hiệu chuỗi F&B Trạm |
| 2 | **Hệ thống Thông báo** | Sửa triệt để race condition và phân quyền đọc/ghi thông báo cho QL2 và Nhân viên | Thông báo hiển thị tức thì, badge chuẩn xác, hỗ trợ "Đã đọc tất cả" mượt mà |
| 3 | **Store Membership** | Bổ sung hàm `cancelJoinRequest` và sửa quyền hủy yêu cầu tham gia | Thành viên có thể tự rút đơn chờ duyệt mà không bị lỗi 403 Forbidden |
| 4 | **Store Membership** | Cho phép thành viên từng bị kick nộp lại đơn | Khắc phục lỗi chặn đăng ký lại khi nhân sự quay trở lại làm việc |
| 5 | **RBAC / Phân quyền** | Cấp quyền đọc bảng công `attendances` cho Quản lý 2 | Quản lý 2 theo dõi được ca trực để giám sát phụ cấp giao hàng |
| 6 | **Bảo mật & Rules** | Nâng cấp toàn diện bộ Firestore Security Rules (270 dòng) | Bảo vệ tuyệt đối bảng lương cơ bản, phân quyền đa tầng an toàn |
| 7 | **Audit Dữ liệu** | Dọn dẹp rác Firestore, bổ sung Collection Group Index `members.userId` | Tối ưu hiệu năng đồng bộ dữ liệu đa chi nhánh |

---

## 3. THÔNG TIN PHỤC VỤ APPLE APP REVIEW (NẾU ĐƯỢC HỎI)

Nếu đội ngũ Apple Review yêu cầu tài khoản demo để kiểm thử các tính năng phân quyền:
- **Tài khoản Test (Chủ quán demo)**:
  - Email: *(Dùng tài khoản test của bạn hoặc Apple Review Account đã cấu hình)*
- **Ghi chú cho Reviewer (Review Notes)**:
  ```text
  Ứng dụng Chấm Công Trạm hỗ trợ chấm công bằng định vị GPS và WiFi tại cơ sở làm việc, quản lý lịch làm việc và bảng lương cho chuỗi cửa hàng. Vui lòng cấp quyền Định vị (Location) và Thông báo (Push Notification) khi được yêu cầu để trải nghiệm đầy đủ các tính năng chấm công và nhận thông báo ca làm.
  ```

---

## 4. HƯỚNG DẪN BUILD & UPLOAD LÊN APP STORE CONNECT

### Cách 1: Tự động Build bằng Terminal (Khuyến nghị)
Chạy lần lượt các lệnh sau tại thư mục dự án:
```bash
cd "/Users/nthtam/Lưu trữ/app_cham_cong/cham_cong_tram"
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release
```

Sau khi lệnh chạy xong thành công:
- File IPA hoàn chỉnh sẽ nằm tại:  
  📁 `build/ios/ipa/cham_cong_tram.ipa`

### Cách 2: Upload bằng Transporter
1. Mở ứng dụng **Transporter** trên máy Mac.
2. Đăng nhập tài khoản Apple Developer (`W97CS7VC54`).
3. Kéo thả file `cham_cong_tram.ipa` vào Transporter và bấm **Deliver**.
4. Chờ 5 - 10 phút để Apple xử lý bản dựng, sau đó vào App Store Connect chọn Build `15` và bấm **Submit for Review**.

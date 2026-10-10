# 📱 TÀI LIỆU PHÁT HÀNH APP STORE & GOOGLE PLAY — CHẤM CÔNG TRẠM v1.1.6

> **Ứng dụng:** Chấm Công Trạm (Hệ sinh thái chấm công & quản trị nhân sự thông minh)  
> **Phiên bản (Version):** `1.1.6`  
> **Số bản dựng (Build Number):** `23`  
> **Bundle Identifier (iOS):** `com.chamcong.chamCongTram`  
> **Package Name (Android):** `com.chamcong.chamCongTram`  
> **Apple Team ID:** `W97CS7VC54`  
> **Ngày chuẩn bị phát hành:** 11/10/2026  
> **Nền tảng hỗ trợ:** iOS, Android, Web Dashboard (Next.js)  

---

## 1. THÔNG TIN ĐIỀN TRÊN APP STORE CONNECT & GOOGLE PLAY CONSOLE

### 1.1. Số phiên bản & Bản dựng
- **Version Number:** `1.1.6`
- **Build Number:** `23`
- **Tên phiên bản phát hành:** `v1.1.6 - Ra Ca Linh Hoạt & Điều Hướng Công Việc Thông Minh`

---

### 1.2. Có gì mới trong phiên bản này? (What's New in This Version)

#### Tiếng Việt (Dành cho App Store Connect & Google Play Console):
```text
Phiên bản 1.1.6 mang đến trải nghiệm làm việc mượt mà và linh hoạt hơn cho nhân viên và cấp quản lý:
- 🚪 Ra ca linh hoạt, không bị chặn: Nhân sự có thể kết thúc ca làm việc (out ca) bình thường ngay cả khi chưa hoàn thành hết việc được giao. Bảng nhắc việc cho phép xác nhận ra ca chỉ với 1 chạm.
- ⏰ Hoàn thành công việc bất cứ lúc nào: Nhân viên có thể nộp báo cáo văn bản và đính kèm ảnh minh chứng trước ca, trong ca, sau khi ra ca hoặc những ngày tiếp theo.
- 📅 Thanh điều hướng ngày thông minh trên Dashboard: Dễ dàng chuyển đổi giữa các ngày (Hôm qua, Hôm nay, Ngày mai) hoặc mở Lịch chọn ngày bất kỳ để xem và nộp bổ sung báo cáo công việc các ngày trước.
- 🎨 Khắc phục hoàn toàn lỗi giao diện: Tinh chỉnh bố cục danh sách việc, chống tràn chữ và chống chồng đè giao diện trên mọi kích cỡ màn hình.
- ⌨️ Thao tác tiện lợi: Cho phép chạm vùng trống hoặc vuốt cuộn màn hình để ẩn bàn phím ảo nhanh chóng trên toàn bộ ứng dụng.
- 🌐 Đồng bộ toàn diện trên Web Dashboard: Cập nhật cơ chế ra ca linh hoạt và quản lý công việc trên nền tảng Web.
- ⚡ Tối ưu hiệu năng, giảm thời gian tải và nâng cao độ ổn định tổng thể.
```

#### English (For English Storefronts):
```text
Version 1.1.6 improves shift workflow flexibility and task management:
- 🚪 Flexible Shift Check-Out: Employees can now check out seamlessly without being blocked by unfinished tasks. A friendly 1-tap confirmation allows checking out and completing tasks later.
- ⏰ Complete Tasks Anytime: Submit task notes and photo evidence at your convenience—during shift, after check-out, or on subsequent days.
- 📅 Smart Date Navigation on Dashboard: Easily navigate between Yesterday, Today, Tomorrow, or pick any past date to view and complete pending tasks.
- 🎨 UI & Layout Improvements: Resolved card text clipping and overlapping elements across various screen sizes.
- ⌨️ Global Keyboard Dismissal: Tap outside or drag to dismiss the soft keyboard across all screens.
- 🌐 Seamless Web Dashboard Sync: Synchronized flexible check-out and date navigation with the Web portal.
- ⚡ General stability and performance optimizations.
```

---

### 1.3. Từ khóa tìm kiếm (Keywords)
```text
cham cong, cham cong tram, giao viec, bao cao cong viec, quan ly ca lam, bang cong, tinh luong, diem danh, nhan su f&b, tram chanh, tram sua
```

---

### 1.4. Thông tin liên hệ & Hỗ trợ (Support Information)
- **URL hỗ trợ (Support URL):** `https://chamcongtram.firebaseapp.com`
- **Chính sách quyền riêng tư (Privacy Policy URL):** `https://chamcongtram.firebaseapp.com/privacy`
- **Web Portal:** `https://webquanlychamcong.vercel.app`
- **Email hỗ trợ:** `nthanhtam.402@gmail.com`

---

## 2. CHI TIẾT CÁC TÍNH NĂNG NÂNG CẤP TRONG BẢN 1.1.6

| STT | Phân hệ | Tính năng / Cải tiến | Mô tả chi tiết kỹ thuật & Nghiệp vụ |
| :---: | :--- | :--- | :--- |
| **1** | **Ra ca (Check-out Flow)** | Cơ chế ra ca linh hoạt (Non-blocking) | Thay thế cơ chế chặn cứng nhắc trước đây. Khi người dùng bấm "Chấm ra", nếu còn việc dở dang, app hiển thị modal nhắc việc kèm thời gian làm việc ca hiện tại và nút **"Xác nhận ra ca (Hoàn thành sau)"** để ra ca ngay chỉ với 1 chạm. |
| **2** | **Báo cáo (Task Completion)** | Hoàn thành việc bất cứ lúc nào | Không giới hạn việc hoàn thành trong khung giờ ca làm. Nhân sự có thể mở app ở bất kỳ đâu (sau khi ra ca, ở nhà, hoặc ngày hôm sau) để viết báo cáo, đính kèm ảnh và bấm "Hoàn thành công việc". |
| **3** | **Dashboard nhân viên** | Thanh điều hướng ngày thông minh | Nâng cấp widget `ShiftTasksCard` thành Stateful với bộ điều khiển ngày: mũi tên chuyển ngày `<` (Hôm qua), `>` (Ngày mai), Dropdown DatePicker chọn ngày bất kỳ, và nút "Về hôm nay". Nhân viên dễ dàng tra cứu và nộp bù báo cáo các ngày trước. |
| **4** | **Giao diện (UI Overlap Fix)** | Tinh chỉnh hiển thị thẻ việc | Tách biệt cấu trúc dọc hiển thị tiêu đề, tên người giao có text-ellipsis và huy hiệu "Cần ảnh chụp", bảo đảm không bao giờ chồng đè lên nút "Báo cáo" màu đỏ ngay cả với tên người giao rất dài. |
| **5** | **Trải nghiệm phím (Keyboard UX)** | Ẩn bàn phím toàn cục | Thiết lập `GestureDetector` xuyên thấu (`HitTestBehavior.translucent`) và bộ lắng nghe cuộn trang (`ScrollUpdateNotification`) tại gốc ứng dụng (`app.dart`) cùng thuộc tính `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`. |
| **6** | **Cổng Web Portal** | Đồng bộ Check-out & Giao việc Web | Cập nhật trang `/dashboard/checkin` trên Next.js bổ sung nút "Xác nhận ra ca (Hoàn thành sau)" kèm hiển thị thời gian làm việc. Đồng bộ tab "Việc của tôi trong ca" tại `/dashboard/tasks`. |
| **7** | **Kiểm thử & Chất lượng** | Bảo toàn 100% kiểm thử tự động | Toàn bộ **171/171 Unit & Widget tests** đều đạt (Green 100%), `dart analyze` không có lỗi. `next build` biên dịch thành công toàn bộ 21 static routes. |

---

## 3. THÔNG TIN PHỤC VỤ APPLE & GOOGLE REVIEW

Nếu đội ngũ App Review yêu cầu kiểm thử tính năng Giao việc & Báo cáo trong ca:
- **Ghi chú dành cho Reviewer (Review Notes):**
  ```text
  Ứng dụng Chấm Công Trạm hỗ trợ chấm công bằng định vị GPS/WiFi, quản lý ca làm việc và giao việc trong ca (Shift Tasks) kèm hình ảnh minh chứng.
  - Vui lòng cấp quyền Định vị (Location) để thực hiện chấm công vào/ra ca.
  - Vui lòng cấp quyền Camera/Thư viện ảnh (Photo Library) để đính kèm hình ảnh minh chứng khi nộp báo cáo công việc.
  - Nhân viên có thể linh hoạt ra ca và hoàn thành báo cáo công việc được giao bất kỳ lúc nào.
  ```

---

## 4. HƯỚNG DẪN BUILD & PHÁT HÀNH BẢN 1.1.6

### 4.1. Build Ứng Dụng Mobile (Flutter)

#### A. Build iOS (IPA để upload App Store Connect)
```bash
cd "/Users/nthtam/Lưu trữ/app_cham_cong/cham_cong_tram"
flutter clean
flutter pub get
flutter build ios --config-only
```
Sau đó mở Xcode:
1. Mở file workspace: `ios/Runner.xcworkspace`.
2. Chọn menu **Product > Clean Build Folder** (`Cmd + Shift + K`).
3. Chọn thiết bị đích: **Any iOS Device (arm64)**.
4. Chọn menu **Product > Archive**.
5. Khi cửa sổ **Organizer** hiện lên, kiểm tra thông tin hiển thị chính xác:
   - **Version:** `1.1.6`
   - **Build:** `23`
6. Nhấn **Distribute App** -> **App Store Connect** -> **Upload** để đưa bản build lên TestFlight / App Store.

#### B. Build Android (AAB để upload Google Play Console)
```bash
cd "/Users/nthtam/Lưu trữ/app_cham_cong/cham_cong_tram"
flutter build appbundle --release
# File xuất ra tại: build/app/outputs/bundle/release/app-release.aab
```

---

### 4.2. Deploy Web Dashboard (Next.js)
```bash
cd "/Users/nthtam/Lưu trữ/app_cham_cong/cham_cong_web"
npm run build
# Deploy tự động qua Vercel Git Integration hoặc:
# vercel --prod
```

---

## 5. CẤU HÌNH IN-APP FORCE UPDATE (NẾU ÁP DỤNG)
Cấu hình JSON khuyến nghị trên Firebase Remote Config hoặc Firestore:
```json
{
  "min_required_version": "1.1.0",
  "latest_version": "1.1.6",
  "latest_build_number": 23,
  "force_update": false,
  "update_title": "Phiên bản mới 1.1.6 đã sẵn sàng!",
  "update_message": "Cập nhật tính năng ra ca linh hoạt và điều hướng công việc thông minh theo ngày.",
  "ios_store_url": "https://apps.apple.com/app/id6749372134",
  "android_store_url": "https://play.google.com/store/apps/details?id=com.chamcong.chamCongTram"
}
```

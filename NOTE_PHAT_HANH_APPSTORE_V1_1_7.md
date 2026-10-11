# 📱 TÀI LIỆU PHÁT HÀNH APP STORE & GOOGLE PLAY — CHẤM CÔNG TRẠM v1.1.7

> **Ứng dụng:** Chấm Công Trạm (Hệ sinh thái chấm công & quản trị nhân sự thông minh)  
> **Phiên bản (Version):** `1.1.7`  
> **Số bản dựng (Build Number):** `24`  
> **Bundle Identifier (iOS):** `com.chamcong.chamCongTram`  
> **Package Name (Android):** `com.chamcong.chamCongTram`  
> **Apple Team ID:** `W97CS7VC54`  
> **Ngày chuẩn bị phát hành:** 12/10/2026  
> **Nền tảng hỗ trợ:** iOS, Android, Web Dashboard (Next.js)  

---

## 1. THÔNG TIN ĐIỀN TRÊN APP STORE CONNECT & GOOGLE PLAY CONSOLE

### 1.1. Số phiên bản & Bản dựng
- **Version Number:** `1.1.7`
- **Build Number:** `24`
- **Tên phiên bản phát hành:** `v1.1.7 - Chia Việc Theo Bộ Phận, Chụp Ảnh Trực Tiếp & Lặp Hằng Ngày`

---

### 1.2. Có gì mới trong phiên bản này? (What's New in This Version)

#### Tiếng Việt (Dành cho App Store Connect & Google Play Console):
```text
Phiên bản 1.1.7 nâng cấp toàn diện phân hệ Giao việc & Quản trị nhiệm vụ trong ca:
- 🏢 Chia việc theo bộ phận: Chủ quán và Quản lý có thể giao việc trực tiếp cho từng bộ phận (Pha chế, Thu ngân, Phục vụ, Bếp...). Nhân sự thuộc bộ phận nào sẽ tự động nhận đúng việc của bộ phận đó khi vào ca.
- 🔒 Khóa chọn ảnh từ thư viện - Xác thực chụp trực tiếp: Khi báo cáo hoàn thành công việc, ứng dụng khóa tính năng chọn ảnh cũ từ album và yêu cầu chụp ảnh trực tiếp từ camera tại đúng thời điểm hoàn thành để đảm bảo tính xác thực minh bạch.
- 🔁 Chế độ công việc Lặp mỗi ngày: Thiết lập công việc lặp lại định kỳ mỗi ngày chỉ với 1 chạm. Hệ thống tự động kích hoạt nhiệm vụ cho mọi ca làm việc hàng ngày mà không cần quản lý phải tạo lại.
- 🏷️ Huy hiệu & Phân loại trực quan: Bổ sung huy hiệu nhận diện "Theo bộ phận" và "Lặp mỗi ngày" trên toàn bộ thẻ công việc ngoài ca, màn hình chi tiết và danh sách quản trị.
- 🌐 Đồng bộ toàn diện trên Web Dashboard: Cập nhật đầy đủ tính năng chia việc bộ phận, khóa thư viện và lặp mỗi ngày trên Cổng quản trị Web.
- ⚡ Tối ưu hóa hiệu năng, bảo đảm 100% kiểm thử tự động đạt chuẩn.
```

#### English (For English Storefronts):
```text
Version 1.1.7 brings major enhancements to task assignment and shift duty verification:
- 🏢 Department-Based Task Assignment: Store owners and managers can now assign tasks directly to specific departments (Baristas, Cashiers, Service, Kitchen, etc.). Shift workers automatically receive duties tailored to their assigned department.
- 🔒 Direct Camera Photo Verification: Locked photo gallery selection when submitting task reports. Employees must capture photos directly via camera in real time, ensuring authenticity and transparency.
- 🔁 Daily Recurring Tasks: Easily set repetitive daily tasks with a single toggle. Tasks are automatically scheduled across daily shifts without repetitive manual input.
- 🏷️ Visual Badges & Department Labels: Added clear "Department" and "Daily Recurring" badges on shift cards, task lists, and detailed submission screens.
- 🌐 Full Web Dashboard Sync: Synchronized department task routing, camera-only proof, and recurring schedules across the Web management portal.
- ⚡ Performance optimizations and enhanced system stability.
```

---

### 1.3. Văn bản quảng bá (Promotional Text - Tối đa 170 ký tự)
```text
Chấm Công Trạm v1.1.7: Giao việc thông minh theo bộ phận, khóa ảnh thư viện bắt buộc chụp trực tiếp xác thực và tự động lặp việc mỗi ngày!
```

---

### 1.4. Từ khóa tìm kiếm (Keywords - Tối đa 100 ký tự)
```text
cham cong,cham cong tram,giao viec,theo bo phan,chup anh xac thuc,lap moi ngay,ca lam,bang cong,tinh luong
```

---

### 1.5. Thông tin liên hệ & Hỗ trợ (Support Information)
- **URL hỗ trợ (Support URL):** `https://chamcongtram.firebaseapp.com`
- **Chính sách quyền riêng tư (Privacy Policy URL):** `https://chamcongtram.firebaseapp.com/privacy`
- **Cổng Quản Trị Web (Web Portal):** `https://webquanlychamcong.vercel.app`
- **Email hỗ trợ kỹ thuật:** `nthanhtam.402@gmail.com`

---

## 2. CHI TIẾT CÁC TÍNH NĂNG NÂNG CẤP TRONG BẢN 1.1.7

| STT | Phân hệ | Tính năng / Cải tiến | Mô tả chi tiết kỹ thuật & Nghiệp vụ |
| :---: | :--- | :--- | :--- |
| **1** | **Giao việc (Task Assignment)** | Chia việc theo bộ phận (`department`) | Hỗ trợ enum `TaskTargetType.department`. Hộp thoại tạo việc hiển thị danh sách phòng ban từ `currentStore.departments` kèm số lượng nhân sự và avatar. `isApplicableForUserOnDate` tự động khớp theo `userDepartment` của nhân sự trong ca. |
| **2** | **Báo cáo (Task Reporting)** | Khóa thư viện, bắt buộc chụp Camera | Loại bỏ lựa chọn tải từ thư viện ảnh (`ImageSource.gallery`). Thay thế bằng nút duy nhất chụp trực tiếp từ Camera (`ImageSource.camera`). Bổ sung banner cảnh báo bảo mật cam kết tính xác thực minh chứng. |
| **3** | **Lập lịch (Task Scheduling)** | Chế độ Lặp mỗi ngày (`repeatDaily`) | Cung cấp Switch "Lặp mỗi ngày". Khi kích hoạt, hệ thống tự động sinh 60 ngày liên tục vào `executionDates` để đảm bảo tương thích 100% với truy vấn `arrayContains` của Firestore và logic kiểm tra hoàn thành khi ra ca. |
| **4** | **Trực quan hóa (UI/UX)** | Huy hiệu & Hiển thị thông minh | Gắn badge `🏢 Bộ phận: [Tên]` và `🔁 Lặp mỗi ngày` trên thẻ ca làm việc (`ShiftTasksCard`), màn hình chi tiết (`TaskDetailScreen`) và danh sách quản trị (`TaskManagementScreen`). Lịch trình hiển thị thông minh dạng "Tự động lặp lại mỗi ngày". |
| **5** | **Cổng Web Portal** | Đồng bộ toàn diện trên Web Next.js | Cập nhật form tạo việc với radio "Theo bộ phận" & dropdown bộ phận, checkbox "Lặp mỗi ngày" tự động sinh 60 ngày, input file đính kèm `capture="environment"` khóa thư viện và bộ lọc nhân viên theo bộ phận tại `TaskSubmissionsModal`. |
| **6** | **Kiểm thử chất lượng** | 100% Unit Tests & Build Verification | Bộ test `test/task_assignment_test.dart` đạt **22/22 tests PASS** (bổ sung test Group 6 về Department và Group 7 về repeatDaily). `dart analyze` sạch 0 lỗi. Web Next.js `npm run build` biên dịch thành công 21 static routes. |

---

## 3. THÔNG TIN PHỤC VỤ APPLE & GOOGLE REVIEW

Nếu đội ngũ App Review yêu cầu kiểm thử tính năng Giao việc & Báo cáo:
- **Ghi chú dành cho Reviewer (App Review Notes):**
  ```text
  Ứng dụng Chấm Công Trạm cung cấp giải pháp chấm công định vị (GPS/Wi-Fi) và giao việc trong ca làm việc.
  - Vui lòng cấp quyền Camera để thực hiện tính năng chụp ảnh minh chứng hoàn thành công việc trực tiếp tại thời điểm làm việc.
  - Vui lòng cấp quyền Vị trí (Location) khi thực hiện vào/ra ca làm việc.
  - Quản lý có thể giao việc cho toàn bộ cửa hàng, theo từng bộ phận (Pha chế, Thu ngân, v.v.), hoặc cá nhân và thiết lập lặp lại mỗi ngày.
  ```

---

## 4. HƯỚNG DẪN BUILD & PHÁT HÀNH BẢN 1.1.7

### 4.1. Build Ứng Dụng Mobile (Flutter)

#### A. Build iOS (IPA để upload App Store Connect)
```bash
cd "/Users/nthtam/Lưu trữ/app_cham_cong/cham_cong_tram"
flutter clean
flutter pub get
flutter build ipa --release
```
*Sau khi build xong, mở file `.xcarchive` trong Xcode Organizer để Validate và Distribute lên App Store Connect.*

#### B. Build Android (AAB để upload Google Play Console)
```bash
cd "/Users/nthtam/Lưu trữ/app_cham_cong/cham_cong_tram"
flutter clean
flutter pub get
flutter build appbundle --release
```
*File đầu ra:* `build/app/outputs/bundle/release/app-release.aab`

---

### 4.2. Build & Deploy Web Dashboard (Next.js)
```bash
cd "/Users/nthtam/Lưu trữ/app_cham_cong/cham_cong_web"
npm run build
```
*Sau khi test thành công, deploy lên Vercel production:*
```bash
npx vercel --prod
```

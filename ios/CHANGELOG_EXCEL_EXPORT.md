# Nhật ký sửa đổi - Fix chức năng xuất Excel & Lưu ý Xcode/iOS (15/08/2026)

Tài liệu này ghi lại các thay đổi đã thực hiện trong dự án và các lưu ý khi mở/build trên Xcode ở máy khác.

---

## 1. Chi tiết các thay đổi xuất file Excel (Bảng công, Lương, Lịch làm)

1. **Định dạng giờ công thành dạng số (Numeric)**
   - **Tình trạng cũ**: Các ô chứa giờ công (ví dụ: `"4.7h"`) và các ô trống (`"-"`, `"0h"`) bị Excel hiểu là văn bản (text), do đó không thể sử dụng các hàm tính toán cơ bản như `SUM`, `AVERAGE`.
   - **Giải pháp**: 
     - Chuyển đổi dữ liệu xuất sang `DoubleCellValue` cho số thập phân và `IntCellValue` cho số nguyên.
     - Dữ liệu giờ công, lương cơ bản, phụ cấp, tạm ứng, lương thực nhận đều đã được chuyển thành số để Excel tính toán được.

2. **Sửa lỗi hiển thị `0,00` khi không có ca làm**
   - **Tình trạng cũ**: Trong file Lịch làm và Bảng công, khi nhân viên không có ca làm, hệ thống hiển thị `"0h"` hoặc `"0,00"`.
   - **Giải pháp**: Ghi đè giá trị mặc định bằng `IntCellValue(0)` (số 0 tròn trĩnh) khi tổng số giờ hoặc ca làm bằng 0.

3. **Cải thiện tên file xuất ra (Descriptive File Naming)**
   - **Tình trạng cũ**: Tên file chung chung (ví dụ: `BangCong_2025-08.xlsx`, `BaoCaoLuong_Filter.xlsx`).
   - **Giải pháp**: Định dạng lại tên file đầy đủ bao gồm: `[Loại báo cáo]_[Tên cửa hàng]_[Thời gian]_[Tên nhân viên (nếu có)].xlsx`.
   - Tự động bỏ dấu tiếng Việt, thay khoảng trắng bằng dấu `_` và xóa ký tự đặc biệt.
   - **Ví dụ tên file mới**: 
     - `BangCong_QuanCaPhe_T08-2025.xlsx`
     - `BaoCaoLuong_QuanCaPhe_T08-2025_NguyenVanA.xlsx`
     - `LichLam_QuanCaPhe_Tuan_11.08-17.08.2025.xlsx`

### Các file Dart đã chỉnh sửa:
- `lib/core/utils/excel_export_service.dart`
- `lib/core/utils/export_utils.dart`
- `lib/features/attendance/screens/attendance_table_screen.dart`
- `lib/features/salary/screens/salary_overview_screen.dart`
- `lib/features/schedule/screens/schedule_manager_screen.dart`

---

## 2. Hướng dẫn khi chuyển sang máy Mac khác & mở Xcode

Khi clone / pull code sang máy mới:
1. Chạy lệnh cài đặt thư viện Flutter:
   ```bash
   flutter pub get
   ```
2. Chuyển vào thư mục `ios` và cài đặt Pods:
   ```bash
   cd ios
   pod install
   ```
3. Mở dự án trong Xcode:
   - Luôn mở file **`ios/Runner.xcworkspace`** (KHÔNG mở `Runner.xcodeproj`).
4. Cấu hình Signing & Capabilities trong Xcode:
   - Chọn target **Runner** > tab **Signing & Capabilities**.
   - Chọn **Team** phát triển Apple Developer của bạn để ký chứng chỉ build lên thiết bị thật.

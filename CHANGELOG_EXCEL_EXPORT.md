# Nhật ký sửa đổi - Fix chức năng xuất Excel (15/08/2026)

Tài liệu này ghi lại các thay đổi đã thực hiện để khắc phục các vấn đề liên quan đến tính năng xuất Excel. 
File này được lưu lại để tham khảo khi làm việc trên thiết bị khác.

## 1. Tổng quan thay đổi

Đã giải quyết 3 vấn đề chính trong chức năng xuất file Excel (Bảng công, Báo cáo lương, Lịch làm):

1. **Định dạng giờ công thành dạng số (Numeric)**
   - **Tình trạng cũ**: Các ô chứa giờ công (ví dụ: `"4.7h"`) và các ô trống (`"-"`, `"0h"`) bị Excel hiểu là văn bản (text), do đó không thể sử dụng các hàm tính toán cơ bản như `SUM`, `AVERAGE`.
   - **Giải pháp**: 
     - Đã chuyển đổi dữ liệu khi xuất sang `DoubleCellValue` cho các số thập phân và `IntCellValue` cho số nguyên.
     - Dữ liệu giờ công, lương cơ bản, phụ cấp, tạm ứng, lương thực nhận đều đã được chuyển thành số.

2. **Sửa lỗi hiển thị `0,00` khi không có ca làm**
   - **Tình trạng cũ**: Trong file Lịch làm và Bảng công, khi nhân viên không có dữ liệu chấm công, hệ thống xuất ra chuỗi `"0h"` hoặc `"0,00"`.
   - **Giải pháp**: Ghi đè giá trị mặc định bằng `IntCellValue(0)` (số 0 tròn trĩnh) khi tổng số giờ hoặc ca làm bằng 0.

3. **Cải thiện tên file xuất ra (Descriptive File Naming)**
   - **Tình trạng cũ**: Tên file chung chung, thiếu thông tin (ví dụ: `BangCong_2025-08.xlsx`, `BaoCaoLuong_Filter.xlsx`).
   - **Giải pháp**: Định dạng lại tên file đầy đủ bao gồm: `[Loại báo cáo]_[Tên cửa hàng]_[Thời gian]_[Tên nhân viên (nếu có)].xlsx`.
   - Bổ sung hàm `sanitize()` để tự động loại bỏ dấu tiếng Việt, thay khoảng trắng bằng dấu `_` và xóa ký tự đặc biệt khỏi tên file.
   - **Ví dụ tên file mới**: 
     - `BangCong_QuanCaPhe_T08-2025.xlsx`
     - `BaoCaoLuong_QuanCaPhe_T08-2025_NguyenVanA.xlsx`
     - `LichLam_QuanCaPhe_Tuan_11.08-17.08.2025.xlsx`

---

## 2. Các file đã chỉnh sửa

Các file mã nguồn sau đã được cập nhật:

- `lib/core/utils/excel_export_service.dart`: Thêm hàm `sanitize()`, chuyển đổi `TextCellValue` thành `DoubleCellValue`/`IntCellValue` cho các cột tính toán, thêm tham số `memberName` và logic tạo tên file mới.
- `lib/core/utils/export_utils.dart`: Đổi `TextCellValue('0h')` thành `IntCellValue(0)`, thêm tham số `storeName` và logic tên file mới cho báo cáo lịch làm.
- `lib/features/attendance/screens/attendance_table_screen.dart`: Bổ sung truyền biến `memberName` khi gọi hàm xuất bảng công.
- `lib/features/salary/screens/salary_overview_screen.dart`: Bổ sung truyền biến `memberName` khi gọi hàm xuất báo cáo lương.
- `lib/features/schedule/screens/schedule_manager_screen.dart`: Bổ sung truyền biến `storeName` khi gọi hàm xuất lịch làm tuần.

---

## 3. Trạng thái

- Đã hoàn tất code.
- Vượt qua vòng kiểm tra `flutter analyze` (0 error).
- Đã được commit và push lên branch `main` của repository GitHub (`origin/main`).
- Thông điệp commit: `fix: update excel export hour format to numeric, set empty shifts to 0, and enhance exported file names`

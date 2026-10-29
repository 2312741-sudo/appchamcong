import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';

/// Thông báo lỗi dễ hiểu cho người dùng (thay vì in nguyên mã lỗi Firestore)
String supplyErrorMessage(Object e) {
  final s = e.toString();
  if (s.contains('permission-denied')) {
    return 'Chưa có quyền truy cập dữ liệu Đặt & soạn hàng.\n'
        'Quản trị cần cập nhật quyền Firestore (deploy firestore.rules), hoặc tài khoản của bạn chưa được duyệt vào cửa hàng.';
  }
  if (s.contains('unavailable') || s.contains('network')) {
    return 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';
  }
  return 'Có lỗi khi tải dữ liệu: $s';
}

class SupplyErrorView extends StatelessWidget {
  final Object error;
  const SupplyErrorView(this.error, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.shieldAlert, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            supplyErrorMessage(error),
            textAlign: TextAlign.center,
            style: GoogleFonts.beVietnamPro(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
        ]),
      ),
    );
  }
}

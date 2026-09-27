import 'package:flutter_test/flutter_test.dart';
import 'package:cham_cong_tram/core/constants/app_colors.dart';
import 'package:cham_cong_tram/features/schedule/screens/schedule_palette.dart';
import 'package:cham_cong_tram/models/member_model.dart';

void main() {
  test('manager variants share blue schedule styling', () {
    for (final role in [
      UserRole.manager1,
      UserRole.manager2,
      UserRole.legacyManager,
    ]) {
      final palette = SchedulePalette.forRole(role);
      expect(palette.accent, AppColors.managerAccent);
      expect(palette.surface, isNot(AppColors.surface));
      expect(palette.outline, isNot(AppColors.cardOutline));
    }
  });

  test('owner schedule stays black and employee keeps the brand palette', () {
    expect(
        SchedulePalette.forRole(UserRole.owner).accent, AppColors.ownerAccent);
    expect(
        SchedulePalette.forRole(UserRole.employee).accent, AppColors.primary);
  });
}

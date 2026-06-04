import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/store_model.dart';
import '../../store/providers/store_provider.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  bool _isSaving = false;
  String? _selectedDepartmentId;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(currentStoreProvider);
    final currentMember = ref.watch(currentMemberProvider);

    if (!_initialized && currentMember != null) {
      _initialized = true;
      _selectedDepartmentId = currentMember.department;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Hồ sơ của tôi',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (store) {
          final user = FirebaseAuth.instance.currentUser;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Avatar & Info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Text(
                              (user?.displayName ?? 'U')[0].toUpperCase(),
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Người dùng',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                          if (currentMember != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                currentMember.role.label,
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Department Section
              if (store != null && store.departments.isNotEmpty) ...[
                Text('Bộ phận của tôi',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral)),
                const SizedBox(height: 4),
                Text('Chọn bộ phận bạn đang làm việc tại cửa hàng này.',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // No department option
                      _DeptTile(
                        label: 'Không thuộc bộ phận nào',
                        shortName: '—',
                        isSelected: _selectedDepartmentId == null,
                        onTap: () => setState(() => _selectedDepartmentId = null),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ...store.departments.map((dept) {
                        final isSelected = _selectedDepartmentId == dept.id;
                        return Column(
                          children: [
                            _DeptTile(
                              label: dept.name,
                              shortName: dept.shortName,
                              isSelected: isSelected,
                              onTap: () =>
                                  setState(() => _selectedDepartmentId = dept.id),
                            ),
                            if (dept != store.departments.last)
                              const Divider(height: 1, indent: 16, endIndent: 16),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () => _saveDepartment(store.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Text('Lưu bộ phận',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ] else if (store != null && store.departments.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.business_outlined,
                          size: 40, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text('Cửa hàng chưa thiết lập bộ phận',
                          style: GoogleFonts.beVietnamPro(
                              fontWeight: FontWeight.w600,
                              color: AppColors.neutral)),
                      const SizedBox(height: 4),
                      Text(
                        'Chủ cửa hàng có thể thêm bộ phận trong Cài đặt cửa hàng.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveDepartment(String storeId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(storeRepositoryProvider);
      await repo.updateMemberDepartment(storeId, uid, _selectedDepartmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Đã cập nhật bộ phận'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _DeptTile extends StatelessWidget {
  final String label;
  final String shortName;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeptTile({
    required this.label,
    required this.shortName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  shortName,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.neutral,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../core/widgets/role_badge.dart';
import '../../../models/member_model.dart';
import '../../../models/task_assignment_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../store/providers/store_provider.dart';
import '../providers/task_provider.dart';

/// Modal / Dialog tạo và giao việc mới cho nhân viên cửa hàng.
/// Dành cho Chủ cửa hàng (Owner), Quản lý 1 (Manager 1), Quản lý 2 (Manager 2).
class CreateTaskDialog extends ConsumerStatefulWidget {
  const CreateTaskDialog({super.key});

  /// Helper mở modal bottom sheet thuận tiện từ bất kỳ màn hình nào
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreateTaskDialog(),
    );
  }

  @override
  ConsumerState<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends ConsumerState<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _memberSearchController = TextEditingController();

  // Danh sách các ngày thực hiện được chọn (YYYY-MM-DD)
  final Set<String> _selectedDates = {};

  // Đối tượng nhận việc
  TaskTargetType _targetType = TaskTargetType.allStore;

  // Danh sách ID thành viên được chọn khi targetType == individual
  final Set<String> _selectedMemberIds = {};

  // Yêu cầu ảnh chụp minh chứng
  bool _requirePhoto = false;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Mặc định chọn ngày hôm nay
    final today = _formatDateIso(DateTime.now());
    _selectedDates.add(today);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  String _formatDateIso(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  String _formatDateDisplay(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final check = DateTime(dt.year, dt.month, dt.day);

      final diffDays = check.difference(today).inDays;
      if (diffDays == 0) {
        return 'Hôm nay (${DateFormat('dd/MM').format(dt)})';
      } else if (diffDays == 1) {
        return 'Ngày mai (${DateFormat('dd/MM').format(dt)})';
      } else if (diffDays == 2) {
        return 'Ngày kia (${DateFormat('dd/MM').format(dt)})';
      } else {
        final weekdayName = _weekdayName(dt.weekday);
        return '$weekdayName, ${DateFormat('dd/MM/yyyy').format(dt)}';
      }
    } catch (_) {
      return isoDate;
    }
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ 2';
      case DateTime.tuesday:
        return 'Thứ 3';
      case DateTime.wednesday:
        return 'Thứ 4';
      case DateTime.thursday:
        return 'Thứ 5';
      case DateTime.friday:
        return 'Thứ 6';
      case DateTime.saturday:
        return 'Thứ 7';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('vi', 'VN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final iso = _formatDateIso(picked);
      setState(() {
        _selectedDates.add(iso);
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitTask() async {
    if (_isSubmitting) return;

    setState(() {
      _errorMessage = null;
    });

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_selectedDates.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng chọn ít nhất một ngày thực hiện!';
      });
      return;
    }

    if (_targetType == TaskTargetType.individual && _selectedMemberIds.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng chọn ít nhất một người nhận việc!';
      });
      return;
    }

    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null || storeId.isEmpty) {
      setState(() {
        _errorMessage = 'Không xác định được cửa hàng hiện tại!';
      });
      return;
    }

    final currentMember = ref.read(currentMemberProvider);
    final currentUser = ref.read(currentUserProvider).valueOrNull;

    final creatorId = currentMember?.userId ?? currentUser?.id ?? '';
    final creatorName = currentMember?.name ?? currentUser?.name ?? 'Quản lý';
    final creatorRole = currentMember?.role ?? UserRole.manager1;

    // Lấy tên các thành viên được chọn
    final allMembers = ref.read(activeMembersProvider);
    final selectedNames = <String>[];
    if (_targetType == TaskTargetType.individual) {
      for (final id in _selectedMemberIds) {
        final m = allMembers.cast<MemberModel?>().firstWhere(
              (element) => element?.userId == id,
              orElse: () => null,
            );
        if (m != null) {
          selectedNames.add(m.name);
        } else {
          selectedNames.add('Thành viên');
        }
      }
    }

    final sortedDates = _selectedDates.toList()..sort();

    final task = AssignedTask(
      id: '',
      storeId: storeId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      createdBy: creatorId,
      createdByName: creatorName,
      createdByRole: creatorRole,
      targetType: _targetType,
      assignedUserIds: _targetType == TaskTargetType.allStore
          ? const []
          : _selectedMemberIds.toList(),
      assignedNames:
          _targetType == TaskTargetType.allStore ? const [] : selectedNames,
      executionDates: sortedDates,
      requirePhoto: _requirePhoto,
      status: TaskStatus.active,
      createdAt: DateTime.now(),
    );

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ref.read(taskRepositoryProvider);
      await repo.createTask(task);

      // Ép làm mới các provider để giao diện cập nhật ngay lập tức
      ref.invalidate(todayUserTasksProvider);
      ref.invalidate(unfinishedUserTasksProvider);
      ref.invalidate(storeTasksProvider(storeId));
      ref.invalidate(storeTasksFilteredProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã giao công việc thành công!',
                    style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi tạo công việc: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeMembers = ref.watch(activeMembersProvider);
    final viewInsets = MediaQuery.of(context).viewInsets;
    final size = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.9,
      ),
      margin: EdgeInsets.only(bottom: viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_add,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giao việc mới',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Chủ & Quản lý phân công công việc',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                  splashRadius: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Form content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.danger,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 13,
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 1. Tiêu đề công việc
                    Text(
                      'Tiêu đề công việc *',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'VD: Kiểm tra tồn kho cuối ngày, Vệ sinh máy pha...',
                        hintStyle: GoogleFonts.beVietnamPro(
                          fontSize: 13.5,
                          color: AppColors.textDisabled,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        prefixIcon: const Icon(
                          Icons.title_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập tiêu đề công việc';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // 2. Mô tả chi tiết
                    Text(
                      'Mô tả chi tiết',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Mô tả cụ thể các việc cần làm, tiêu chí hoàn thành...',
                        hintStyle: GoogleFonts.beVietnamPro(
                          fontSize: 13.5,
                          color: AppColors.textDisabled,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Chọn ngày thực hiện (executionDates)
                    _buildExecutionDatesSection(),
                    const SizedBox(height: 20),

                    // 4. Chọn đối tượng nhận việc
                    _buildTargetSelectionSection(activeMembers),
                    const SizedBox(height: 20),

                    // 5. Switch Yêu cầu ảnh minh chứng
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (_requirePhoto ? AppColors.warning : AppColors.textDisabled)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: _requirePhoto
                                  ? const Color(0xFFD97706)
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bắt buộc chụp ảnh minh chứng',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Nhân viên phải chụp ảnh kết quả khi báo cáo hoàn thành',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _requirePhoto,
                            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                _requirePhoto = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nút Tạo công việc
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.5),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_task_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Giao công việc',
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section chọn ngày thực hiện linh hoạt
  Widget _buildExecutionDatesSection() {
    final now = DateTime.now();
    final today = _formatDateIso(now);
    final tomorrow = _formatDateIso(now.add(const Duration(days: 1)));
    final dayAfterTomorrow = _formatDateIso(now.add(const Duration(days: 2)));

    // 4 ngày kế tiếp để chọn nhanh
    final upcomingDays = List.generate(4, (i) {
      final dt = now.add(Duration(days: i + 3));
      return dt;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Ngày thực hiện *',
              style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_selectedDates.length} ngày đã chọn)',
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Chọn một hoặc nhiều ngày trong tương lai task này cần làm:',
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Quick add buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildQuickDateChip(
                label: 'Hôm nay',
                isoDate: today,
                isSelected: _selectedDates.contains(today),
              ),
              const SizedBox(width: 6),
              _buildQuickDateChip(
                label: 'Ngày mai',
                isoDate: tomorrow,
                isSelected: _selectedDates.contains(tomorrow),
              ),
              const SizedBox(width: 6),
              _buildQuickDateChip(
                label: 'Ngày kia',
                isoDate: dayAfterTomorrow,
                isSelected: _selectedDates.contains(dayAfterTomorrow),
              ),
              const SizedBox(width: 6),
              for (final dt in upcomingDays) ...[
                _buildQuickDateChip(
                  label: '${_weekdayName(dt.weekday)} (${DateFormat('dd/MM').format(dt)})',
                  isoDate: _formatDateIso(dt),
                  isSelected: _selectedDates.contains(_formatDateIso(dt)),
                ),
                const SizedBox(width: 6),
              ],
              ActionChip(
                avatar: const Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: Text(
                  '+ Chọn ngày khác',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
                onPressed: _pickCustomDate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Danh sách Chips các ngày đã chọn
        if (_selectedDates.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_selectedDates.toList()..sort()).map((iso) {
                return Chip(
                  label: Text(
                    _formatDateDisplay(iso),
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  deleteIcon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  onDeleted: () {
                    setState(() {
                      _selectedDates.remove(iso);
                    });
                  },
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Chưa chọn ngày nào. Vui lòng bấm chọn ngày phía trên.',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuickDateChip({
    required String label,
    required String isoDate,
    required bool isSelected,
  }) {
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: GoogleFonts.beVietnamPro(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : AppColors.border.withValues(alpha: 0.8),
      ),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedDates.add(isoDate);
          } else {
            _selectedDates.remove(isoDate);
          }
          _errorMessage = null;
        });
      },
    );
  }

  /// Section chọn đối tượng nhận việc
  Widget _buildTargetSelectionSection(List<MemberModel> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đối tượng nhận việc *',
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        // Segmented Control
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.8),
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: _buildSegmentButton(
                  title: 'Toàn bộ cửa hàng',
                  icon: Icons.storefront_rounded,
                  isSelected: _targetType == TaskTargetType.allStore,
                  onTap: () {
                    setState(() {
                      _targetType = TaskTargetType.allStore;
                      _errorMessage = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSegmentButton(
                  title: 'Chỉ định cá nhân/nhóm',
                  icon: Icons.group_outlined,
                  isSelected: _targetType == TaskTargetType.individual,
                  onTap: () {
                    setState(() {
                      _targetType = TaskTargetType.individual;
                      _errorMessage = null;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Khi chọn "Chỉ định cá nhân / nhóm"
        if (_targetType == TaskTargetType.individual) ...[
          _buildIndividualMembersList(members),
        ],
      ],
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Danh sách thành viên để tick chọn
  Widget _buildIndividualMembersList(List<MemberModel> members) {
    final query = _memberSearchController.text.trim().toLowerCase();
    final filteredMembers = members.where((m) {
      if (query.isEmpty) return true;
      return m.name.toLowerCase().contains(query) ||
          (m.phone?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header chọn nhanh & Đếm
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đã chọn: ${_selectedMemberIds.length}/${members.length} người',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    if (_selectedMemberIds.length == members.length) {
                      _selectedMemberIds.clear();
                    } else {
                      _selectedMemberIds.addAll(members.map((e) => e.userId));
                    }
                    _errorMessage = null;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    _selectedMemberIds.length == members.length
                        ? 'Bỏ chọn tất cả'
                        : 'Chọn tất cả',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.managerAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tìm kiếm nhanh nếu danh sách > 4
          if (members.length > 4) ...[
            TextField(
              controller: _memberSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc SĐT...',
                hintStyle: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: AppColors.textDisabled,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.cardSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              style: GoogleFonts.beVietnamPro(fontSize: 12.5),
            ),
            const SizedBox(height: 8),
          ],

          // Danh sách thành viên (có thể chọn cả Chủ, QL1, QL2, Nhân viên)
          if (filteredMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Không tìm thấy thành viên phù hợp',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filteredMembers.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, index) {
                  final member = filteredMembers[index];
                  final isSelected = _selectedMemberIds.contains(member.userId);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedMemberIds.remove(member.userId);
                        } else {
                          _selectedMemberIds.add(member.userId);
                        }
                        _errorMessage = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedMemberIds.add(member.userId);
                                } else {
                                  _selectedMemberIds.remove(member.userId);
                                }
                                _errorMessage = null;
                              });
                            },
                          ),
                          AvatarWidget(
                            name: member.name,
                            avatarUrl: member.avatarUrl,
                            radius: 15,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name,
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (member.phone != null && member.phone!.isNotEmpty)
                                  Text(
                                    member.phone!,
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          RoleBadge(role: member.role, compact: true),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

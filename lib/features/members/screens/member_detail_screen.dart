import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/member_model.dart';
import '../../store/providers/store_provider.dart';

class MemberDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const MemberDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  UserRole _selectedRole = UserRole.employee;
  EmployeeType _selectedType = EmployeeType.fulltime;
  
  final _monthlySalaryCtrl = TextEditingController();
  final _hourlyRateCtrl = TextEditingController();
  final _standardHoursCtrl = TextEditingController();
  final _employeeCodeCtrl = TextEditingController();
  DateTime? _joinedAt;

  bool _isInit = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _monthlySalaryCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _standardHoursCtrl.dispose();
    _employeeCodeCtrl.dispose();
    super.dispose();
  }

  void _initData(MemberModel member) {
    if (_isInit) return;
    _selectedRole = member.role;
    _selectedType = member.employeeType;
    _employeeCodeCtrl.text = member.employeeCode ?? '';
    _joinedAt = member.joinedAt;
    _monthlySalaryCtrl.text = member.baseMonthlySalary.toStringAsFixed(0);
    _hourlyRateCtrl.text = member.baseHourlyRate.toStringAsFixed(0);
    _standardHoursCtrl.text = member.standardHoursPerMonth.toStringAsFixed(0);
    _isInit = true;
  }

  Future<void> _saveChanges(String storeId) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(storeRepositoryProvider);
      
      // Update role
      await repo.updateMemberRole(storeId, widget.userId, _selectedRole);
      
      // Update salary
      double salary = _selectedType == EmployeeType.fulltime
          ? double.tryParse(_monthlySalaryCtrl.text) ?? 0
          : double.tryParse(_hourlyRateCtrl.text) ?? 0;
      double hours = double.tryParse(_standardHoursCtrl.text) ?? 208;
          
      await repo.updateMemberSalary(storeId, widget.userId, _selectedType, salary, hours);
      
      // Update employee info
      await repo.updateMemberInfo(
        storeId, 
        widget.userId, 
        _employeeCodeCtrl.text.trim(), 
        _joinedAt
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lưu thành công'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.primary),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _kickMember(String storeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa nhân viên này khỏi cửa hàng?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(storeRepositoryProvider);
      await repo.kickMember(storeId, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa nhân viên'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.primary),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeId = ref.watch(currentStoreIdProvider);
    final membersAsync = ref.watch(storeMembersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết nhân viên', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
        data: (members) {
          final member = members.firstWhere(
            (m) => m.userId == widget.userId,
            orElse: () => MemberModel(
              userId: '', name: 'Not Found', role: UserRole.employee, 
              status: MemberStatus.kicked, employeeType: EmployeeType.fulltime, joinedAt: DateTime.now()
            ) as dynamic, 
          );
          
          if (member.userId.isEmpty) {
            return const Center(child: Text('Không tìm thấy nhân viên.'));
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initData(member);
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: member.hasAvatar ? NetworkImage(member.avatarUrl!) : null,
                      child: !member.hasAvatar
                          ? Text(member.initials, style: const TextStyle(fontSize: 24, color: AppColors.primary))
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.name, style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 18, fontWeight: FontWeight.bold)),
                          if (member.phone != null) ...[
                            const SizedBox(height: 4),
                            Text(member.phone!, style: const TextStyle(fontFamily: 'BeVietnamPro', color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                const Text('Mã nhân viên', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _employeeCodeCtrl,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'VD: NV001',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Ngày vào làm', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _joinedAt ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _joinedAt = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _joinedAt != null ? '${_joinedAt!.day.toString().padLeft(2, '0')}/${_joinedAt!.month.toString().padLeft(2, '0')}/${_joinedAt!.year}' : 'Chọn ngày',
                      style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Role Setup
                const Text('Vai trò', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedRole = v);
                  },
                ),
                const SizedBox(height: 24),
                
                // Employee Type Setup
                const Text('Loại hình', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<EmployeeType>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  items: EmployeeType.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedType = v);
                  },
                ),
                const SizedBox(height: 24),

                // Salary configs
                if (_selectedType == EmployeeType.fulltime) ...[
                  const Text('Lương cơ bản (tháng)', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _monthlySalaryCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'VD: 5000000',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Số giờ chuẩn (tháng)', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _standardHoursCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'VD: 208',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ] else ...[
                  const Text('Lương cơ bản (giờ)', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _hourlyRateCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'VD: 20000',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ],

                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading || storeId == null ? null : () => _saveChanges(storeId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Lưu thay đổi', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: _isLoading || storeId == null ? null : () => _kickMember(storeId),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Xóa khỏi cửa hàng', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
          },
        ),
    );
  }
}

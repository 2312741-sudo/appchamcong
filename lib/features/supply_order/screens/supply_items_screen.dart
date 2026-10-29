import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/app_permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/supply_order_model.dart';
import '../../store/providers/store_provider.dart';
import '../providers/supply_order_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/supply_error_view.dart';

/// Danh mục hàng đặt (bao bì, ly, ống hút, nguyên liệu…). Chủ, Quản lý 1, Quản lý 2 sửa; người khác chỉ xem.
class SupplyItemsScreen extends ConsumerWidget {
  const SupplyItemsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, {SupplyItem? item, required int count}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final unitCtrl = TextEditingController(text: item?.unit ?? '');
    final groupCtrl = TextEditingController(text: item?.group ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(item == null ? 'Thêm mặt hàng' : 'Sửa mặt hàng',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Tên hàng *', hintText: 'VD: Ly 500ml, Nắp cầu, Ống hút', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Đơn vị', hintText: 'VD: cái, bịch, thùng, kg', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: groupCtrl, decoration: const InputDecoration(labelText: 'Nhóm', hintText: 'VD: Bao bì, Nguyên liệu', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(item == null ? 'Thêm' : 'Lưu'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên hàng')));
      return;
    }
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    try {
      await ref.read(supplyOrderRepositoryProvider).saveItem(
            storeId,
            SupplyItem(
              id: item?.id ?? '',
              name: name,
              unit: unitCtrl.text.trim(),
              group: groupCtrl.text.trim(),
              order: item?.order ?? count + 1,
              active: item?.active ?? true,
            ),
          );
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = AppPermissions.canManageSupplyCatalog(ref.watch(currentMemberProvider)?.role);
    final itemsAsync = ref.watch(allSupplyItemsProvider);
    final storeId = ref.watch(currentStoreIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Danh mục hàng đặt', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        // Theme chung đặt màu chữ/icon AppBar cố định → phải ghi rõ để nền màu dùng chữ trắng
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _edit(context, ref, count: itemsAsync.valueOrNull?.length ?? 0),
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SupplyErrorView(e),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(canEdit ? 'Chưa có mặt hàng. Bấm + để thêm.' : 'Chưa có mặt hàng.',
                  style: GoogleFonts.beVietnamPro(color: AppColors.textSecondary)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final it = items[i];
              return Container(
                decoration: BoxDecoration(
                  color: it.active ? Colors.white : AppColors.paperInk,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  title: Text(it.name,
                      style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, color: it.active ? AppColors.textPrimary : AppColors.textDisabled)),
                  subtitle: Text([if (it.group.isNotEmpty) it.group, if (it.unit.isNotEmpty) 'Đơn vị: ${it.unit}', if (!it.active) 'Đã ẩn'].join(' • ')),
                  onTap: canEdit ? () => _edit(context, ref, item: it, count: items.length) : null,
                  trailing: canEdit && storeId != null
                      ? Switch(
                          value: it.active,
                          activeColor: AppColors.primary,
                          onChanged: (v) => ref.read(supplyOrderRepositoryProvider).setItemActive(storeId, it.id, v),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

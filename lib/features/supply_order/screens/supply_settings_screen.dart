import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/app_permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/supply_order_model.dart';
import '../../store/providers/store_provider.dart';
import '../providers/supply_order_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Cài đặt đặt & soạn hàng: giờ chốt đặt hàng, bộ phận soạn hàng khi vào ca. Chủ, QL1, QL2 chỉnh.
class SupplySettingsScreen extends ConsumerStatefulWidget {
  const SupplySettingsScreen({super.key});

  @override
  ConsumerState<SupplySettingsScreen> createState() => _SupplySettingsScreenState();
}

class _SupplySettingsScreenState extends ConsumerState<SupplySettingsScreen> {
  bool _loaded = false;
  bool _hasCutoff = false;
  TimeOfDay _cutoff = const TimeOfDay(hour: 21, minute: 0);
  final Set<String> _deps = {};
  bool _saving = false;

  void _load(SupplySettings s) {
    if (_loaded) return;
    _loaded = true;
    final c = s.cutoffTime;
    if (c != null) {
      final p = c.split(':');
      _hasCutoff = true;
      _cutoff = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    _deps.addAll(s.preparerDepartmentIds);
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(supplyOrderRepositoryProvider).saveSettings(
            storeId,
            SupplySettings(cutoffTime: _hasCutoff ? _fmt(_cutoff) : null, preparerDepartmentIds: _deps.toList()),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt đặt & soạn hàng')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = AppPermissions.canManageSupplyCatalog(ref.watch(currentMemberProvider)?.role);
    final settingsAsync = ref.watch(supplySettingsProvider);
    final departments = ref.watch(currentStoreProvider).valueOrNull?.departments ?? const [];
    final settings = settingsAsync.valueOrNull;
    if (settings != null) _load(settings);

    final title = GoogleFonts.beVietnamPro(fontWeight: FontWeight.w800, fontSize: 15);
    final hint = GoogleFonts.beVietnamPro(fontSize: 12, color: AppColors.textSecondary);
    BoxDecoration card() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cài đặt đặt & soạn hàng', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: card(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Giờ chốt đặt hàng', style: title),
                  const SizedBox(height: 4),
                  Text('Phiếu của ngày hôm sau khóa từ giờ này của hôm trước. Sau giờ chốt chỉ Chủ, Quản lý 1, Quản lý 2 còn thêm / sửa được.', style: hint),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bật giờ chốt'),
                    value: _hasCutoff,
                    activeColor: AppColors.primary,
                    onChanged: canEdit ? (v) => setState(() => _hasCutoff = v) : null,
                  ),
                  if (_hasCutoff)
                    OutlinedButton.icon(
                      icon: const Icon(LucideIcons.clock),
                      label: Text('Chốt lúc ${_fmt(_cutoff)} mỗi ngày'),
                      onPressed: canEdit
                          ? () async {
                              final t = await showTimePicker(context: context, initialTime: _cutoff);
                              if (t != null) setState(() => _cutoff = t);
                            }
                          : null,
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: card(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bộ phận soạn hàng khi vào ca', style: title),
                  const SizedBox(height: 4),
                  Text('Người được xếp lịch ở bộ phận này trong ngày sẽ là người soạn hàng: thấy thẻ nhắc, được hỏi "Soạn hàng ngay?" khi chấm công vào và được tích "Đã soạn". Không chọn bộ phận nào = ai trong ca cũng soạn được.', style: hint),
                  const SizedBox(height: 6),
                  if (departments.isEmpty)
                    Text('Cửa hàng chưa có bộ phận — thêm bộ phận trong Cài đặt cửa hàng trước.', style: hint)
                  else
                    for (final d in departments)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _deps.contains(d.id),
                        activeColor: AppColors.primary,
                        title: Text(d.shortName.isEmpty ? d.name : '${d.name} (${d.shortName})'),
                        onChanged: canEdit
                            ? (v) => setState(() => v == true ? _deps.add(d.id) : _deps.remove(d.id))
                            : null,
                      ),
                ]),
              ),
              const SizedBox(height: 16),
              if (canEdit)
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Đang lưu...' : 'Lưu cài đặt', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
    );
  }
}

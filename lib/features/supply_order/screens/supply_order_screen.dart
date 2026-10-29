import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/app_permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/supply_date_utils.dart';
import '../../../models/supply_order_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../store/providers/store_provider.dart';
import '../providers/supply_order_provider.dart';
import 'supply_items_screen.dart';
import 'supply_history_screen.dart';
import 'supply_settings_screen.dart';

/// Đặt hàng (bao bì, hàng hóa) cho một ngày và tích "Đã soạn" khi vào ca.
/// Mọi vai trò đều đặt và tích được; nhiều người cùng đặt vào MỘT phiếu của ngày.
class SupplyOrderScreen extends ConsumerStatefulWidget {
  /// yyyy-MM-dd; mặc định: ngày mai (đặt hàng)
  final String? initialDate;

  const SupplyOrderScreen({super.key, this.initialDate});

  @override
  ConsumerState<SupplyOrderScreen> createState() => _SupplyOrderScreenState();
}

class _SupplyOrderScreenState extends ConsumerState<SupplyOrderScreen> with SingleTickerProviderStateMixin {
  late String _date;
  late final TabController _tabs;
  // Ô nhập số lượng / trọng lượng cho từng mặt hàng ở tab "Đặt hàng"
  final Map<String, TextEditingController> _qtyCtrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? SupplyDateUtils.tomorrow();
    // Mở phiếu hôm nay → vào thẳng tab "Soạn hàng"; ngày khác → "Đặt hàng"
    _tabs = TabController(length: 2, vsync: this, initialIndex: _date == SupplyDateUtils.today() ? 1 : 0);
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(String itemId) => _qtyCtrls.putIfAbsent(itemId, () => TextEditingController());

  int get _pendingCount => _qtyCtrls.values.where((c) => SupplyDateUtils.parseQty(c.text) != null).length;

  /// Lưu mọi số lượng đã nhập ở tab "Đặt hàng" vào phiếu ngày đang xem (cộng dồn)
  Future<void> _saveOrder(List<SupplyItem> items) async {
    final quantities = <SupplyItem, double>{};
    for (final it in items) {
      final c = _qtyCtrls[it.id];
      if (c == null || c.text.trim().isEmpty) continue;
      final q = SupplyDateUtils.parseQty(c.text);
      if (q == null) {
        _snack('Số lượng của "${it.name}" không hợp lệ', error: true);
        return;
      }
      quantities[it] = q;
    }
    if (quantities.isEmpty) {
      _snack('Nhập số lượng cho ít nhất một món');
      return;
    }
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(supplyOrderRepositoryProvider).addManyToOrder(
            storeId,
            _date,
            quantities: quantities,
            uid: _uid,
            userName: _userName,
          );
      for (final c in _qtyCtrls.values) {
        c.clear();
      }
      _snack('Đã đặt ${quantities.length} món cho ${SupplyDateUtils.label(_date)}');
    } catch (e) {
      _snack('Không lưu được: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _uid => ref.read(currentUserIdProvider) ?? '';
  String get _userName => ref.read(currentMemberProvider)?.name ?? '';

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : null),
    );
  }

  Future<void> _pickDate() async {
    final p = _date.split('-').map(int.parse).toList();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(p[0], p[1], p[2]),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _date = SupplyDateUtils.ymd(picked));
  }

  Future<double?> _askQty({required String title, double? initial, String unit = '', String? note, void Function(String)? onNote}) async {
    final qtyCtrl = TextEditingController(text: initial == null ? '' : SupplyDateUtils.formatQty(initial));
    final noteCtrl = TextEditingController(text: note ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: qtyCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Số lượng', suffixText: unit, border: const OutlineInputBorder()),
          ),
          if (onNote != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)', border: OutlineInputBorder()),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    final q = SupplyDateUtils.parseQty(qtyCtrl.text);
    if (q == null) {
      _snack('Số lượng không hợp lệ', error: true);
      return null;
    }
    onNote?.call(noteCtrl.text);
    return q;
  }

  Future<void> _editLine(SupplyOrderLine line) async {
    var note = line.note;
    final qty = await _askQty(
      title: 'Sửa "${line.name}"',
      initial: line.qty,
      unit: line.unit,
      note: line.note,
      onNote: (n) => note = n,
    );
    if (qty == null) return;
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    try {
      await ref.read(supplyOrderRepositoryProvider).updateLine(
            storeId, _date, line.itemId,
            qty: qty, note: note, uid: _uid, userName: _userName,
          );
    } catch (e) {
      _snack('Không lưu được: $e', error: true);
    }
  }

  Future<void> _removeLine(SupplyOrderLine line) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa khỏi phiếu'),
        content: Text('Xóa "${line.name}" khỏi phiếu ${SupplyDateUtils.label(_date)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    try {
      await ref.read(supplyOrderRepositoryProvider).removeLine(storeId, _date, line.itemId);
    } catch (e) {
      _snack('Không xóa được: $e', error: true);
    }
  }

  Future<void> _togglePrepared(SupplyOrderLine line, bool value) async {
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    try {
      await ref.read(supplyOrderRepositoryProvider).setPrepared(
            storeId, _date, line.itemId,
            prepared: value, uid: _uid, userName: _userName,
          );
    } catch (e) {
      _snack('Không lưu được: $e', error: true);
    }
  }

  void _openCatalog() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplyItemsScreen()));

  Widget _dateBar() {
    final today = SupplyDateUtils.today();
    final tomorrow = SupplyDateUtils.tomorrow();
    Widget chip(String label, String value) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 13)),
            selected: _date == value,
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            onSelected: (_) => setState(() => _date = value),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        chip('Hôm nay', today),
        chip('Ngày mai', tomorrow),
        const Spacer(),
        IconButton(tooltip: 'Chọn ngày', icon: const Icon(Icons.calendar_month_outlined), onPressed: _pickDate),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(currentMemberProvider);
    final canCatalog = AppPermissions.canManageSupplyCatalog(member?.role);
    final orderAsync = ref.watch(supplyOrderProvider(_date));
    final itemsAsync = ref.watch(supplyItemsProvider);
    final isToday = _date == SupplyDateUtils.today();
    final settings = ref.watch(supplySettingsProvider).valueOrNull ?? const SupplySettings();
    // Qua giờ chốt: chỉ Chủ / QL1 / QL2 còn thêm, sửa hàng
    final pastCutoff = SupplyDateUtils.isOrderLocked(_date, settings.cutoffTime);
    final orderLocked = pastCutoff && !canCatalog;
    final cutoffText = SupplyDateUtils.cutoffLabel(_date, settings.cutoffTime);
    // Soạn hàng: người được xếp lịch ở bộ phận soạn hàng trong ngày (hoặc Chủ / QL)
    final canPrepare = canCatalog || ref.watch(isSupplyPreparerProvider(_date));
    final prepDeptNames = _deptNames(settings.preparerDepartmentIds);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đặt & soạn hàng', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Lịch sử phiếu',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplyHistoryScreen())),
          ),
          if (canCatalog)
            IconButton(tooltip: 'Danh mục hàng', icon: const Icon(Icons.inventory_2_outlined), onPressed: _openCatalog),
          if (canCatalog)
            IconButton(
              tooltip: 'Cài đặt giờ chốt & người soạn',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplySettingsScreen())),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold),
          tabs: const [Tab(text: 'Đặt hàng'), Tab(text: 'Soạn hàng')],
        ),
      ),
      body: Column(children: [
        _dateBar(),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _orderTab(itemsAsync, orderAsync.valueOrNull, canCatalog, locked: orderLocked, pastCutoff: pastCutoff, cutoffText: cutoffText),
            _prepareTab(orderAsync, isToday, canPrepare: canPrepare, canEditLines: !orderLocked, prepDeptNames: prepDeptNames),
          ]),
        ),
      ]),
    );
  }

  /// Tab "Đặt hàng": danh sách hàng có sẵn (tên + đơn vị), người đặt chỉ nhập số lượng / trọng lượng
  /// Tên các bộ phận soạn hàng (để hiện trong thông báo)
  String _deptNames(List<String> ids) {
    if (ids.isEmpty) return '';
    final deps = ref.read(currentStoreProvider).valueOrNull?.departments ?? const [];
    return ids.map((id) => deps.where((d) => d.id == id).map((d) => d.name).firstOrNull ?? id).join(', ');
  }

  Widget _banner(String text, {Color color = AppColors.warning, IconData icon = Icons.lock_clock}) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _orderTab(AsyncValue<List<SupplyItem>> itemsAsync, SupplyOrder? order, bool canCatalog,
      {required bool locked, required bool pastCutoff, String? cutoffText}) {
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải danh mục: $e')),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  canCatalog ? 'Chưa có danh sách hàng. Hãy thiết lập tên món và đơn vị trước.' : 'Chưa có danh sách hàng — nhờ Quản lý thiết lập.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.beVietnamPro(color: AppColors.textSecondary),
                ),
                if (canCatalog) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: _openCatalog,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Thiết lập danh sách hàng'),
                  ),
                ],
              ]),
            ),
          );
        }
        final ordered = {for (final l in order?.lines ?? const <SupplyOrderLine>[]) l.itemId: l};
        String? lastGroup;
        final rows = <Widget>[];
        for (final it in items) {
          if (it.group != lastGroup && it.group.isNotEmpty) {
            rows.add(Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
              child: Text(it.group.toUpperCase(),
                  style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
            ));
          }
          lastGroup = it.group;
          final line = ordered[it.id];
          rows.add(Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.name, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
                  if (line != null)
                    Text('Đã đặt: ${SupplyDateUtils.formatQty(line.qty)} ${line.unit} • ${line.contributorNames.join(", ")}',
                        style: GoogleFonts.beVietnamPro(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _ctrlFor(it.id),
                  enabled: !locked,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: line == null ? 'SL' : '+ thêm',
                    suffixText: it.unit,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ]),
          ));
        }
        final pending = _pendingCount;
        return Column(children: [
          if (cutoffText != null)
            locked
                ? _banner('Đã chốt đặt hàng lúc $cutoffText. Cần thêm hàng, hãy báo Chủ hoặc Quản lý.')
                : _banner(
                    pastCutoff ? 'Đã qua giờ chốt ($cutoffText) — bạn là Chủ/Quản lý nên vẫn sửa được.' : 'Chốt đặt hàng lúc $cutoffText.',
                    color: pastCutoff ? AppColors.warning : AppColors.info,
                    icon: Icons.schedule,
                  ),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: rows)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: _saving || pending == 0 || locked ? null : () => _saveOrder(items),
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(pending == 0 ? 'Nhập số lượng để đặt' : 'Đặt $pending món cho ${SupplyDateUtils.label(_date)}',
                      style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  /// Tab "Soạn hàng": người vào ca kiểm từng món đã đặt và tích "Đã soạn"
  Widget _prepareTab(AsyncValue<SupplyOrder> orderAsync, bool isToday,
      {required bool canPrepare, required bool canEditLines, required String prepDeptNames}) {
    return orderAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải phiếu: $e')),
      data: (order) {
        if (order.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Chưa có hàng nào được đặt cho ${SupplyDateUtils.label(_date)}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _ProgressHeader(order: order, isToday: isToday),
            if (!canPrepare)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Chỉ người được xếp lịch ở bộ phận ${prepDeptNames.isEmpty ? "soạn hàng" : prepDeptNames} trong ngày này mới tích "Đã soạn".',
                  style: GoogleFonts.beVietnamPro(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 8),
            for (final line in order.lines)
              _LineTile(
                line: line,
                onToggle: canPrepare ? (v) => _togglePrepared(line, v) : null,
                onEdit: canEditLines ? () => _editLine(line) : null,
                onRemove: canEditLines ? () => _removeLine(line) : null,
              ),
          ],
        );
      },
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final SupplyOrder order;
  final bool isToday;
  const _ProgressHeader({required this.order, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final total = order.lines.length;
    final done = order.preparedCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          order.isAllPrepared ? 'Đã soạn đủ $total/$total món' : 'Đã soạn $done/$total món',
          style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: total == 0 ? 0 : done / total,
          minHeight: 6,
          backgroundColor: AppColors.paperInk,
          color: order.isAllPrepared ? AppColors.success : AppColors.primary,
          borderRadius: BorderRadius.circular(4),
        ),
        if (isToday && !order.isAllPrepared) ...[
          const SizedBox(height: 8),
          Text('Người vào ca hôm nay kiểm từng món và tích "Đã soạn".',
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }
}

class _LineTile extends StatelessWidget {
  final SupplyOrderLine line;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const _LineTile({required this.line, this.onToggle, this.onEdit, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final who = line.contributorNames;
    final preparedAt = line.preparedAt == null
        ? ''
        : DateFormat('HH:mm dd/MM').format(DateTime.fromMillisecondsSinceEpoch(line.preparedAt!).toUtc().add(const Duration(hours: 7)));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: line.prepared ? AppColors.success.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: CheckboxListTile(
        value: line.prepared,
        activeColor: AppColors.success,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: onToggle == null ? null : (v) => onToggle!(v ?? false),
        title: Text(
          '${line.name} — ${SupplyDateUtils.formatQty(line.qty)} ${line.unit}',
          style: GoogleFonts.beVietnamPro(
            fontWeight: FontWeight.w700,
            decoration: line.prepared ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (line.group.isNotEmpty) Text(line.group, style: GoogleFonts.beVietnamPro(fontSize: 11, color: AppColors.textSecondary)),
          if (who.isNotEmpty) Text('Đặt bởi: ${who.join(", ")}', style: GoogleFonts.beVietnamPro(fontSize: 12)),
          if (line.note.isNotEmpty) Text('Ghi chú: ${line.note}', style: GoogleFonts.beVietnamPro(fontSize: 12, fontStyle: FontStyle.italic)),
          if (line.prepared)
            Text('Đã soạn bởi ${line.preparedByName.isEmpty ? line.preparedBy : line.preparedByName}${preparedAt.isEmpty ? "" : " lúc $preparedAt"}',
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
        ]),
        secondary: onEdit == null && onRemove == null
            ? null
            : PopupMenuButton<String>(
          onSelected: (v) => v == 'edit' ? onEdit?.call() : onRemove?.call(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Sửa số lượng / ghi chú')),
            PopupMenuItem(value: 'remove', child: Text('Xóa khỏi phiếu')),
          ],
        ),
      ),
    );
  }
}

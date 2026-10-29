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

/// Đặt hàng (bao bì, hàng hóa) cho một ngày và tích "Đã soạn" khi vào ca.
/// Mọi vai trò đều đặt và tích được; nhiều người cùng đặt vào MỘT phiếu của ngày.
class SupplyOrderScreen extends ConsumerStatefulWidget {
  /// yyyy-MM-dd; mặc định: ngày mai (đặt hàng)
  final String? initialDate;

  const SupplyOrderScreen({super.key, this.initialDate});

  @override
  ConsumerState<SupplyOrderScreen> createState() => _SupplyOrderScreenState();
}

class _SupplyOrderScreenState extends ConsumerState<SupplyOrderScreen> {
  late String _date;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? SupplyDateUtils.tomorrow();
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

  /// Chọn mặt hàng trong danh mục rồi nhập số lượng → cộng dồn vào phiếu ngày đang xem
  Future<void> _addItem() async {
    final items = ref.read(supplyItemsProvider).valueOrNull ?? const <SupplyItem>[];
    final canCatalog = AppPermissions.canManageSupplyCatalog(ref.read(currentMemberProvider)?.role);
    if (items.isEmpty) {
      _snack(canCatalog ? 'Danh mục hàng đang trống — hãy thêm mặt hàng trước' : 'Danh mục hàng đang trống — nhờ Quản lý thêm mặt hàng');
      if (canCatalog) _openCatalog();
      return;
    }
    final item = await showModalBottomSheet<SupplyItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ItemPickerSheet(items: items),
    );
    if (item == null || !mounted) return;
    var note = '';
    final qty = await _askQty(
      title: 'Đặt "${item.name}" cho ${SupplyDateUtils.label(_date)}',
      unit: item.unit,
      onNote: (n) => note = n,
    );
    if (qty == null) return;
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    try {
      await ref.read(supplyOrderRepositoryProvider).addToOrder(
            storeId,
            _date,
            item: item,
            qty: qty,
            uid: _uid,
            userName: _userName,
            note: note,
          );
      _snack('Đã thêm ${SupplyDateUtils.formatQty(qty)} ${item.unit} ${item.name}');
    } catch (e) {
      _snack('Không lưu được: $e', error: true);
    }
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
        chip('Hôm nay (soạn)', today),
        chip('Ngày mai (đặt)', tomorrow),
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
    final isToday = _date == SupplyDateUtils.today();

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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _addItem,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text('Thêm hàng', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        _dateBar(),
        Expanded(
          child: orderAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi tải phiếu: $e')),
            data: (order) {
              if (order.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Chưa có hàng nào trong phiếu ${SupplyDateUtils.label(_date)}.\nBấm "Thêm hàng" để đặt.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.beVietnamPro(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _ProgressHeader(order: order, isToday: isToday),
                  const SizedBox(height: 8),
                  for (final line in order.lines)
                    _LineTile(
                      line: line,
                      onToggle: (v) => _togglePrepared(line, v),
                      onEdit: () => _editLine(line),
                      onRemove: () => _removeLine(line),
                    ),
                ],
              );
            },
          ),
        ),
      ]),
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
          order.isAllPrepared ? '✅ Đã soạn đủ $total/$total món' : '📦 Đã soạn $done/$total món',
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
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _LineTile({required this.line, required this.onToggle, required this.onEdit, required this.onRemove});

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
        onChanged: (v) => onToggle(v ?? false),
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
        secondary: PopupMenuButton<String>(
          onSelected: (v) => v == 'edit' ? onEdit() : onRemove(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Sửa số lượng / ghi chú')),
            PopupMenuItem(value: 'remove', child: Text('Xóa khỏi phiếu')),
          ],
        ),
      ),
    );
  }
}

class _ItemPickerSheet extends StatefulWidget {
  final List<SupplyItem> items;
  const _ItemPickerSheet({required this.items});

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = widget.items.where((i) => q.isEmpty || i.name.toLowerCase().contains(q) || i.group.toLowerCase().contains(q)).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Tìm mặt hàng...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final it = list[i];
                return ListTile(
                  title: Text(it.name, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                  subtitle: Text([if (it.group.isNotEmpty) it.group, if (it.unit.isNotEmpty) 'Đơn vị: ${it.unit}'].join(' • ')),
                  trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  onTap: () => Navigator.pop(context, it),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

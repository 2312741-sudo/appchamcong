import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/store/providers/store_provider.dart';
import '../auth/app_permissions.dart';
import '../constants/app_colors.dart';
import '../services/cash_drawer_service.dart';

/// Nút MỞ KÉT trên đầu trang chủ (Chủ / Quản lý 1). Bấm → nhập PIN (lần đầu đặt PIN) + lý do →
/// gửi lệnh tới laptop chạy Trạm Mở Két (cùng wifi) → ghi nhật ký.
class CashDrawerButton extends ConsumerWidget {
  final Color iconColor;
  final Color? backgroundColor;

  const CashDrawerButton({super.key, this.iconColor = Colors.white, this.backgroundColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(currentMemberProvider);
    final storeId = ref.watch(currentStoreIdProvider);
    if (member == null || storeId == null || storeId.isEmpty || !AppPermissions.canOpenCashDrawer(member.role)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => const CashDrawerSheet(),
          ),
          child: Tooltip(
            message: 'Mở két tiền',
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(LucideIcons.vault, color: iconColor, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

class CashDrawerSheet extends ConsumerStatefulWidget {
  const CashDrawerSheet({super.key});

  @override
  ConsumerState<CashDrawerSheet> createState() => _CashDrawerSheetState();
}

class _CashDrawerSheetState extends ConsumerState<CashDrawerSheet> {
  // Đếm sai PIN dùng chung trong phiên app (chặn dò PIN)
  static int _wrong = 0;
  static DateTime? _lockedUntil;

  final _service = CashDrawerService();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  final _note = TextEditingController();
  String _reason = CashDrawerService.reasons.first;
  CashDrawerConfig? _cfg;
  String? _loadError;
  bool _busy = false;
  String? _msg;
  bool _msgOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pin.dispose();
    _pin2.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    try {
      final cfg = await _service.loadConfig(storeId);
      if (mounted) setState(() => _cfg = cfg);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Không đọc được cấu hình két: $e');
    }
  }

  void _show(String text, {bool ok = false}) => setState(() {
        _msg = text;
        _msgOk = ok;
      });

  Future<void> _submit() async {
    final cfg = _cfg;
    final storeId = ref.read(currentStoreIdProvider);
    final uid = ref.read(currentUserIdProvider);
    final member = ref.read(currentMemberProvider);
    if (cfg == null || storeId == null || uid == null) return;
    final lock = _lockedUntil;
    if (lock != null && DateTime.now().isBefore(lock)) {
      _show('Nhập sai PIN quá nhiều lần. Thử lại sau ${lock.difference(DateTime.now()).inSeconds + 1} giây.');
      return;
    }
    final pin = _pin.text.trim();
    if (!CashDrawerService.isValidPin(pin)) {
      _show('PIN gồm 4–6 chữ số');
      return;
    }
    final hasPin = cfg.pins.containsKey(uid);
    setState(() => _busy = true);
    try {
      if (!hasPin) {
        if (pin != _pin2.text.trim()) {
          _show('Hai lần nhập PIN không khớp');
          return;
        }
        await _service.setPin(storeId, uid, pin);
      } else if (!CashDrawerService.checkPin(cfg, storeId, uid, pin)) {
        _wrong++;
        if (_wrong >= 5) {
          _wrong = 0;
          _lockedUntil = DateTime.now().add(const Duration(minutes: 1));
        }
        _pin.clear();
        _show('Sai PIN');
        return;
      }
      _wrong = 0;
      final name = member?.name ?? 'Quản lý';
      final reason = CashDrawerService.fullReason(_reason, _note.text);
      final err = await _service.sendOpen(cfg, name);
      try {
        await _service.log(storeId,
            uid: uid, name: name, role: member?.role.name ?? '', reason: reason, ok: err == null, error: err);
      } catch (_) {
        // Không ghi được nhật ký (vd chưa cập nhật luật Firestore) — không chặn việc mở két
      }
      if (!mounted) return;
      if (err != null) {
        _show(err);
      } else {
        HapticFeedback.mediumImpact();
        _show('Đã mở két', ok: true);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      _show('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final cfg = _cfg;
    final hasPin = cfg != null && uid != null && cfg.pins.containsKey(uid);
    final inset = MediaQuery.of(context).viewInsets.bottom;

    Widget body;
    if (_loadError != null) {
      body = Text(_loadError!, style: const TextStyle(color: AppColors.danger));
    } else if (cfg == null) {
      body = const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    } else if (!cfg.isPaired) {
      body = const Text(
        'Chưa ghép nối laptop mở két.\n\nTrên laptop cắm máy in KV804: cài phần mềm Trạm Mở Két, mở web Chấm Công '
        'trên chính laptop đó → Két tiền → Ghép nối với laptop này.',
        style: TextStyle(fontSize: 14, fontFamily: 'BeVietnamPro'),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, letterSpacing: 8),
            decoration: InputDecoration(
              labelText: hasPin ? 'PIN mở két của bạn' : 'Đặt PIN mở két (4–6 số)',
              counterText: '',
              border: const OutlineInputBorder(),
            ),
          ),
          if (!hasPin) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _pin2,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8),
              decoration: const InputDecoration(labelText: 'Nhập lại PIN', counterText: '', border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Lý do', border: OutlineInputBorder()),
            items: [for (final r in CashDrawerService.reasons) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => setState(() => _reason = v ?? _reason),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: _reason == 'Khác' ? 'Ghi rõ lý do' : 'Ghi chú (không bắt buộc)',
              counterText: '',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 8),
            Text(_msg!,
                style: TextStyle(
                    color: _msgOk ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.vault),
            label: Text(hasPin ? 'Mở két' : 'Lưu PIN & mở két'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 8),
          Text(
            'Điện thoại phải cùng wifi với laptop ${cfg.computer.isEmpty ? '' : '(${cfg.computer}) '}và laptop đang bật. Mỗi lần mở đều được ghi nhật ký.',
            style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'BeVietnamPro'),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.vault, size: 22),
                SizedBox(width: 8),
                Text('Mở két tiền', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'BeVietnamPro')),
              ],
            ),
            const SizedBox(height: 16),
            body,
          ],
        ),
      ),
    );
  }
}

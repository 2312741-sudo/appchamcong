import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/store/providers/store_provider.dart';
import '../../models/member_model.dart';
import '../auth/app_permissions.dart';
import '../constants/app_colors.dart';
import '../services/cash_drawer_service.dart';

/// Yêu cầu mở két của cửa hàng (dùng chung cho nút trên dashboard)
final cashDrawerRequestsProvider = StreamProvider.autoDispose.family<List<CashDrawerRequest>, String>(
  (ref, storeId) => CashDrawerService().watchRequests(storeId),
);

/// Nút MỞ KÉT trên đầu trang chủ (Chủ / Quản lý). Chủ: chấm đỏ khi có yêu cầu đang chờ mã.
class CashDrawerButton extends ConsumerWidget {
  final Color iconColor;
  final Color? backgroundColor;

  const CashDrawerButton({super.key, this.iconColor = Colors.white, this.backgroundColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(currentMemberProvider);
    final storeId = ref.watch(currentStoreIdProvider);
    final uid = ref.watch(currentUserIdProvider);
    if (member == null || storeId == null || storeId.isEmpty || !AppPermissions.canOpenCashDrawer(member.role)) {
      return const SizedBox.shrink();
    }
    final isOwner = member.role == UserRole.owner;
    Widget icon = Icon(LucideIcons.vault, color: iconColor, size: 24);
    if (isOwner) {
      icon = Consumer(
        builder: (context, ref, _) {
          final list = ref.watch(cashDrawerRequestsProvider(storeId)).valueOrNull ?? const <CashDrawerRequest>[];
          final n = list.where((r) => r.isAlive() && r.uid != uid).length;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(LucideIcons.vault, color: iconColor, size: 24),
              if (n > 0)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text('$n',
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, height: 1)),
                    ),
                  ),
                ),
            ],
          );
        },
      );
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
            // Dùng context CỦA bảng (sheetCtx) để biết bàn phím đang mở → đẩy ô nhập mã lên trên bàn phím.
            // (Trước đây dùng context của màn phía sau nên bàn phím che mất ô nhập.)
            builder: (sheetCtx) => AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
              child: const SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: CashDrawerPanel(closeOnSuccess: true),
              ),
            ),
          ),
          child: Tooltip(message: 'Mở két tiền', child: Padding(padding: const EdgeInsets.all(8), child: icon)),
        ),
      ),
    );
  }
}

/// Màn KÉT TIỀN (mở từ thông báo "Yêu cầu mở két" của Chủ)
class CashDrawerScreen extends StatelessWidget {
  const CashDrawerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Két tiền')),
      body: const SafeArea(
        child: SingleChildScrollView(padding: EdgeInsets.all(20), child: CashDrawerPanel(showTitle: false)),
      ),
    );
  }
}

/// Nội dung mở két:
///  - Chủ: mã 6 số của các yêu cầu đang chờ (gửi cho quản lý) + tự mở ngay.
///  - Quản lý (QL1 / QL2): gửi yêu cầu cho Chủ → nhập mã Chủ gửi → két bật.
class CashDrawerPanel extends ConsumerStatefulWidget {
  final bool closeOnSuccess;
  final bool showTitle;

  const CashDrawerPanel({super.key, this.closeOnSuccess = false, this.showTitle = true});

  @override
  ConsumerState<CashDrawerPanel> createState() => _CashDrawerPanelState();
}

class _CashDrawerPanelState extends ConsumerState<CashDrawerPanel> {
  final _service = CashDrawerService();
  final _code = TextEditingController();
  final _note = TextEditingController();
  String _reason = CashDrawerService.reasons.first;
  CashDrawerConfig? _cfg;
  String? _secret;
  String? _loadError;
  bool _busy = false;
  String? _msg;
  bool _msgOk = false;
  List<CashDrawerRequest> _requests = const [];
  StreamSubscription<List<CashDrawerRequest>>? _sub;
  Timer? _tick;

  bool get _isOwner => ref.read(currentMemberProvider)?.role == UserRole.owner;

  @override
  void initState() {
    super.initState();
    _load();
    // Cập nhật "còn X phút" / bỏ yêu cầu hết hạn
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    _code.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    try {
      final cfg = await _service.loadConfig(storeId);
      final secret = _isOwner ? await _service.loadOwnerSecret(storeId) : null;
      if (!mounted) return;
      setState(() {
        _cfg = cfg;
        _secret = secret;
      });
      _sub = _service.watchRequests(storeId).listen((rs) {
        if (mounted) setState(() => _requests = rs);
      }, onError: (_) {});
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Không đọc được dữ liệu két: $e');
    }
  }

  void _show(String text, {bool ok = false}) => setState(() {
        _msg = text;
        _msgOk = ok;
      });

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await fn();
    } catch (e) {
      _show('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish(String storeId, CashDrawerRequest req, String? err) async {
    final member = ref.read(currentMemberProvider);
    final uid = ref.read(currentUserIdProvider) ?? '';
    try {
      await _service.log(storeId,
          uid: uid,
          name: member?.name ?? 'Quản lý',
          role: member?.role.name ?? '',
          reason: req.reason,
          ok: err == null,
          error: err,
          requestId: req.id);
    } catch (_) {
      // Không ghi được nhật ký (vd chưa cập nhật luật Firestore) — không chặn việc mở két
    }
    if (!mounted) return;
    if (err != null) {
      _show(err);
      return;
    }
    try {
      await _service.setRequestStatus(storeId, req.id, 'opened');
    } catch (_) {}
    HapticFeedback.mediumImpact();
    _show('Đã mở két', ok: true);
    if (widget.closeOnSuccess) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  // CHỦ: mở ngay (tự tính mã từ khóa bí mật)
  Future<void> _ownerOpen() => _run(() async {
        final storeId = ref.read(currentStoreIdProvider);
        final cfg = _cfg;
        final secret = _secret;
        if (storeId == null || cfg == null) return;
        if (secret == null) {
          _show('Chủ chưa có khóa mở két: ghép nối laptop trên web (mở trên chính laptop cắm máy in → Két tiền).');
          return;
        }
        final member = ref.read(currentMemberProvider);
        final req = await _service.createRequest(storeId,
            uid: ref.read(currentUserIdProvider) ?? '',
            name: member?.name ?? 'Chủ',
            role: member?.role.name ?? 'owner',
            reason: CashDrawerService.fullReason(_reason, _note.text),
            notifyOwner: false);
        final err = await _service.sendOpen(cfg,
            nonce: req.nonce, otp: CashDrawerService.otpFor(secret, req.nonce), byName: member?.name ?? 'Chủ');
        await _finish(storeId, req, err);
      });

  // QUẢN LÝ: gửi yêu cầu cho Chủ
  Future<void> _sendRequest() => _run(() async {
        final storeId = ref.read(currentStoreIdProvider);
        if (storeId == null) return;
        final member = ref.read(currentMemberProvider);
        await _service.createRequest(storeId,
            uid: ref.read(currentUserIdProvider) ?? '',
            name: member?.name ?? 'Quản lý',
            role: member?.role.name ?? '',
            reason: CashDrawerService.fullReason(_reason, _note.text),
            notifyOwner: true);
        _show('Đã gửi yêu cầu cho Chủ. Nhập mã 6 số Chủ gửi cho bạn.', ok: true);
      });

  // QUẢN LÝ: nhập mã
  Future<void> _submitCode(CashDrawerRequest req) => _run(() async {
        final storeId = ref.read(currentStoreIdProvider);
        final cfg = _cfg;
        if (storeId == null || cfg == null) return;
        final code = _code.text.trim();
        if (!CashDrawerService.isValidOtp(code)) {
          _show('Mã gồm 6 số');
          return;
        }
        final err = await _service.sendOpen(cfg,
            nonce: req.nonce, otp: code, byName: ref.read(currentMemberProvider)?.name ?? 'Quản lý');
        if (err != null) _code.clear();
        await _finish(storeId, req, err);
      });

  Widget _reasonFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
        ],
      );

  Widget _ownerCodes(String? myUid) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final alive = _requests.where((r) => r.isAlive(now) && r.uid != myUid).toList();
    if (alive.isEmpty) return const SizedBox.shrink();
    final secret = _secret;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Yêu cầu đang chờ mã — gửi mã cho đúng người:',
            style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
        const SizedBox(height: 8),
        if (secret == null)
          const Text('Chủ chưa có khóa mở két: ghép nối laptop trên web (mở trên chính laptop cắm máy in).',
              style: TextStyle(color: AppColors.danger))
        else
          for (final r in alive)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${r.reason} • còn ${r.minutesLeft(now)} phút',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  SelectableText(CashDrawerService.otpFor(secret, r.nonce),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 3)),
                  IconButton(
                    tooltip: 'Chép mã',
                    icon: const Icon(LucideIcons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: CashDrawerService.otpFor(secret, r.nonce)));
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Đã chép mã')));
                    },
                  ),
                  IconButton(
                    tooltip: 'Từ chối',
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () {
                      final storeId = ref.read(currentStoreIdProvider);
                      if (storeId != null) _service.setRequestStatus(storeId, r.id, 'cancelled').catchError((_) {});
                    },
                  ),
                ],
              ),
            ),
        const Divider(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final member = ref.watch(currentMemberProvider);
    final isOwner = member?.role == UserRole.owner;
    final cfg = _cfg;
    final now = DateTime.now().millisecondsSinceEpoch;
    final myPending = isOwner
        ? null
        : _requests.where((r) => r.uid == uid && r.isAlive(now)).cast<CashDrawerRequest?>().firstWhere((_) => true, orElse: () => null);

    final children = <Widget>[];
    if (widget.showTitle) {
      children.addAll(const [
        Row(children: [
          Icon(LucideIcons.vault, size: 22),
          SizedBox(width: 8),
          Text('Mở két tiền', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'BeVietnamPro')),
        ]),
        SizedBox(height: 16),
      ]);
    }

    if (member == null || !AppPermissions.canOpenCashDrawer(member.role)) {
      children.add(const Text('Chỉ Chủ và Quản lý dùng được tính năng két tiền.'));
    } else if (_loadError != null) {
      children.add(Text(_loadError!, style: const TextStyle(color: AppColors.danger)));
    } else if (cfg == null) {
      children.add(const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())));
    } else if (!cfg.isPaired) {
      children.add(const Text(
        'Chưa ghép nối laptop mở két.\n\nTrên laptop cắm máy in KV804: cài phần mềm Trạm Mở Két, CHỦ mở web Chấm Công '
        'trên chính laptop đó → Két tiền → Ghép nối với laptop này.',
        style: TextStyle(fontSize: 14, fontFamily: 'BeVietnamPro'),
      ));
    } else if (isOwner) {
      children.addAll([
        _ownerCodes(uid),
        _reasonFields(),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: _busy ? null : _ownerOpen,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(LucideIcons.vault),
          label: const Text('Mở két ngay'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
      ]);
    } else if (myPending == null) {
      children.addAll([
        const Text('Gửi yêu cầu cho Chủ. Chủ sẽ gửi bạn mã 6 số dùng 1 lần (hết hạn sau 15 phút).',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        _reasonFields(),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: _busy ? null : _sendRequest,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(LucideIcons.send),
          label: const Text('Gửi yêu cầu cho Chủ'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
      ]);
    } else {
      children.addAll([
        Text('Yêu cầu: ${myPending.reason} • còn ${myPending.minutesLeft(now)} phút.\nNhập mã 6 số Chủ gửi cho bạn:',
            style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(counterText: '', border: OutlineInputBorder(), hintText: '••••••'),
          onSubmitted: (_) => _submitCode(myPending),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : () => _submitCode(myPending),
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(LucideIcons.vault),
          label: const Text('Mở két'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final storeId = ref.read(currentStoreIdProvider);
                    if (storeId != null) await _service.setRequestStatus(storeId, myPending.id, 'cancelled');
                  }),
          child: const Text('Hủy yêu cầu'),
        ),
      ]);
    }

    if (_msg != null) {
      children.addAll([
        const SizedBox(height: 8),
        Text(_msg!,
            style: TextStyle(
                color: _msgOk ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w700, fontFamily: 'BeVietnamPro')),
      ]);
    }
    if (cfg != null && cfg.isPaired) {
      children.addAll([
        const SizedBox(height: 8),
        Text(
          'Điện thoại phải cùng wifi với laptop ${cfg.computer.isEmpty ? '' : '(${cfg.computer}) '}và laptop đang bật. '
          'Mỗi mã chỉ mở 1 lần; mọi lần mở đều được ghi nhật ký.',
          style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'BeVietnamPro'),
        ),
      ]);
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/store_provider.dart';

class StoreSettingsScreen extends ConsumerStatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  ConsumerState<StoreSettingsScreen> createState() =>
      _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends ConsumerState<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  
  String? _networkIP;
  bool _isFetchingIP = false;

  double _radius = 100;
  double? _lat;
  double? _lng;
  bool _isSaving = false;
  bool _isFetchingLocation = false;
  bool _isRegeneratingCode = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _initFromStore(storeModel) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = storeModel.name;
    _addressCtrl.text = storeModel.address ?? '';
    _networkIP = storeModel.networkIP;
    _radius = storeModel.radiusMeters.toDouble();
    _lat = storeModel.latitude;
    _lng = storeModel.longitude;
  }

  Future<void> _fetchNetworkIP() async {
    setState(() => _isFetchingIP = true);
    try {
      final request = await HttpClient().getUrl(Uri.parse('https://api.ipify.org?format=json'));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody);
      
      setState(() {
        _networkIP = data['ip'];
      });
      _showSuccess('Lấy IP mạng thành công');
    } catch (e) {
      _showError('Không thể lấy IP mạng: $e');
    } finally {
      if (mounted) setState(() => _isFetchingIP = false);
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Vui lòng bật dịch vụ vị trí');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _showError('Ứng dụng cần quyền vị trí');
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _showError('Vui lòng cấp quyền vị trí trong cài đặt');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _showSuccess('Đã cập nhật vị trí GPS');
    } catch (e) {
      _showError('Không lấy được vị trí');
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _save(String storeId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(storeRepositoryProvider);
      await repo.updateStoreSettings(storeId, {
        'name': _nameCtrl.text.trim(),
        'address':
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'networkIP': _networkIP,
        'latitude': _lat,
        'longitude': _lng,
        'radiusMeters': _radius.round(),
      });
      _showSuccess('Đã lưu thay đổi');
    } catch (e) {
      _showError('Lưu thất bại: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _regenerateCode(String storeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tạo mã mới',
            style: TextStyle(
                fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w700)),
        content: const Text(
          'Mã cũ sẽ hết hiệu lực. Nhân viên cần dùng mã mới để tham gia. Tiếp tục?',
          style: TextStyle(fontFamily: 'BeVietnamPro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Hủy', style: TextStyle(fontFamily: 'BeVietnamPro')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Tạo mã mới',
                style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isRegeneratingCode = true);
    try {
      final repo = ref.read(storeRepositoryProvider);
      await repo.regenerateStoreCode(storeId);
      _showSuccess('Đã tạo mã mới');
    } catch (e) {
      _showError('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isRegeneratingCode = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(currentStoreProvider);

    return storeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Lỗi: $e')),
      ),
      data: (store) {
        if (store == null) {
          return const Scaffold(
            body: Center(child: Text('Không tìm thấy cửa hàng')),
          );
        }
        _initFromStore(store);
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: const Text(
              'Cài đặt cửa hàng',
              style: TextStyle(
                  fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w700),
            ),
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(title: 'Thông tin cơ bản'),
                  const SizedBox(height: 12),
                  const _Label('Tên cửa hàng *'),
                  const SizedBox(height: 6),
                  _Field(
                    controller: _nameCtrl,
                    hint: 'Tên cửa hàng',
                    icon: Icons.store_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tên'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  const _Label('Địa chỉ'),
                  const SizedBox(height: 6),
                  _Field(
                    controller: _addressCtrl,
                    hint: 'Địa chỉ cửa hàng',
                    icon: Icons.location_on_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  const _Label('Địa chỉ IP Mạng'),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _isFetchingIP ? null : _fetchNetworkIP,
                    icon: _isFetchingIP
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.wifi_rounded),
                    label: Text(
                      _isFetchingIP ? 'Đang lấy IP...' : 'Lấy IP mạng hiện tại',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      textStyle: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (_networkIP != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'IP: $_networkIP',
                            style: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.danger, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _networkIP = null),
                          )
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  const _SectionHeader(title: 'Vị trí GPS'),
                  const SizedBox(height: 12),
                  if (_lat != null && _lng != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                            style: const TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontSize: 12,
                                color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _isFetchingLocation ? null : _fetchLocation,
                    icon: _isFetchingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary))
                        : const Icon(Icons.my_location_rounded),
                    label: Text(_isFetchingLocation
                        ? 'Đang lấy...'
                        : 'Cập nhật vị trí GPS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Label('Bán kính: ${_radius.round()}m'),
                  Slider(
                    value: _radius,
                    min: 50,
                    max: 500,
                    divisions: 45,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border,
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                  const SizedBox(height: 20),

                  const _SectionHeader(title: 'Mã cửa hàng'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                store.code,
                                style: const TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 6,
                                  color: AppColors.neutral,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded,
                                  color: AppColors.info),
                              tooltip: 'Sao chép mã',
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: store.code));
                                _showSuccess('Đã sao chép mã: ${store.code}');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isRegeneratingCode
                                ? null
                                : () => _regenerateCode(store.id),
                            icon: _isRegeneratingCode
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary))
                                : const Icon(Icons.refresh_rounded),
                            label: const Text('Tạo mã mới'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const _SectionHeader(title: 'Mã QR'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: store.code,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          store.code,
                          style: const TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                context.push('/qr-display'),
                            icon: const Icon(Icons.open_in_full_rounded),
                            label: const Text('Xem mã QR toàn màn hình'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Shift Settings
                  const _SectionHeader(title: 'Quản lý ca làm'),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => context.push('/shift-settings'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.schedule_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cài đặt ca làm',
                                    style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.neutral)),
                                SizedBox(height: 2),
                                Text('Thêm, sửa, xóa ca và giờ làm',
                                    style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () => _save(store.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Text(
                              'Lưu thay đổi',
                              style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.neutral,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'BeVietnamPro', color: AppColors.textDisabled),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/location_utils.dart';
import '../../../models/store_model.dart';
import '../../../app/router.dart';
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
  final _deptNameCtrl = TextEditingController();
  final _deptShortCtrl = TextEditingController();
  final _wifiNameCtrl = TextEditingController();
  
  String? _networkIP;
  String? _detectedSsid;
  bool _isFetchingIP = false;
  List<StoreWifi> _wifis = [];

  bool _deliveryEnabled = true;
  final _deliveryAllowanceCtrl = TextEditingController();
  bool _giaoHangEnabled = true;
  final _giaoHangAllowanceCtrl = TextEditingController();

  double _radius = 100;
  double? _lat;
  double? _lng;
  bool _isSaving = false;
  bool _isFetchingLocation = false;
  bool _isRegeneratingCode = false;
  bool _initialized = false;
  List<DepartmentDefinition> _departments = [];
  bool _deptSelectionEnabled = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _deptNameCtrl.dispose();
    _deptShortCtrl.dispose();
    _wifiNameCtrl.dispose();
    _deliveryAllowanceCtrl.dispose();
    _giaoHangAllowanceCtrl.dispose();
    super.dispose();
  }

  void _initFromStore(StoreModel storeModel) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = storeModel.name;
    _addressCtrl.text = storeModel.address ?? '';
    _networkIP = storeModel.networkIP;
    _wifis = List.from(storeModel.wifis);
    _deliveryEnabled = storeModel.deliveryEnabled;
    _deliveryAllowanceCtrl.text = (storeModel.deliveryAllowance ?? 0).toString();
    _giaoHangEnabled = storeModel.giaoHangEnabled;
    _giaoHangAllowanceCtrl.text = (storeModel.giaoHangAllowance ?? 0).toString();
    _radius = storeModel.radiusMeters.toDouble();
    _lat = storeModel.latitude;
    _lng = storeModel.longitude;
    _departments = List.from(storeModel.departments);
    _deptSelectionEnabled = storeModel.departmentSelectionEnabled;
  }

  Future<void> _fetchNetworkIP() async {
    if (mounted) setState(() => _isFetchingIP = true);
    try {
      final details = await LocationUtils.getCurrentWifiDetails();
      if (details.ip == null || details.ip!.isEmpty) {
        throw Exception('Không lấy được IP mạng. Vui lòng đảm bảo thiết bị đang kết nối WiFi hoặc internet.');
      }
      
      if (mounted) {
        setState(() {
          _networkIP = details.ip;
          if (details.ssid != null && details.ssid!.isNotEmpty) {
            _detectedSsid = details.ssid;
            _wifiNameCtrl.text = details.ssid!;
          } else {
            _detectedSsid = null;
            _wifiNameCtrl.text = 'WiFi ${_wifis.length + 1}';
          }
        });
        _showSuccess(_detectedSsid != null
            ? 'Đã lấy WiFi: $_detectedSsid'
            : 'Đã lấy IP mạng thành công');
      }
    } catch (e) {
      _showError('Không thể lấy thông tin WiFi: $e');
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
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
        _showSuccess('Đã cập nhật vị trí GPS');
      }
    } catch (e) {
      _showError('Không lấy được vị trí');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
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
        'wifis': _wifis.map((w) => w.toJson()).toList(),
        'deliveryEnabled': _deliveryEnabled,
        'deliveryAllowance': num.tryParse(_deliveryAllowanceCtrl.text.trim()) ?? 0,
        'giaoHangEnabled': _giaoHangEnabled,
        'giaoHangAllowance': num.tryParse(_giaoHangAllowanceCtrl.text.trim()) ?? 0,
        'latitude': _lat,
        'longitude': _lng,
        'radiusMeters': _radius.round(),
        'departments': _departments.map((d) => d.toJson()).toList(),
        'departmentSelectionEnabled': _deptSelectionEnabled,
      });
      _showSuccess('Đã lưu thay đổi');
    } catch (e) {
      _showError('Lưu thất bại: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddDepartmentDialog() {
    _deptNameCtrl.clear();
    _deptShortCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thêm bộ phận', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _deptNameCtrl,
              decoration: const InputDecoration(labelText: 'Tên bộ phận *', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deptShortCtrl,
              decoration: const InputDecoration(labelText: 'Tên viết tắt (VD: KD, KT)', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.characters,
              maxLength: 5,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              final name = _deptNameCtrl.text.trim();
              if (name.isEmpty) return;
              final shortName = _deptShortCtrl.text.trim().toUpperCase();
              final id = name.toLowerCase().replaceAll(' ', '_') + '_' + DateTime.now().millisecondsSinceEpoch.toString();
              setState(() {
                _departments.add(DepartmentDefinition(id: id, name: name, shortName: shortName.isEmpty ? name.substring(0, name.length > 3 ? 3 : name.length).toUpperCase() : shortName));
              });
              Navigator.pop(ctx);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
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

  void _showEditWifiDialog(int index, StoreWifi wifi) {
    final ctrl = TextEditingController(text: wifi.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi tên nhận diện WiFi',
            style: TextStyle(
                fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IP: ${wifi.ip}',
                style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    color: AppColors.textSecondary,
                    fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Tên WiFi',
                hintText: 'Nhập tên nhận diện...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ',
                  style: TextStyle(fontFamily: 'BeVietnamPro'))),
          ElevatedButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  _wifis[index] = StoreWifi(
                    name: newName,
                    ip: wifi.ip,
                    createdAt: wifi.createdAt,
                  );
                });
                _showSuccess('Đã đổi tên WiFi');
              }
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
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
                      _isFetchingIP ? 'Đang lấy thông tin...' : 'Lấy WiFi mạng hiện tại',
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
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _detectedSsid != null
                              ? AppColors.success.withOpacity(0.5)
                              : Colors.orange.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _detectedSsid != null
                                    ? Icons.wifi_rounded
                                    : Icons.wifi_find_rounded,
                                color: _detectedSsid != null
                                    ? AppColors.success
                                    : Colors.orange,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _detectedSsid != null
                                      ? 'Đã nhận diện: $_detectedSsid'
                                      : 'Chưa đọc được SSID tự động (có thể tự đặt tên)',
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontSize: 13,
                                    color: _detectedSsid != null
                                        ? AppColors.success
                                        : Colors.orange.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: AppColors.danger, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => setState(() {
                                  _networkIP = null;
                                  _detectedSsid = null;
                                  _wifiNameCtrl.clear();
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _wifiNameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Tên nhận diện WiFi',
                              hintText: 'VD: WiFi Tầng 1 / Quầy Thu Ngân',
                              prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                            style: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.router_rounded,
                                    size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'IP Router (WAN): $_networkIP',
                                  style: const TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_wifis.length >= 10) {
                                  _showError('Đã đạt tối đa 10 địa chỉ WiFi cho phép.');
                                  return;
                                }
                                if (_wifis.any((w) => w.ip.trim() == _networkIP!.trim())) {
                                  _showError('Địa chỉ IP này đã tồn tại trong danh sách.');
                                  return;
                                }
                                final nameToSave = _wifiNameCtrl.text.trim().isNotEmpty
                                    ? _wifiNameCtrl.text.trim()
                                    : (_detectedSsid ?? 'WiFi ${_wifis.length + 1}');
                                setState(() {
                                  _wifis.add(StoreWifi(
                                    name: nameToSave,
                                    ip: _networkIP!,
                                    createdAt: DateTime.now(),
                                  ));
                                  _networkIP = null;
                                  _detectedSsid = null;
                                  _wifiNameCtrl.clear();
                                });
                                _showSuccess('Đã thêm "$nameToSave" vào danh sách');
                              },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Thêm vào danh sách cho phép (Tối đa 10)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Label('Danh sách WiFi cho phép (${_wifis.length}/10)'),
                      if (_wifis.isNotEmpty)
                        Text(
                          '${10 - _wifis.length} vị trí còn lại',
                          style: const TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_wifis.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.wifi_off_rounded, color: AppColors.textSecondary, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Chưa cấu hình WiFi nào.\nKết nối mạng tại điểm làm việc và nhấn "Lấy WiFi mạng hiện tại" để thêm.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._wifis.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final wifi = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wifi.name,
                                    style: const TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'IP: ${wifi.ip}',
                                    style: const TextStyle(
                                      fontFamily: 'BeVietnamPro',
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                              tooltip: 'Đổi tên WiFi',
                              onPressed: () => _showEditWifiDialog(idx, wifi),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                              tooltip: 'Xoá WiFi này',
                              onPressed: () {
                                setState(() => _wifis.removeAt(idx));
                                _showSuccess('Đã xoá WiFi');
                              },
                            ),
                          ],
                        ),
                      );
                    }),
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
                                context.push(AppRoutes.qrDisplay),
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
                  const SizedBox(height: 20),

                  // Department Management
                  const _SectionHeader(title: 'Quản lý bộ phận'),
                  const SizedBox(height: 8),
                  const Text(
                    'Định nghĩa các bộ phận để NV/QL chọn khi đăng ký ca làm.',
                    style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  // Toggle bật/tắt chọn bộ phận
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cho phép NV/QL chọn bộ phận', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        _deptSelectionEnabled ? 'Đang bật – NV/QL thấy danh sách bộ phận khi đăng ký ca' : 'Đang tắt – NV/QL không thấy tùy chọn bộ phận',
                        style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12),
                      ),
                      value: _deptSelectionEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _deptSelectionEnabled = val),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_departments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text('Chưa có bộ phận nào. Bấm + để thêm.', style: TextStyle(fontFamily: 'BeVietnamPro', color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    ...List.generate(_departments.length, (i) {
                      final dept = _departments[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(dept.shortName, style: const TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(dept.name, style: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 14, fontWeight: FontWeight.w600))),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                              onPressed: () => setState(() => _departments.removeAt(i)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _showAddDepartmentDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm bộ phận', style: TextStyle(fontFamily: 'BeVietnamPro')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Cài đặt Giao hàng / Chở hàng
                  const _SectionHeader(title: 'Cài đặt Phụ cấp'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cho phép đăng ký Chở hàng', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Tích vào lịch để tính phụ cấp chở hàng', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12)),
                      value: _deliveryEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _deliveryEnabled = val),
                    ),
                  ),
                  if (_deliveryEnabled) ...[
                    const SizedBox(height: 12),
                    const _Label('Mức phụ cấp Chở hàng (VNĐ)'),
                    const SizedBox(height: 6),
                    _Field(
                      controller: _deliveryAllowanceCtrl,
                      hint: 'VD: 15000',
                      icon: Icons.monetization_on_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cho phép đăng ký Giao hàng', style: TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Tích vào lịch để tính phụ cấp giao hàng', style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 12)),
                      value: _giaoHangEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _giaoHangEnabled = val),
                    ),
                  ),
                  if (_giaoHangEnabled) ...[
                    const SizedBox(height: 12),
                    const _Label('Mức phụ cấp Giao hàng (VNĐ)'),
                    const SizedBox(height: 6),
                    _Field(
                      controller: _giaoHangAllowanceCtrl,
                      hint: 'VD: 15000',
                      icon: Icons.monetization_on_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ],
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
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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

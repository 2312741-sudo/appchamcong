import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../features/store/screens/shift_settings_screen.dart';

class DepartmentDefinition extends Equatable {
  final String id;
  final String name;
  final String shortName;

  const DepartmentDefinition({
    required this.id,
    required this.name,
    required this.shortName,
  });

  factory DepartmentDefinition.fromJson(Map<String, dynamic> json) => DepartmentDefinition(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    shortName: json['shortName'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'shortName': shortName,
  };

  @override
  List<Object?> get props => [id, name, shortName];
}

class StoreWifi extends Equatable {
  final String name;
  final String ip;
  final DateTime? createdAt;

  const StoreWifi({
    required this.name,
    required this.ip,
    this.createdAt,
  });

  factory StoreWifi.fromJson(Map<String, dynamic> json) => StoreWifi(
    name: json['name'] as String? ?? 'WiFi',
    ip: json['ip'] as String? ?? '',
    createdAt: json['createdAt'] is Timestamp
        ? (json['createdAt'] as Timestamp).toDate()
        : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'ip': ip,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
  };

  @override
  List<Object?> get props => [name, ip, createdAt];
}

class StoreModel extends Equatable {
  final String id;
  final String name;
  final String code; // 6-char alphanumeric
  final String ownerId;
  final String? address;
  final String? networkIP;
  final double? latitude;
  final double? longitude;
  final int radiusMeters; // default 100
  final DateTime createdAt;
  final List<ShiftDefinition> customShifts;
  final List<DepartmentDefinition> departments;
  final num? deliveryAllowance;
  final num? giaoHangAllowance;
  final bool deliveryEnabled;
  final bool giaoHangEnabled;
  final String? themeColor;
  final bool departmentSelectionEnabled; // cho phép NV/QL chọn bộ phận khi đăng ký ca
  final List<StoreWifi> wifis;
  final String status;

  bool get isDeleted => status == 'deleted';

  const StoreModel({
    required this.id,
    required this.name,
    required this.code,
    required this.ownerId,
    this.address,
    this.networkIP,
    this.latitude,
    this.longitude,
    this.radiusMeters = 100,
    required this.createdAt,
    this.customShifts = const [],
    this.departments = const [],
    this.deliveryAllowance,
    this.giaoHangAllowance,
    this.deliveryEnabled = true,
    this.giaoHangEnabled = true,
    this.themeColor,
    this.departmentSelectionEnabled = true,
    this.wifis = const [],
    this.status = 'active',
  });

  factory StoreModel.fromJson(Map<String, dynamic> json, String id) {
    final legacyIp = json['networkIP'] as String?;
    final rawWifis = (json['wifis'] as List<dynamic>?)
            ?.map((e) => StoreWifi.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    // Auto-migration: if legacy networkIP exists and is not yet in wifis list, include it
    final resolvedWifis = List<StoreWifi>.from(rawWifis);
    if (legacyIp != null && legacyIp.trim().isNotEmpty) {
      if (!resolvedWifis.any((w) => w.ip.trim() == legacyIp.trim())) {
        resolvedWifis.insert(
          0,
          StoreWifi(
            name: 'WiFi Chính',
            ip: legacyIp.trim(),
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    return StoreModel(
      id: id,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      address: json['address'] as String?,
      networkIP: legacyIp,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusMeters: (json['radiusMeters'] as int?) ?? 100,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate().toUtc()
          : DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now().toUtc(),
      customShifts: (json['customShifts'] as List<dynamic>?)
              ?.map((e) => ShiftDefinition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      departments: (json['departments'] as List<dynamic>?)
              ?.map((e) => DepartmentDefinition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      deliveryAllowance: json['deliveryAllowance'] as num?,
      giaoHangAllowance: json['giaoHangAllowance'] as num?,
      deliveryEnabled: json['deliveryEnabled'] as bool? ?? true,
      giaoHangEnabled: json['giaoHangEnabled'] as bool? ?? true,
      themeColor: json['themeColor'] as String?,
      departmentSelectionEnabled: json['departmentSelectionEnabled'] as bool? ?? true,
      wifis: resolvedWifis,
      status: json['status'] as String? ?? 'active',
    );
  }

  factory StoreModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreModel.fromJson(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'ownerId': ownerId,
      'address': address,
      'networkIP': networkIP,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'createdAt': Timestamp.fromDate(createdAt),
      'customShifts': customShifts.map((s) => s.toJson()).toList(),
      'departments': departments.map((d) => d.toJson()).toList(),
      'deliveryAllowance': deliveryAllowance,
      'giaoHangAllowance': giaoHangAllowance,
      'deliveryEnabled': deliveryEnabled,
      'giaoHangEnabled': giaoHangEnabled,
      'themeColor': themeColor,
      'departmentSelectionEnabled': departmentSelectionEnabled,
      'wifis': wifis.map((w) => w.toJson()).toList(),
      'status': status,
    };
  }

  StoreModel copyWith({
    String? id,
    String? name,
    String? code,
    String? ownerId,
    String? address,
    String? networkIP,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    DateTime? createdAt,
    List<ShiftDefinition>? customShifts,
    List<DepartmentDefinition>? departments,
    num? deliveryAllowance,
    num? giaoHangAllowance,
    bool? deliveryEnabled,
    bool? giaoHangEnabled,
    String? themeColor,
    bool? departmentSelectionEnabled,
    List<StoreWifi>? wifis,
    String? status,
    bool clearAddress = false,
    bool clearNetworkIP = false,
    bool clearLocation = false,
  }) {
    return StoreModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      ownerId: ownerId ?? this.ownerId,
      address: clearAddress ? null : (address ?? this.address),
      networkIP: clearNetworkIP ? null : (networkIP ?? this.networkIP),
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      radiusMeters: radiusMeters ?? this.radiusMeters,
      createdAt: createdAt ?? this.createdAt,
      customShifts: customShifts ?? this.customShifts,
      departments: departments ?? this.departments,
      deliveryAllowance: deliveryAllowance ?? this.deliveryAllowance,
      giaoHangAllowance: giaoHangAllowance ?? this.giaoHangAllowance,
      deliveryEnabled: deliveryEnabled ?? this.deliveryEnabled,
      giaoHangEnabled: giaoHangEnabled ?? this.giaoHangEnabled,
      themeColor: themeColor ?? this.themeColor,
      departmentSelectionEnabled: departmentSelectionEnabled ?? this.departmentSelectionEnabled,
      wifis: wifis ?? this.wifis,
      status: status ?? this.status,
    );
  }

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasWifi => (networkIP != null && networkIP!.isNotEmpty) || wifis.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        name,
        code,
        ownerId,
        address,
        networkIP,
        latitude,
        longitude,
        radiusMeters,
        createdAt,
        customShifts,
        departments,
        deliveryAllowance,
        giaoHangAllowance,
        deliveryEnabled,
        giaoHangEnabled,
        themeColor,
        departmentSelectionEnabled,
        wifis,
        status,
      ];

  @override
  String toString() =>
      'StoreModel(id: $id, name: $name, code: $code, ownerId: $ownerId, status: $status)';
}

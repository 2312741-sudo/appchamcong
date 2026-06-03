import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

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
  });

  factory StoreModel.fromJson(Map<String, dynamic> json, String id) {
    return StoreModel(
      id: id,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      address: json['address'] as String?,
      networkIP: json['networkIP'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusMeters: (json['radiusMeters'] as int?) ?? 100,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate().toUtc()
          : DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now().toUtc(),
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
    );
  }

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasWifi => networkIP != null && networkIP!.isNotEmpty;

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
      ];

  @override
  String toString() =>
      'StoreModel(id: $id, name: $name, code: $code, ownerId: $ownerId)';
}

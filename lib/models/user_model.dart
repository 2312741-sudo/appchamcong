import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? currentStoreId;
  final List<String> storeIds;
  final DateTime createdAt;

  bool get hasStore => currentStoreId != null && currentStoreId!.isNotEmpty;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.currentStoreId,
    this.storeIds = const [],
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    return UserModel(
      id: docId ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatarUrl: json['avatarUrl'],
      currentStoreId: json['currentStoreId'],
      storeIds: List<String>.from(json['storeIds'] ?? []),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString()) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'currentStoreId': currentStoreId,
      'storeIds': storeIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromJson(data, doc.id);
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? currentStoreId,
    List<String>? storeIds,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currentStoreId: currentStoreId ?? this.currentStoreId,
      storeIds: storeIds ?? this.storeIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        phone,
        avatarUrl,
        currentStoreId,
        storeIds,
        createdAt,
      ];
}

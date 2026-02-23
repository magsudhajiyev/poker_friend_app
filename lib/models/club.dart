import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a poker club that can have multiple tables and members
class Club {
  final String id;
  final String name;
  final String ownerId;
  final String createdBy; // Admin userId who created this club
  final DateTime createdAt;
  final ClubSettings settings;
  final String? address;
  final String? phone;
  final String? description;

  Club({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdBy,
    required this.createdAt,
    required this.settings,
    this.address,
    this.phone,
    this.description,
  });

  /// Factory constructor from Firestore document
  factory Club.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Club(
      id: doc.id,
      name: data['name'] ?? '',
      ownerId: data['ownerId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settings: ClubSettings.fromMap(data['settings'] as Map<String, dynamic>? ?? {}),
      address: data['address'] as String?,
      phone: data['phone'] as String?,
      description: data['description'] as String?,
    );
  }

  /// Factory constructor from map (for local storage)
  factory Club.fromMap(Map<String, dynamic> map) {
    return Club(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      ownerId: map['ownerId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      settings: ClubSettings.fromMap(map['settings'] as Map<String, dynamic>? ?? {}),
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      description: map['description'] as String?,
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerId': ownerId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'settings': settings.toMap(),
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (description != null) 'description': description,
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'settings': settings.toMap(),
      'address': address,
      'phone': phone,
      'description': description,
    };
  }

  /// Create a copy with updated values
  Club copyWith({
    String? name,
    String? ownerId,
    ClubSettings? settings,
    String? address,
    String? phone,
    String? description,
  }) {
    return Club(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      createdBy: createdBy,
      createdAt: createdAt,
      settings: settings ?? this.settings,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      description: description ?? this.description,
    );
  }
}

/// Settings for a club
class ClubSettings {
  final int defaultSmallBlind;
  final int defaultBigBlind;
  final int defaultPlayerCount;
  final bool defaultHasBBante;
  final String defaultGameType; // 'cash' or 'tournament'

  ClubSettings({
    this.defaultSmallBlind = 1,
    this.defaultBigBlind = 2,
    this.defaultPlayerCount = 9,
    this.defaultHasBBante = false,
    this.defaultGameType = 'cash',
  });

  factory ClubSettings.fromMap(Map<String, dynamic> map) {
    return ClubSettings(
      defaultSmallBlind: map['defaultSmallBlind'] ?? 1,
      defaultBigBlind: map['defaultBigBlind'] ?? 2,
      defaultPlayerCount: map['defaultPlayerCount'] ?? 9,
      defaultHasBBante: map['defaultHasBBante'] ?? false,
      defaultGameType: map['defaultGameType'] ?? 'cash',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultSmallBlind': defaultSmallBlind,
      'defaultBigBlind': defaultBigBlind,
      'defaultPlayerCount': defaultPlayerCount,
      'defaultHasBBante': defaultHasBBante,
      'defaultGameType': defaultGameType,
    };
  }

  ClubSettings copyWith({
    int? defaultSmallBlind,
    int? defaultBigBlind,
    int? defaultPlayerCount,
    bool? defaultHasBBante,
    String? defaultGameType,
  }) {
    return ClubSettings(
      defaultSmallBlind: defaultSmallBlind ?? this.defaultSmallBlind,
      defaultBigBlind: defaultBigBlind ?? this.defaultBigBlind,
      defaultPlayerCount: defaultPlayerCount ?? this.defaultPlayerCount,
      defaultHasBBante: defaultHasBBante ?? this.defaultHasBBante,
      defaultGameType: defaultGameType ?? this.defaultGameType,
    );
  }
}

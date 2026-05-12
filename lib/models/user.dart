import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isEmailVerified;
  final UserPreferences preferences;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
    required this.createdAt,
    required this.lastLoginAt,
    required this.isEmailVerified,
    required this.preferences,
  });

  factory User.fromFirebase(Map<String, dynamic> data, String id) {
    return User(
      id: id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      phoneNumber: data['phoneNumber'],
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp).toDate(),
      isEmailVerified: data['isEmailVerified'] ?? false,
      preferences: UserPreferences.fromMap(data['preferences'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'isEmailVerified': isEmailVerified,
      'preferences': preferences.toMap(),
    };
  }

  User copyWith({
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    DateTime? lastLoginAt,
    bool? isEmailVerified,
    UserPreferences? preferences,
  }) {
    return User(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      preferences: preferences ?? this.preferences,
    );
  }
}

class UserPreferences {
  final bool notificationsEnabled;
  final bool locationSharingEnabled;
  final String defaultTransportMode;
  final bool darkMode;
  final String language;

  UserPreferences({
    this.notificationsEnabled = true,
    this.locationSharingEnabled = true,
    this.defaultTransportMode = 'jeepney',
    this.darkMode = false,
    this.language = 'en',
  });

  factory UserPreferences.fromMap(Map<String, dynamic> data) {
    return UserPreferences(
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      locationSharingEnabled: data['locationSharingEnabled'] ?? true,
      defaultTransportMode: data['defaultTransportMode'] ?? 'jeepney',
      darkMode: data['darkMode'] ?? false,
      language: data['language'] ?? 'en',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'locationSharingEnabled': locationSharingEnabled,
      'defaultTransportMode': defaultTransportMode,
      'darkMode': darkMode,
      'language': language,
    };
  }
}

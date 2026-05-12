import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'firebase_service.dart';

/// User Profile Model
class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;
  final LatLng? homeLocation;
  final LatLng? workLocation;
  final List<String> emergencyContacts;
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerified;
  final String? fcmToken; // For push notifications

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
    this.homeLocation,
    this.workLocation,
    this.emergencyContacts = const [],
    this.preferences = const {},
    required this.createdAt,
    required this.updatedAt,
    this.isVerified = false,
    this.fcmToken,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'phoneNumber': phoneNumber,
    'photoUrl': photoUrl,
    'homeLocation': homeLocation != null ? {
      'lat': homeLocation!.latitude,
      'lng': homeLocation!.longitude,
    } : null,
    'workLocation': workLocation != null ? {
      'lat': workLocation!.latitude,
      'lng': workLocation!.longitude,
    } : null,
    'emergencyContacts': emergencyContacts,
    'preferences': preferences,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'isVerified': isVerified,
    'fcmToken': fcmToken,
  };

  factory UserProfile.fromMap(String id, Map<String, dynamic> map) {
    return UserProfile(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      phoneNumber: map['phoneNumber'],
      photoUrl: map['photoUrl'],
      homeLocation: map['homeLocation'] != null
          ? LatLng(map['homeLocation']['lat'], map['homeLocation']['lng'])
          : null,
      workLocation: map['workLocation'] != null
          ? LatLng(map['workLocation']['lat'], map['workLocation']['lng'])
          : null,
      emergencyContacts: List<String>.from(map['emergencyContacts'] ?? []),
      preferences: Map<String, dynamic>.from(map['preferences'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isVerified: map['isVerified'] ?? false,
      fcmToken: map['fcmToken'],
    );
  }
}

/// User Service - CRUD for user profiles
class UserService {
  static final _firestore = FirebaseService.firestore;
  static final _auth = FirebaseService.auth;
  static const String _collection = 'users';

  // ================= CREATE =================

  /// Create new user profile after signup
  static Future<UserProfile> createUserProfile({
    String? displayName,
    String? phoneNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final now = DateTime.now();
    final profile = UserProfile(
      id: user.uid,
      email: user.email!,
      displayName: displayName ?? user.displayName,
      phoneNumber: phoneNumber ?? user.phoneNumber,
      photoUrl: user.photoURL,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore
        .collection(_collection)
        .doc(user.uid)
        .set(profile.toMap());

    return profile;
  }

  // ================= READ =================

  /// Get current user profile
  static Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return getUserProfile(user.uid);
  }

  /// Get user profile by ID
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Get multiple user profiles
  static Future<List<UserProfile>> getUserProfiles(List<String> userIds) async {
    try {
      final snapshots = await Future.wait(
        userIds.map((id) => _firestore.collection(_collection).doc(id).get()),
      );
      return snapshots
          .where((doc) => doc.exists)
          .map((doc) => UserProfile.fromMap(doc.id, doc.data()!))
          .toList();
    } catch (e) {
      debugPrint('Error getting user profiles: $e');
      return [];
    }
  }

  /// Search users by name
  static Future<List<UserProfile>> searchUsers(String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: '$query\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => UserProfile.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // ================= UPDATE =================

  /// Update user profile
  static Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection(_collection).doc(userId).update(updates);
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      throw Exception('Failed to update profile');
    }
  }

  /// Update profile picture
  static Future<void> updateProfilePicture(String userId, String photoUrl) async {
    await updateUserProfile(userId, {'photoUrl': photoUrl});
  }

  /// Update home location
  static Future<void> updateHomeLocation(String userId, LatLng location) async {
    await updateUserProfile(userId, {
      'homeLocation': {'lat': location.latitude, 'lng': location.longitude},
    });
  }

  /// Update work location
  static Future<void> updateWorkLocation(String userId, LatLng location) async {
    await updateUserProfile(userId, {
      'workLocation': {'lat': location.latitude, 'lng': location.longitude},
    });
  }

  /// Add emergency contact
  static Future<void> addEmergencyContact(String userId, String contact) async {
    await _firestore.collection(_collection).doc(userId).update({
      'emergencyContacts': FieldValue.arrayUnion([contact]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Remove emergency contact
  static Future<void> removeEmergencyContact(String userId, String contact) async {
    await _firestore.collection(_collection).doc(userId).update({
      'emergencyContacts': FieldValue.arrayRemove([contact]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Update FCM token for push notifications
  static Future<void> updateFcmToken(String userId, String token) async {
    await _firestore.collection(_collection).doc(userId).update({
      'fcmToken': token,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Update user preferences
  static Future<void> updatePreferences(
    String userId,
    Map<String, dynamic> preferences,
  ) async {
    await _firestore.collection(_collection).doc(userId).update({
      'preferences': preferences,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ================= DELETE =================

  /// Delete user profile
  static Future<void> deleteUserProfile(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).delete();
    } catch (e) {
      debugPrint('Error deleting user profile: $e');
      throw Exception('Failed to delete profile');
    }
  }

  // ================= REALTIME =================

  /// Stream user profile updates
  static Stream<UserProfile?> watchUserProfile(String userId) {
    return _firestore
        .collection(_collection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromMap(doc.id, doc.data()!) : null);
  }

  /// Stream current user profile
  static Stream<UserProfile?> watchCurrentUserProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return watchUserProfile(user.uid);
  }

  // ================= AUTH HELPERS =================

  /// Check if username is available
  static Future<bool> isUsernameAvailable(String displayName) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('displayName', isEqualTo: displayName)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty;
  }

  /// Get user statistics
  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final incidentCount = await _firestore
          .collection('incidents')
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      final routeCount = await _firestore
          .collection('route_history')
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      return {
        'incidentsReported': incidentCount.count ?? 0,
        'routesTaken': routeCount.count ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return {'incidentsReported': 0, 'routesTaken': 0};
    }
  }
}

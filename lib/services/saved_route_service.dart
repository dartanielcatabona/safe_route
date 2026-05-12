import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/transit_route.dart';
import 'firebase_service.dart';

/// Saved Route Model (User's favorite/saved routes)
class SavedRoute {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final LatLng startLocation;
  final String startAddress;
  final LatLng endLocation;
  final String endAddress;
  final TransitMode? preferredMode;
  final int? estimatedMinutes;
  final double? estimatedFare;
  final List<Map<String, dynamic>>? routeWaypoints;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;
  final int useCount;
  final String? icon;
  final String? color;

  SavedRoute({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.startLocation,
    required this.startAddress,
    required this.endLocation,
    required this.endAddress,
    this.preferredMode,
    this.estimatedMinutes,
    this.estimatedFare,
    this.routeWaypoints,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
    this.useCount = 0,
    this.icon,
    this.color,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'description': description,
    'startLocation': {
      'lat': startLocation.latitude,
      'lng': startLocation.longitude,
    },
    'startAddress': startAddress,
    'endLocation': {
      'lat': endLocation.latitude,
      'lng': endLocation.longitude,
    },
    'endAddress': endAddress,
    'preferredMode': preferredMode?.name,
    'estimatedMinutes': estimatedMinutes,
    'estimatedFare': estimatedFare,
    'routeWaypoints': routeWaypoints,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'isFavorite': isFavorite,
    'useCount': useCount,
    'icon': icon,
    'color': color,
  };

  factory SavedRoute.fromMap(String id, Map<String, dynamic> map) {
    return SavedRoute(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      startLocation: LatLng(
        map['startLocation']['lat'],
        map['startLocation']['lng'],
      ),
      startAddress: map['startAddress'] ?? '',
      endLocation: LatLng(
        map['endLocation']['lat'],
        map['endLocation']['lng'],
      ),
      endAddress: map['endAddress'] ?? '',
      preferredMode: map['preferredMode'] != null
          ? TransitMode.values.firstWhere(
              (e) => e.name == map['preferredMode'],
              orElse: () => TransitMode.p2pBus,
            )
          : null,
      estimatedMinutes: map['estimatedMinutes'],
      estimatedFare: map['estimatedFare']?.toDouble(),
      routeWaypoints: map['routeWaypoints'] != null
          ? List<Map<String, dynamic>>.from(map['routeWaypoints'])
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isFavorite: map['isFavorite'] ?? false,
      useCount: map['useCount'] ?? 0,
      icon: map['icon'],
      color: map['color'],
    );
  }
}

/// Saved Route Service - CRUD for user saved/favorite routes
class SavedRouteService {
  static final _firestore = FirebaseService.firestore;
  static const String _collection = 'saved_routes';

  // ================= CREATE =================

  /// Save a new route
  static Future<SavedRoute> saveRoute({
    required String userId,
    required String name,
    String? description,
    required LatLng startLocation,
    required String startAddress,
    required LatLng endLocation,
    required String endAddress,
    TransitMode? preferredMode,
    int? estimatedMinutes,
    double? estimatedFare,
    List<Map<String, dynamic>>? routeWaypoints,
    String? icon,
    String? color,
  }) async {
    final now = DateTime.now();
    final docRef = _firestore.collection(_collection).doc();
    
    final savedRoute = SavedRoute(
      id: docRef.id,
      userId: userId,
      name: name,
      description: description,
      startLocation: startLocation,
      startAddress: startAddress,
      endLocation: endLocation,
      endAddress: endAddress,
      preferredMode: preferredMode,
      estimatedMinutes: estimatedMinutes,
      estimatedFare: estimatedFare,
      routeWaypoints: routeWaypoints,
      createdAt: now,
      updatedAt: now,
      icon: icon,
      color: color,
    );

    await docRef.set(savedRoute.toMap());
    return savedRoute;
  }

  /// Quick save current route
  static Future<SavedRoute> quickSave({
    required String userId,
    required MultiModalRoute route,
    required LatLng start,
    required String startAddress,
    required LatLng end,
    required String endAddress,
    String name = 'Saved Route',
  }) async {
    return saveRoute(
      userId: userId,
      name: name,
      startLocation: start,
      startAddress: startAddress,
      endLocation: end,
      endAddress: endAddress,
      estimatedMinutes: route.totalMinutes,
      estimatedFare: route.totalFare,
    );
  }

  // ================= READ =================

  /// Get single saved route
  static Future<SavedRoute?> getSavedRoute(String routeId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(routeId).get();
      if (doc.exists) {
        return SavedRoute.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting saved route: $e');
      return null;
    }
  }

  /// Get all saved routes for user
  static Future<List<SavedRoute>> getUserSavedRoutes(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SavedRoute.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching saved routes: $e');
      return [];
    }
  }

  /// Get favorite routes only
  static Future<List<SavedRoute>> getFavoriteRoutes(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isFavorite', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SavedRoute.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching favorite routes: $e');
      return [];
    }
  }

  /// Search saved routes by name
  static Future<List<SavedRoute>> searchSavedRoutes(
    String userId,
    String query,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('name')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .get();

      return snapshot.docs
          .map((doc) => SavedRoute.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error searching saved routes: $e');
      return [];
    }
  }

  /// Get frequently used routes (top N by useCount)
  static Future<List<SavedRoute>> getFrequentRoutes(
    String userId, {
    int limit = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('useCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SavedRoute.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching frequent routes: $e');
      return [];
    }
  }

  // ================= UPDATE =================

  /// Update saved route
  static Future<void> updateSavedRoute(
    String routeId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection(_collection).doc(routeId).update(updates);
    } catch (e) {
      debugPrint('Error updating saved route: $e');
      throw Exception('Failed to update saved route');
    }
  }

  /// Rename route
  static Future<void> renameRoute(String routeId, String newName) async {
    await updateSavedRoute(routeId, {'name': newName});
  }

  /// Toggle favorite status
  static Future<void> toggleFavorite(String routeId, bool isFavorite) async {
    await updateSavedRoute(routeId, {'isFavorite': isFavorite});
  }

  /// Increment use count
  static Future<void> incrementUseCount(String routeId) async {
    await _firestore.collection(_collection).doc(routeId).update({
      'useCount': FieldValue.increment(1),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Update route details
  static Future<void> updateRouteDetails(
    String routeId, {
    String? name,
    String? description,
    TransitMode? preferredMode,
    String? icon,
    String? color,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (preferredMode != null) updates['preferredMode'] = preferredMode.name;
    if (icon != null) updates['icon'] = icon;
    if (color != null) updates['color'] = color;

    await _firestore.collection(_collection).doc(routeId).update(updates);
  }

  // ================= DELETE =================

  /// Delete saved route
  static Future<void> deleteSavedRoute(String routeId) async {
    try {
      await _firestore.collection(_collection).doc(routeId).delete();
    } catch (e) {
      debugPrint('Error deleting saved route: $e');
      throw Exception('Failed to delete saved route');
    }
  }

  /// Delete all user saved routes
  static Future<void> deleteAllUserRoutes(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting all routes: $e');
      throw Exception('Failed to delete routes');
    }
  }

  // ================= REALTIME =================

  /// Stream user's saved routes
  static Stream<List<SavedRoute>> watchUserSavedRoutes(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedRoute.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Stream favorite routes
  static Stream<List<SavedRoute>> watchFavoriteRoutes(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isFavorite', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedRoute.fromMap(doc.id, doc.data()))
            .toList());
  }

  // ================= STATISTICS =================

  /// Get saved route statistics for user
  static Future<Map<String, dynamic>> getUserRouteStats(String userId) async {
    try {
      final total = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      final favorites = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isFavorite', isEqualTo: true)
          .count()
          .get();

      return {
        'totalSaved': total.count ?? 0,
        'favorites': favorites.count ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting route stats: $e');
      return {'totalSaved': 0, 'favorites': 0};
    }
  }
}

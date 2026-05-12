import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/transit_route.dart';
import 'firebase_service.dart';

/// Route History Entry (Completed trips)
class RouteHistoryEntry {
  final String id;
  final String userId;
  final LatLng startLocation;
  final String startAddress;
  final LatLng endLocation;
  final String endAddress;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? actualMinutes;
  final double? actualFare;
  final List<RouteSegment> segments;
  final double safetyScore;
  final List<String>? incidentIds; // Incidents encountered
  final Map<String, dynamic>? mlPredictionData;
  final String? savedRouteId; // If from a saved route
  final DateTime createdAt;

  RouteHistoryEntry({
    required this.id,
    required this.userId,
    required this.startLocation,
    required this.startAddress,
    required this.endLocation,
    required this.endAddress,
    required this.startedAt,
    this.completedAt,
    this.actualMinutes,
    this.actualFare,
    required this.segments,
    required this.safetyScore,
    this.incidentIds,
    this.mlPredictionData,
    this.savedRouteId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
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
    'startedAt': Timestamp.fromDate(startedAt),
    'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    'actualMinutes': actualMinutes,
    'actualFare': actualFare,
    'segments': segments.map((s) => {
      'mode': s.mode.name,
      'start': {'lat': s.start.latitude, 'lng': s.start.longitude},
      'end': {'lat': s.end.latitude, 'lng': s.end.longitude},
      'minutes': s.estimatedMinutes,
      'fare': s.fare,
    }).toList(),
    'safetyScore': safetyScore,
    'incidentIds': incidentIds,
    'mlPredictionData': mlPredictionData,
    'savedRouteId': savedRouteId,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory RouteHistoryEntry.fromMap(String id, Map<String, dynamic> map) {
    return RouteHistoryEntry(
      id: id,
      userId: map['userId'] ?? '',
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
      startedAt: (map['startedAt'] as Timestamp).toDate(),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      actualMinutes: map['actualMinutes'],
      actualFare: map['actualFare']?.toDouble(),
      segments: (map['segments'] as List?)
          ?.map((s) => RouteSegment(
            mode: TransitMode.values.firstWhere(
              (e) => e.name == s['mode'],
              orElse: () => TransitMode.p2pBus,
            ),
            start: LatLng(s['start']['lat'], s['start']['lng']),
            end: LatLng(s['end']['lat'], s['end']['lng']),
            path: [],
            estimatedMinutes: s['minutes'] ?? 0,
            fare: s['fare']?.toDouble() ?? 0,
            safetyScore: s['safetyScore']?.toDouble() ?? 5.0,
          )).toList() ?? [],
      safetyScore: map['safetyScore']?.toDouble() ?? 5.0,
      incidentIds: map['incidentIds'] != null
          ? List<String>.from(map['incidentIds'])
          : null,
      mlPredictionData: map['mlPredictionData'] != null
          ? Map<String, dynamic>.from(map['mlPredictionData'])
          : null,
      savedRouteId: map['savedRouteId'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

/// Route History Service - CRUD for trip history
class RouteHistoryService {
  static final _firestore = FirebaseService.firestore;
  static const String _collection = 'route_history';

  // ================= CREATE =================

  /// Start a new trip (create history entry)
  static Future<RouteHistoryEntry> startTrip({
    required String userId,
    required LatLng startLocation,
    required String startAddress,
    required LatLng endLocation,
    required String endAddress,
    required List<RouteSegment> segments,
    required double safetyScore,
    String? savedRouteId,
    Map<String, dynamic>? mlPredictionData,
  }) async {
    final now = DateTime.now();
    final docRef = _firestore.collection(_collection).doc();

    final entry = RouteHistoryEntry(
      id: docRef.id,
      userId: userId,
      startLocation: startLocation,
      startAddress: startAddress,
      endLocation: endLocation,
      endAddress: endAddress,
      startedAt: now,
      segments: segments,
      safetyScore: safetyScore,
      savedRouteId: savedRouteId,
      mlPredictionData: mlPredictionData,
      createdAt: now,
    );

    await docRef.set(entry.toMap());
    return entry;
  }

  /// Complete a trip (update with actual time and fare)
  static Future<void> completeTrip(
    String entryId, {
    required int actualMinutes,
    required double actualFare,
    List<String>? incidentIds,
  }) async {
    await _firestore.collection(_collection).doc(entryId).update({
      'completedAt': Timestamp.fromDate(DateTime.now()),
      'actualMinutes': actualMinutes,
      'actualFare': actualFare,
      'incidentIds': incidentIds,
    });
  }

  // ================= READ =================

  /// Get single history entry
  static Future<RouteHistoryEntry?> getHistoryEntry(String entryId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(entryId).get();
      if (doc.exists) {
        return RouteHistoryEntry.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting history entry: $e');
      return null;
    }
  }

  /// Get user's trip history
  static Future<List<RouteHistoryEntry>> getUserHistory(
    String userId, {
    int limit = 50,
    DateTime? since,
  }) async {
    try {
      var query = _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      if (since != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs
          .map((doc) => RouteHistoryEntry.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching route history: $e');
      return [];
    }
  }

  /// Get recent trips (last 7 days)
  static Future<List<RouteHistoryEntry>> getRecentTrips(String userId) async {
    final lastWeek = DateTime.now().subtract(const Duration(days: 7));
    return getUserHistory(userId, since: lastWeek);
  }

  /// Get completed trips only
  static Future<List<RouteHistoryEntry>> getCompletedTrips(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('completedAt', isNotEqualTo: null)
          .orderBy('completedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RouteHistoryEntry.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching completed trips: $e');
      return [];
    }
  }

  /// Get active (incomplete) trips
  static Future<List<RouteHistoryEntry>> getActiveTrips(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('completedAt', isEqualTo: null)
          .orderBy('startedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RouteHistoryEntry.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching active trips: $e');
      return [];
    }
  }

  /// Get trips by date range
  static Future<List<RouteHistoryEntry>> getTripsByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RouteHistoryEntry.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching trips by date: $e');
      return [];
    }
  }

  // ================= UPDATE =================

  /// Update history entry
  static Future<void> updateHistoryEntry(
    String entryId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection(_collection).doc(entryId).update(updates);
    } catch (e) {
      debugPrint('Error updating history entry: $e');
      throw Exception('Failed to update history');
    }
  }

  /// Report incident during trip
  static Future<void> reportTripIncident(
    String entryId,
    String incidentId,
  ) async {
    await _firestore.collection(_collection).doc(entryId).update({
      'incidentIds': FieldValue.arrayUnion([incidentId]),
    });
  }

  /// Update actual fare/time after trip
  static Future<void> updateTripActuals(
    String entryId, {
    int? actualMinutes,
    double? actualFare,
  }) async {
    final updates = <String, dynamic>{};
    if (actualMinutes != null) updates['actualMinutes'] = actualMinutes;
    if (actualFare != null) updates['actualFare'] = actualFare;
    if (updates.isNotEmpty) {
      await _firestore.collection(_collection).doc(entryId).update(updates);
    }
  }

  // ================= DELETE =================

  /// Delete history entry
  static Future<void> deleteHistoryEntry(String entryId) async {
    try {
      await _firestore.collection(_collection).doc(entryId).delete();
    } catch (e) {
      debugPrint('Error deleting history entry: $e');
      throw Exception('Failed to delete history');
    }
  }

  /// Delete all user history
  static Future<void> deleteAllUserHistory(String userId) async {
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
      debugPrint('Error deleting all history: $e');
      throw Exception('Failed to delete history');
    }
  }

  // ================= REALTIME =================

  /// Stream user's trip history
  static Stream<List<RouteHistoryEntry>> watchUserHistory(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RouteHistoryEntry.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Stream active trips
  static Stream<List<RouteHistoryEntry>> watchActiveTrips(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('completedAt', isEqualTo: null)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RouteHistoryEntry.fromMap(doc.id, doc.data()))
            .toList());
  }

  // ================= STATISTICS & ANALYTICS =================

  /// Get user trip statistics
  static Future<Map<String, dynamic>> getUserTripStats(String userId) async {
    try {
      final allTrips = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      final completedTrips = allTrips.docs.where((d) => d.data()['completedAt'] != null).toList();

      int totalMinutes = 0;
      double totalFare = 0;
      int tripsWithFare = 0;

      for (final trip in completedTrips) {
        final data = trip.data();
        if (data['actualMinutes'] != null) {
          totalMinutes += data['actualMinutes'] as int;
        }
        if (data['actualFare'] != null) {
          totalFare += data['actualFare'] as double;
          tripsWithFare++;
        }
      }

      return {
        'totalTrips': allTrips.docs.length,
        'completedTrips': completedTrips.length,
        'activeTrips': allTrips.docs.length - completedTrips.length,
        'totalMinutes': totalMinutes,
        'totalFare': totalFare,
        'averageFare': tripsWithFare > 0 ? totalFare / tripsWithFare : 0,
        'averageTripTime': completedTrips.isNotEmpty 
            ? totalMinutes / completedTrips.length 
            : 0,
      };
    } catch (e) {
      debugPrint('Error getting trip stats: $e');
      return {
        'totalTrips': 0,
        'completedTrips': 0,
        'activeTrips': 0,
        'totalMinutes': 0,
        'totalFare': 0.0,
        'averageFare': 0.0,
        'averageTripTime': 0.0,
      };
    }
  }

  /// Get most frequent destinations
  static Future<List<Map<String, dynamic>>> getFrequentDestinations(
    String userId, {
    int limit = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('completedAt', isNotEqualTo: null)
          .orderBy('completedAt', descending: true)
          .limit(100)
          .get();

      final destinationCounts = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final destAddress = data['endAddress'] as String;
        
        if (!destinationCounts.containsKey(destAddress)) {
          destinationCounts[destAddress] = {
            'address': destAddress,
            'location': data['endLocation'],
            'count': 0,
            'lastVisit': (data['completedAt'] as Timestamp).toDate(),
          };
        }
        destinationCounts[destAddress]!['count'] = 
            (destinationCounts[destAddress]!['count'] as int) + 1;
      }

      final sorted = destinationCounts.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return sorted.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting frequent destinations: $e');
      return [];
    }
  }
}

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/incident_report.dart';
import 'firebase_service.dart';

class IncidentService {
  static final _firestore = FirebaseService.firestore;
  static const String _collection = 'incidents';

  static Future<String> reportIncident(IncidentReport report) async {
    try {
      final docRef = await _firestore.collection(_collection).add(report.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error reporting incident: $e');
      throw Exception('Failed to report incident');
    }
  }

  static Stream<List<IncidentReport>> getNearbyIncidents(
    LatLng center,
    double radiusKm, {
    DateTime? since,
  }) {
    // Query incidents within time window (Firestore doesn't support radius queries directly)
    final query = _firestore
        .collection(_collection)
        .where('reportedAt', isGreaterThan: Timestamp.fromDate(
          since ?? DateTime.now().subtract(const Duration(days: 7)),
        ))
        .orderBy('reportedAt', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => IncidentReport.fromMap(doc.id, doc.data()))
          .where((incident) => _isWithinRadius(incident.location, center, radiusKm))
          .toList();
    });
  }

  static Future<List<IncidentReport>> getIncidentsInArea(
    LatLng southwest,
    LatLng northeast, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('reportedAt', isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 30)),
          ))
          .orderBy('reportedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => IncidentReport.fromMap(doc.id, doc.data()))
          .where((incident) => _isWithinBounds(incident.location, southwest, northeast))
          .toList();
    } catch (e) {
      debugPrint('Error fetching incidents: $e');
      return [];
    }
  }

  static Future<void> upvoteIncident(String incidentId) async {
    await _firestore.collection(_collection).doc(incidentId).update({
      'upvotes': FieldValue.increment(1),
    });
  }

  static Future<void> downvoteIncident(String incidentId) async {
    await _firestore.collection(_collection).doc(incidentId).update({
      'downvotes': FieldValue.increment(1),
    });
  }

  static Future<void> verifyIncident(String incidentId, String verifierId) async {
    await _firestore.collection(_collection).doc(incidentId).update({
      'isVerified': true,
      'verifiedBy': verifierId,
      'verifiedAt': FieldValue.serverTimestamp(),
    });
  }

  // ================= COMPLETE CRUD OPERATIONS =================

  /// READ single incident by ID
  static Future<IncidentReport?> getIncident(String incidentId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(incidentId).get();
      if (doc.exists) {
        return IncidentReport.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting incident: $e');
      return null;
    }
  }

  /// READ all incidents by current user
  static Future<List<IncidentReport>> getMyIncidents(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('reportedAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => IncidentReport.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching my incidents: $e');
      return [];
    }
  }

  /// UPDATE incident
  static Future<void> updateIncident(
    String incidentId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(_collection).doc(incidentId).update(updates);
    } catch (e) {
      debugPrint('Error updating incident: $e');
      throw Exception('Failed to update incident');
    }
  }

  /// DELETE incident
  static Future<void> deleteIncident(String incidentId) async {
    try {
      await _firestore.collection(_collection).doc(incidentId).delete();
    } catch (e) {
      debugPrint('Error deleting incident: $e');
      throw Exception('Failed to delete incident');
    }
  }

  /// Delete all incidents reported by a user
  static Future<void> deleteAllUserIncidents(String userId) async {
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
      debugPrint('Error deleting all incidents: $e');
      throw Exception('Failed to delete incidents');
    }
  }

  /// REALTIME stream of user's incidents
  static Stream<List<IncidentReport>> watchMyIncidents(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => IncidentReport.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Batch update incident status
  static Future<void> batchUpdateStatus(
    List<String> incidentIds,
    String newStatus,
  ) async {
    final batch = _firestore.batch();
    for (final id in incidentIds) {
      final ref = _firestore.collection(_collection).doc(id);
      batch.update(ref, {'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  static bool _isWithinRadius(LatLng point, LatLng center, double radiusKm) {
    // Haversine formula
    const R = 6371; // Earth radius in km
    final lat1 = _toRadians(center.latitude);
    final lat2 = _toRadians(point.latitude);
    final deltaLat = _toRadians(point.latitude - center.latitude);
    final deltaLng = _toRadians(point.longitude - center.longitude);

    final a = 
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    final c = 2 * math.asin(math.sqrt(a));
    final distance = R * c;

    return distance <= radiusKm;
  }

  static bool _isWithinBounds(LatLng point, LatLng southwest, LatLng northeast) {
    return point.latitude >= southwest.latitude &&
        point.latitude <= northeast.latitude &&
        point.longitude >= southwest.longitude &&
        point.longitude <= northeast.longitude;
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180);

  // ================= STATISTICS & ANALYTICS =================

  /// Get incident statistics by type
  static Future<Map<String, int>> getIncidentStatsByType() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      final stats = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final type = doc.data()['type'] as String? ?? 'unknown';
        stats[type] = (stats[type] ?? 0) + 1;
      }
      
      return stats;
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {};
    }
  }

  /// Get verified vs unverified counts
  static Future<Map<String, int>> getVerificationStats() async {
    try {
      final verified = await _firestore
          .collection(_collection)
          .where('isVerified', isEqualTo: true)
          .count()
          .get();
      
      final total = await _firestore.collection(_collection).count().get();
      
      return {
        'verified': verified.count ?? 0,
        'unverified': (total.count ?? 0) - (verified.count ?? 0),
      };
    } catch (e) {
      debugPrint('Error getting verification stats: $e');
      return {'verified': 0, 'unverified': 0};
    }
  }
}

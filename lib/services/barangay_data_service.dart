import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'firebase_service.dart';

/// Barangay Crime Data Model
class BarangayCrimeData {
  final String id;
  final String barangayName;
  final String city;
  final double crimeRate; // 0-1 scale
  final int population;
  final int totalIncidents;
  final Map<String, int> crimeTypeCounts;
  final List<CrimeHotspot> hotspots;
  final double safetyScore; // 0-10 scale (10 = safest)
  final DateTime dataDate;
  final DateTime lastUpdated;
  final LatLng? centerLocation;
  final List<double>? boundaryCoordinates; // For geofencing

  BarangayCrimeData({
    required this.id,
    required this.barangayName,
    required this.city,
    required this.crimeRate,
    required this.population,
    required this.totalIncidents,
    required this.crimeTypeCounts,
    this.hotspots = const [],
    required this.safetyScore,
    required this.dataDate,
    required this.lastUpdated,
    this.centerLocation,
    this.boundaryCoordinates,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'barangayName': barangayName,
    'city': city,
    'crimeRate': crimeRate,
    'population': population,
    'totalIncidents': totalIncidents,
    'crimeTypeCounts': crimeTypeCounts,
    'hotspots': hotspots.map((h) => h.toMap()).toList(),
    'safetyScore': safetyScore,
    'dataDate': Timestamp.fromDate(dataDate),
    'lastUpdated': Timestamp.fromDate(lastUpdated),
    'centerLocation': centerLocation != null ? {
      'lat': centerLocation!.latitude,
      'lng': centerLocation!.longitude,
    } : null,
    'boundaryCoordinates': boundaryCoordinates,
  };

  factory BarangayCrimeData.fromMap(String id, Map<String, dynamic> map) {
    return BarangayCrimeData(
      id: id,
      barangayName: map['barangayName'] ?? '',
      city: map['city'] ?? '',
      crimeRate: map['crimeRate']?.toDouble() ?? 0.0,
      population: map['population'] ?? 0,
      totalIncidents: map['totalIncidents'] ?? 0,
      crimeTypeCounts: Map<String, int>.from(map['crimeTypeCounts'] ?? {}),
      hotspots: (map['hotspots'] as List?)
          ?.map((h) => CrimeHotspot.fromMap(h as Map<String, dynamic>))
          .toList() ?? [],
      safetyScore: map['safetyScore']?.toDouble() ?? 5.0,
      dataDate: (map['dataDate'] as Timestamp).toDate(),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
      centerLocation: map['centerLocation'] != null
          ? LatLng(map['centerLocation']['lat'], map['centerLocation']['lng'])
          : null,
      boundaryCoordinates: map['boundaryCoordinates'] != null
          ? List<double>.from(map['boundaryCoordinates'])
          : null,
    );
  }
}

/// Crime Hotspot within a barangay
class CrimeHotspot {
  final String id;
  final LatLng location;
  final String description;
  final int incidentCount;
  final List<String> commonCrimeTypes;
  final double riskScore;

  CrimeHotspot({
    required this.id,
    required this.location,
    required this.description,
    required this.incidentCount,
    required this.commonCrimeTypes,
    required this.riskScore,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'location': {'lat': location.latitude, 'lng': location.longitude},
    'description': description,
    'incidentCount': incidentCount,
    'commonCrimeTypes': commonCrimeTypes,
    'riskScore': riskScore,
  };

  factory CrimeHotspot.fromMap(Map<String, dynamic> map) {
    return CrimeHotspot(
      id: map['id'] ?? '',
      location: LatLng(map['location']['lat'], map['location']['lng']),
      description: map['description'] ?? '',
      incidentCount: map['incidentCount'] ?? 0,
      commonCrimeTypes: List<String>.from(map['commonCrimeTypes'] ?? []),
      riskScore: map['riskScore']?.toDouble() ?? 0.0,
    );
  }
}

/// Historical Crime Entry
class CrimeEntry {
  final String id;
  final String barangayId;
  final String type;
  final DateTime date;
  final LatLng? location;
  final String? description;
  final String? severity;
  final bool isVerified;
  final DateTime createdAt;

  CrimeEntry({
    required this.id,
    required this.barangayId,
    required this.type,
    required this.date,
    this.location,
    this.description,
    this.severity,
    this.isVerified = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'barangayId': barangayId,
    'type': type,
    'date': Timestamp.fromDate(date),
    'location': location != null ? {
      'lat': location!.latitude,
      'lng': location!.longitude,
    } : null,
    'description': description,
    'severity': severity,
    'isVerified': isVerified,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory CrimeEntry.fromMap(String id, Map<String, dynamic> map) {
    return CrimeEntry(
      id: id,
      barangayId: map['barangayId'] ?? '',
      type: map['type'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      location: map['location'] != null
          ? LatLng(map['location']['lat'], map['location']['lng'])
          : null,
      description: map['description'],
      severity: map['severity'],
      isVerified: map['isVerified'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

/// Barangay Data Service - CRUD for crime statistics
class BarangayDataService {
  static final _firestore = FirebaseService.firestore;
  static const String _collection = 'barangay_data';
  static const String _crimesCollection = 'crime_entries';

  // Cache for barangay data
  static final Map<String, BarangayCrimeData> _cache = {};
  static DateTime _lastCacheUpdate = DateTime.now();

  // ================= CREATE =================

  /// Create new barangay crime data entry
  static Future<BarangayCrimeData> createBarangayData({
    required String barangayName,
    required String city,
    required double crimeRate,
    required int population,
    required int totalIncidents,
    required Map<String, int> crimeTypeCounts,
    List<CrimeHotspot>? hotspots,
    LatLng? centerLocation,
    List<double>? boundaryCoordinates,
  }) async {
    final now = DateTime.now();
    final docRef = _firestore.collection(_collection).doc();

    final data = BarangayCrimeData(
      id: docRef.id,
      barangayName: barangayName,
      city: city,
      crimeRate: crimeRate,
      population: population,
      totalIncidents: totalIncidents,
      crimeTypeCounts: crimeTypeCounts,
      hotspots: hotspots ?? [],
      safetyScore: (1 - crimeRate) * 10, // Convert to safety score
      dataDate: now,
      lastUpdated: now,
      centerLocation: centerLocation,
      boundaryCoordinates: boundaryCoordinates,
    );

    await docRef.set(data.toMap());
    _cache[docRef.id] = data;
    return data;
  }

  /// Add crime entry to barangay
  static Future<String> addCrimeEntry({
    required String barangayId,
    required String type,
    required DateTime date,
    LatLng? location,
    String? description,
    String? severity,
  }) async {
    final docRef = _firestore.collection(_crimesCollection).doc();
    
    final entry = CrimeEntry(
      id: docRef.id,
      barangayId: barangayId,
      type: type,
      date: date,
      location: location,
      description: description,
      severity: severity,
      createdAt: DateTime.now(),
    );

    await docRef.set(entry.toMap());
    
    // Update barangay stats
    await _incrementBarangayCrimeCount(barangayId, type);
    
    return docRef.id;
  }

  // ================= READ =================

  /// Get barangay data by ID
  static Future<BarangayCrimeData?> getBarangayData(String barangayId) async {
    // Check cache first
    if (_cache.containsKey(barangayId) && 
        DateTime.now().difference(_lastCacheUpdate).inMinutes < 30) {
      return _cache[barangayId];
    }

    try {
      final doc = await _firestore.collection(_collection).doc(barangayId).get();
      if (doc.exists) {
        final data = BarangayCrimeData.fromMap(doc.id, doc.data()!);
        _cache[barangayId] = data;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting barangay data: $e');
      return null;
    }
  }

  /// Get barangay by name and city
  static Future<BarangayCrimeData?> getBarangayByName(
    String name,
    String city,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('barangayName', isEqualTo: name)
          .where('city', isEqualTo: city)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return BarangayCrimeData.fromMap(
          snapshot.docs.first.id,
          snapshot.docs.first.data(),
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting barangay by name: $e');
      return null;
    }
  }

  /// Get all barangays in a city
  static Future<List<BarangayCrimeData>> getCityBarangays(String city) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('city', isEqualTo: city)
          .orderBy('barangayName')
          .get();

      return snapshot.docs
          .map((doc) => BarangayCrimeData.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching city barangays: $e');
      return [];
    }
  }

  /// Get high-risk barangays (crime rate > threshold)
  static Future<List<BarangayCrimeData>> getHighRiskBarangays({
    double threshold = 0.6,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('crimeRate', isGreaterThan: threshold)
          .orderBy('crimeRate', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BarangayCrimeData.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching high-risk barangays: $e');
      return [];
    }
  }

  /// Get safest barangays
  static Future<List<BarangayCrimeData>> getSafestBarangays({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('safetyScore', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BarangayCrimeData.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching safest barangays: $e');
      return [];
    }
  }

  /// Find barangay by location
  static Future<BarangayCrimeData?> findBarangayByLocation(LatLng location) async {
    try {
      // Query nearby barangays
      final snapshot = await _firestore
          .collection(_collection)
          .where('centerLocation.lat', 
            isGreaterThan: location.latitude - 0.01,
            isLessThan: location.latitude + 0.01)
          .get();

      BarangayCrimeData? closest;
      double minDistance = double.infinity;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['centerLocation'] != null) {
          final center = LatLng(
            data['centerLocation']['lat'],
            data['centerLocation']['lng'],
          );
          final distance = _calculateDistance(location, center);
          if (distance < minDistance) {
            minDistance = distance;
            closest = BarangayCrimeData.fromMap(doc.id, data);
          }
        }
      }

      return closest;
    } catch (e) {
      debugPrint('Error finding barangay by location: $e');
      return null;
    }
  }

  /// Get crime entries for barangay
  static Future<List<CrimeEntry>> getBarangayCrimes(
    String barangayId, {
    DateTime? since,
    int limit = 50,
  }) async {
    try {
      var query = _firestore
          .collection(_crimesCollection)
          .where('barangayId', isEqualTo: barangayId)
          .orderBy('date', descending: true);

      if (since != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs
          .map((doc) => CrimeEntry.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching barangay crimes: $e');
      return [];
    }
  }

  // ================= UPDATE =================

  /// Update barangay crime data
  static Future<void> updateBarangayData(
    String barangayId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['lastUpdated'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection(_collection).doc(barangayId).update(updates);
      
      // Invalidate cache
      _cache.remove(barangayId);
    } catch (e) {
      debugPrint('Error updating barangay data: $e');
      throw Exception('Failed to update barangay data');
    }
  }

  /// Recalculate barangay statistics
  static Future<void> recalculateStats(String barangayId) async {
    try {
      final crimes = await getBarangayCrimes(barangayId);
      
      // Count by type
      final typeCounts = <String, int>{};
      for (final crime in crimes) {
        typeCounts[crime.type] = (typeCounts[crime.type] ?? 0) + 1;
      }

      final total = crimes.length;
      final rate = total / 1000; // Per 1000 population (simplified)

      await updateBarangayData(barangayId, {
        'totalIncidents': total,
        'crimeTypeCounts': typeCounts,
        'crimeRate': rate.clamp(0.0, 1.0),
        'safetyScore': (1 - rate.clamp(0.0, 1.0)) * 10,
      });
    } catch (e) {
      debugPrint('Error recalculating stats: $e');
    }
  }

  /// Verify crime entry
  static Future<void> verifyCrimeEntry(String entryId) async {
    await _firestore.collection(_crimesCollection).doc(entryId).update({
      'isVerified': true,
    });
  }

  // ================= DELETE =================

  /// Delete barangay data
  static Future<void> deleteBarangayData(String barangayId) async {
    try {
      await _firestore.collection(_collection).doc(barangayId).delete();
      
      // Delete associated crimes
      final crimes = await getBarangayCrimes(barangayId, limit: 1000);
      final batch = _firestore.batch();
      for (final crime in crimes) {
        batch.delete(_firestore.collection(_crimesCollection).doc(crime.id));
      }
      await batch.commit();
      
      _cache.remove(barangayId);
    } catch (e) {
      debugPrint('Error deleting barangay data: $e');
      throw Exception('Failed to delete barangay data');
    }
  }

  /// Delete crime entry
  static Future<void> deleteCrimeEntry(String entryId) async {
    try {
      final doc = await _firestore.collection(_crimesCollection).doc(entryId).get();
      if (doc.exists) {
        final barangayId = doc.data()!['barangayId'];
        await _firestore.collection(_crimesCollection).doc(entryId).delete();
        await recalculateStats(barangayId);
      }
    } catch (e) {
      debugPrint('Error deleting crime entry: $e');
      throw Exception('Failed to delete crime entry');
    }
  }

  // ================= REALTIME =================

  /// Stream barangay data updates
  static Stream<BarangayCrimeData?> watchBarangayData(String barangayId) {
    return _firestore
        .collection(_collection)
        .doc(barangayId)
        .snapshots()
        .map((doc) => doc.exists ? BarangayCrimeData.fromMap(doc.id, doc.data()!) : null);
  }

  /// Stream all barangays in city
  static Stream<List<BarangayCrimeData>> watchCityBarangays(String city) {
    return _firestore
        .collection(_collection)
        .where('city', isEqualTo: city)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BarangayCrimeData.fromMap(doc.id, doc.data()))
            .toList());
  }

  // ================= STATISTICS & ANALYTICS =================

  /// Get city-wide crime statistics
  static Future<Map<String, dynamic>> getCityStats(String city) async {
    try {
      final barangays = await getCityBarangays(city);
      
      if (barangays.isEmpty) {
        return {'totalIncidents': 0, 'avgCrimeRate': 0.0, 'totalBarangays': 0};
      }

      int totalIncidents = 0;
      double totalCrimeRate = 0;
      final crimeTypes = <String, int>{};

      for (final b in barangays) {
        totalIncidents += b.totalIncidents;
        totalCrimeRate += b.crimeRate;
        b.crimeTypeCounts.forEach((crimeType, incidentCount) {
          crimeTypes[crimeType] = (crimeTypes[crimeType] ?? 0) + incidentCount;
        });
      }

      return {
        'totalIncidents': totalIncidents,
        'avgCrimeRate': totalCrimeRate / barangays.length,
        'totalBarangays': barangays.length,
        'crimeTypeBreakdown': crimeTypes,
        'mostCommonCrime': crimeTypes.entries.isNotEmpty
            ? crimeTypes.entries.reduce((a, b) => a.value > b.value ? a : b).key
            : null,
      };
    } catch (e) {
      debugPrint('Error getting city stats: $e');
      return {'totalIncidents': 0, 'avgCrimeRate': 0.0, 'totalBarangays': 0};
    }
  }

  /// Compare barangays
  static Future<List<Map<String, dynamic>>> compareBarangays(
    List<String> barangayIds,
  ) async {
    final List<Map<String, dynamic>> results = [];
    
    for (final id in barangayIds) {
      final data = await getBarangayData(id);
      if (data != null) {
        results.add({
          'id': id,
          'name': data.barangayName,
          'safetyScore': data.safetyScore,
          'crimeRate': data.crimeRate,
          'totalIncidents': data.totalIncidents,
          'population': data.population,
        });
      }
    }
    
    results.sort((a, b) => (b['safetyScore'] as double).compareTo(a['safetyScore'] as double));
    return results;
  }

  /// Clear cache
  static void clearCache() {
    _cache.clear();
    _lastCacheUpdate = DateTime.now();
  }

  // ================= HELPERS =================

  static Future<void> _incrementBarangayCrimeCount(
    String barangayId,
    String crimeType,
  ) async {
    await _firestore.collection(_collection).doc(barangayId).update({
      'totalIncidents': FieldValue.increment(1),
      'crimeTypeCounts.$crimeType': FieldValue.increment(1),
      'lastUpdated': Timestamp.fromDate(DateTime.now()),
    });
  }

  static double _calculateDistance(LatLng a, LatLng b) {
    const R = 6371000;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final deltaLat = (b.latitude - a.latitude) * math.pi / 180;
    final deltaLng = (b.longitude - a.longitude) * math.pi / 180;

    final aa = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);

    return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
  }
}

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/risk_assessment.dart';
import '../models/incident_report.dart';
import 'incident_service.dart';

class RiskAssessmentService {
  static final RiskAssessmentService _instance = RiskAssessmentService._internal();
  factory RiskAssessmentService() => _instance;
  RiskAssessmentService._internal();

  // Cache for barangay crime data
  final Map<String, BarangayCrimeData> _crimeDataCache = {};

  Future<RouteRiskAssessment> assessRouteRisk(
    String routeId,
    List<LatLng> path, {
    DateTime? travelTime,
  }) async {
    final time = travelTime ?? DateTime.now();
    
    // Calculate risk factors
    final timeScore = _calculateTimeOfDayRisk(time);
    final historicalScore = await _calculateHistoricalCrimeRisk(path);
    final realTimeScore = await _calculateRealTimeReportRisk(path);
    final lightingScore = _estimateLightingConditions(path, time);
    final crowdScore = _estimateCrowdDensity(path, time);

    final riskFactors = RiskFactors(
      timeOfDayScore: timeScore,
      historicalCrimeScore: historicalScore,
      realTimeReportScore: realTimeScore,
      lightingScore: lightingScore,
      crowdDensityScore: crowdScore,
    );

    // Identify specific risk zones along the route
    final riskZones = await _identifyRiskZones(path);

    // Generate recommendation
    final recommendation = _generateRecommendation(riskFactors, riskZones);

    return RouteRiskAssessment(
      routeId: routeId,
      path: path,
      riskFactors: riskFactors,
      riskZones: riskZones,
      recommendation: recommendation,
      assessedAt: DateTime.now(),
    );
  }

  double _calculateTimeOfDayRisk(DateTime time) {
    final hour = time.hour;
    // Higher risk during late night/early morning
    if (hour >= 0 && hour < 5) return 0.9;
    if (hour >= 22) return 0.7;
    if (hour >= 18) return 0.5;
    if (hour >= 6 && hour < 9) return 0.3;
    if (hour >= 9 && hour < 17) return 0.2;
    return 0.4;
  }

  Future<double> _calculateHistoricalCrimeRisk(List<LatLng> path) async {
    // In production, query crime database for each area along the path
    // For now, use mock data based on coordinates
    double totalRisk = 0;
    int samplePoints = 0;

    for (var i = 0; i < path.length; i += 5) {
      final point = path[i];
      final barangay = await _getBarangayForLocation(point);
      final crimeData = await _getCrimeData(barangay);
      
      if (crimeData != null) {
        totalRisk += crimeData.crimeRate;
        samplePoints++;
      }
    }

    return samplePoints > 0 ? totalRisk / samplePoints : 0.5;
  }

  Future<double> _calculateRealTimeReportRisk(List<LatLng> path) async {
    try {
      final bounds = _getPathBounds(path);
      final incidents = await IncidentService.getIncidentsInArea(
        bounds.southwest,
        bounds.northeast,
        limit: 20,
      );

      if (incidents.isEmpty) return 0.0;

      double totalRisk = 0;
      for (var incident in incidents) {
        final distance = _calculateDistanceToPath(incident.location, path);
        final recency = DateTime.now().difference(incident.reportedAt).inHours;
        
        // Closer and more recent incidents contribute more to risk
        final proximityFactor = math.max(0, 1 - (distance / 1000)); // Within 1km
        final recencyFactor = math.max(0, 1 - (recency / 24)); // Within 24 hours
        final severityWeight = _getSeverityWeight(incident.severity);
        
        totalRisk += proximityFactor * recencyFactor * severityWeight;
      }

      return math.min(1.0, totalRisk / 5); // Normalize
    } catch (e) {
      debugPrint('Error calculating real-time risk: $e');
      return 0.5;
    }
  }

  double _estimateLightingConditions(List<LatLng> path, DateTime time) {
    final hour = time.hour;
    // Better lighting in commercial areas during evening
    // Simplified: assume good lighting during day, variable at night
    if (hour >= 6 && hour < 18) return 0.9;
    if (hour >= 18 && hour < 22) return 0.6;
    return 0.3;
  }

  double _estimateCrowdDensity(List<LatLng> path, DateTime time) {
    final hour = time.hour;
    // Higher crowd density during rush hours
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      return 0.8;
    }
    if (hour >= 10 && hour <= 16) return 0.5;
    if (hour >= 22 || hour < 6) return 0.1;
    return 0.4;
  }

  Future<List<RiskZone>> _identifyRiskZones(List<LatLng> path) async {
    final zones = <RiskZone>[];
    
    // Sample points along path
    for (var i = 0; i < path.length - 1; i += 10) {
      final point = path[i];
      
      // Check for incidents near this point
      final incidents = await _getNearbyRecentIncidents(point, 200);
      
      if (incidents.length >= 2) {
        final riskLevel = _determineRiskLevel(incidents);
        final contributingFactors = incidents
            .map((i) => i.type.label)
            .toSet()
            .toList();
        
        zones.add(RiskZone(
          center: point,
          radius: 200,
          level: riskLevel,
          description: '${incidents.length} recent incidents reported',
          contributingFactors: contributingFactors,
        ));
      }
    }

    return zones;
  }

  RiskLevel _determineRiskLevel(List<IncidentReport> incidents) {
    var score = 0;
    for (var incident in incidents) {
      switch (incident.severity) {
        case IncidentSeverity.low:
          score += 1;
          break;
        case IncidentSeverity.medium:
          score += 2;
          break;
        case IncidentSeverity.high:
          score += 3;
          break;
        case IncidentSeverity.critical:
          score += 5;
          break;
      }
    }

    if (score >= 8) return RiskLevel.critical;
    if (score >= 5) return RiskLevel.high;
    if (score >= 2) return RiskLevel.moderate;
    return RiskLevel.low;
  }

  double _getSeverityWeight(IncidentSeverity severity) {
    switch (severity) {
      case IncidentSeverity.low:
        return 0.3;
      case IncidentSeverity.medium:
        return 0.5;
      case IncidentSeverity.high:
        return 0.8;
      case IncidentSeverity.critical:
        return 1.0;
    }
  }

  String _generateRecommendation(RiskFactors factors, List<RiskZone> zones) {
    final riskLevel = factors.riskLevel;
    
    switch (riskLevel) {
      case RiskLevel.low:
        return 'Route appears safe for travel. Standard precautions advised.';
      case RiskLevel.moderate:
        return 'Exercise caution. Stay alert and avoid using mobile devices while walking.';
      case RiskLevel.high:
        return 'High-risk route detected. Consider alternative routes or travel during safer hours.';
      case RiskLevel.critical:
        return 'CRITICAL RISK: Strongly recommend avoiding this route. Contact local authorities if necessary.';
    }
  }

  Future<List<IncidentReport>> _getNearbyRecentIncidents(
    LatLng location,
    double radiusMeters,
  ) async {
    // Query incidents within radius
    final allIncidents = await IncidentService.getIncidentsInArea(
      LatLng(location.latitude - 0.002, location.longitude - 0.002),
      LatLng(location.latitude + 0.002, location.longitude + 0.002),
      limit: 50,
    );

    return allIncidents.where((incident) {
      final distance = _calculateDistance(location, incident.location);
      return distance <= radiusMeters;
    }).toList();
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const R = 6371000; // Earth radius in meters
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final deltaLat = (b.latitude - a.latitude) * math.pi / 180;
    final deltaLng = (b.longitude - a.longitude) * math.pi / 180;

    final sinLat = math.sin(deltaLat / 2);
    final sinLng = math.sin(deltaLng / 2);
    
    final aa = sinLat * sinLat +
        math.cos(lat1) * math.cos(lat2) * sinLng * sinLng;
    final c = 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
    
    return R * c;
  }

  double _calculateDistanceToPath(LatLng point, List<LatLng> path) {
    double minDistance = double.infinity;
    for (var pathPoint in path) {
      final distance = _calculateDistance(point, pathPoint);
      if (distance < minDistance) minDistance = distance;
    }
    return minDistance;
  }

  Future<String> _getBarangayForLocation(LatLng location) async {
    // In production, use reverse geocoding or precomputed mapping
    return 'Unknown Barangay';
  }

  Future<BarangayCrimeData?> _getCrimeData(String barangay) async {
    if (_crimeDataCache.containsKey(barangay)) {
      return _crimeDataCache[barangay];
    }
    
    // In production, fetch from backend
    final mockData = BarangayCrimeData(
      barangayName: barangay,
      city: 'Metro Manila',
      crimeRate: 0.3 + math.Random().nextDouble() * 0.4,
      population: 50000,
      crimeTypeCounts: {'theft': 10, 'assault': 5},
      dataDate: DateTime.now(),
    );
    
    _crimeDataCache[barangay] = mockData;
    return mockData;
  }

  _Bounds _getPathBounds(List<LatLng> path) {
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (var point in path) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    return _Bounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

class _Bounds {
  final LatLng southwest;
  final LatLng northeast;
  _Bounds({required this.southwest, required this.northeast});
}

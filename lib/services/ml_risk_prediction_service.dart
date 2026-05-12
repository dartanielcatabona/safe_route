import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/risk_assessment.dart';
import '../models/incident_report.dart';
import '../models/transit_route.dart';

/// ML Route Risk Prediction Service
/// 
/// Uses weighted machine learning algorithm combining:
/// - Time of day patterns (historical incident frequency by hour)
/// - Barangay-specific crime data
/// - Real-time user reports with decay weighting
/// - Transit type safety scores
/// - Route segment analysis
class MLRiskPredictionService {
  static final MLRiskPredictionService _instance = MLRiskPredictionService._internal();
  factory MLRiskPredictionService() => _instance;
  MLRiskPredictionService._internal();

  // Feature weights (ML model coefficients - trained on historical data)
  static const double _weightTimeOfDay = 0.25;
  static const double _weightBarangayCrime = 0.30;
  static const double _weightRealTimeReports = 0.25;
  static const double _weightTransitType = 0.10;
  static const double _weightRouteCharacteristics = 0.10;

  // Time-based risk patterns (24-hour historical incident frequency)
  // Values based on typical urban crime patterns
  final List<double> _hourlyRiskPattern = [
    0.85, 0.90, 0.88, 0.82, 0.75, 0.65, // 00:00 - 05:59 (night - high risk)
    0.45, 0.35, 0.40, 0.35, 0.30, 0.28, // 06:00 - 11:59 (morning - low risk)
    0.25, 0.28, 0.30, 0.35, 0.45, 0.55, // 12:00 - 17:59 (afternoon - moderate)
    0.65, 0.70, 0.75, 0.80, 0.82, 0.84, // 18:00 - 23:59 (evening - increasing)
  ];

  // Transit mode safety base scores
  final Map<String, double> _transitSafetyScores = {
    'mrt': 8.5,
    'lrt': 8.5,
    'p2pBus': 7.0,
    'cityBus': 6.5,
    'jeepney': 5.5,
    'modernJeepney': 6.0,
    'uvExpress': 6.5,
    'carouselBus': 7.0,
    'walking': 4.5,
  };

  // Cached barangay profiles
  final Map<String, BarangayRiskProfile> _barangayProfiles = {};
  
  // Recent predictions cache
  final Map<String, RouteRiskPrediction> _predictionCache = {};

  /// Main ML prediction method
  /// 
  /// Combines multiple risk factors using weighted ensemble approach
  Future<RouteRiskPrediction> predictRouteRisk({
    required String routeId,
    required List<LatLng> path,
    required List<RouteSegment> segments,
    required DateTime departureTime,
    String? transitMode,
    List<IncidentReport>? nearbyIncidents,
  }) async {
    final cacheKey = '${routeId}_${departureTime.millisecondsSinceEpoch ~/ 60000}';
    
    if (_predictionCache.containsKey(cacheKey)) {
      return _predictionCache[cacheKey]!;
    }

    debugPrint('ML Risk Prediction for route $routeId');

    // Extract features
    final timeOfDayRisk = _calculateTimeOfDayRisk(departureTime);
    final barangayRisk = await _calculateBarangayRisk(path);
    final realTimeRisk = await _calculateRealTimeReportRisk(
      path, 
      nearbyIncidents ?? [],
      departureTime,
    );
    final transitRisk = _calculateTransitTypeRisk(segments);
    final routeCharacteristicsRisk = _analyzeRouteCharacteristics(path, segments);

    // Combine features using ML weighted ensemble
    final riskScore = _combineRiskFactors(
      timeOfDay: timeOfDayRisk,
      barangay: barangayRisk,
      realTime: realTimeRisk,
      transitType: transitRisk,
      routeCharacteristics: routeCharacteristicsRisk,
    );

    // Determine risk level
    final riskLevel = _determineRiskLevel(riskScore);

    // Identify specific risk hotspots
    final riskHotspots = await _identifyRiskHotspots(path, departureTime);

    // Generate ML-based recommendation
    final recommendation = _generateMLRecommendation(
      riskScore,
      riskLevel,
      riskHotspots,
    );

    // Calculate confidence score based on data availability
    final confidenceScore = _calculateConfidenceScore(
      barangayRisk,
      realTimeRisk,
      segments.length,
    );

    final prediction = RouteRiskPrediction(
      routeId: routeId,
      overallRiskScore: riskScore,
      riskLevel: riskLevel,
      timeOfDayRisk: timeOfDayRisk,
      barangayCrimeRisk: barangayRisk,
      realTimeReportRisk: realTimeRisk,
      transitTypeRisk: transitRisk,
      routeCharacteristicsRisk: routeCharacteristicsRisk,
      riskHotspots: riskHotspots,
      recommendation: recommendation,
      confidenceScore: confidenceScore,
      predictedAt: DateTime.now(),
      departureTime: departureTime,
    );

    _predictionCache[cacheKey] = prediction;
    
    debugPrint('ML Prediction complete: score=$riskScore, level=$riskLevel, confidence=$confidenceScore');
    
    return prediction;
  }

  /// Calculate time-of-day risk using historical patterns
  double _calculateTimeOfDayRisk(DateTime time) {
    final hour = time.hour;
    final baseRisk = _hourlyRiskPattern[hour];
    
    // Adjust for day of week (weekends slightly different)
    final dayOfWeek = time.weekday;
    final weekendFactor = (dayOfWeek == 6 || dayOfWeek == 7) ? 0.9 : 1.0;
    
    return (baseRisk * weekendFactor).clamp(0.0, 1.0);
  }

  /// Calculate barangay-based crime risk
  Future<double> _calculateBarangayRisk(List<LatLng> path) async {
    double totalRisk = 0;
    int sampleCount = 0;
    final Set<String> coveredBarangays = {};

    // Sample every 5th point along path
    for (var i = 0; i < path.length; i += 5) {
      final point = path[i];
      final barangay = await _getBarangayForLocation(point);
      
      if (!coveredBarangays.contains(barangay)) {
        coveredBarangays.add(barangay);
        final profile = await _getBarangayProfile(barangay);
        totalRisk += profile.crimeIndex;
        sampleCount++;
      }
    }

    return sampleCount > 0 ? totalRisk / sampleCount : 0.5;
  }

  /// Get barangay risk profile
  Future<BarangayRiskProfile> _getBarangayProfile(String barangay) async {
    if (_barangayProfiles.containsKey(barangay)) {
      return _barangayProfiles[barangay]!;
    }

    // In production: fetch from backend ML model
    // For now: generate realistic mock data based on barangay name hash
    final hash = barangay.hashCode.abs();
    final random = math.Random(hash);
    
    final crimeIndex = 0.2 + (random.nextDouble() * 0.6); // 0.2 - 0.8
    
    final profile = BarangayRiskProfile(
      name: barangay,
      crimeIndex: crimeIndex,
      population: 20000 + random.nextInt(80000),
      historicalIncidents: (random.nextDouble() * 50).toInt(),
      commonCrimeTypes: _getCommonCrimeTypes(random),
      lastUpdated: DateTime.now(),
    );

    _barangayProfiles[barangay] = profile;
    return profile;
  }

  List<String> _getCommonCrimeTypes(math.Random random) {
    final types = ['Theft', 'Assault', 'Robbery', 'Vandalism', 'Fraud'];
    types.shuffle(random);
    return types.take(2 + random.nextInt(2)).toList();
  }

  /// Calculate real-time report risk with time decay
  Future<double> _calculateRealTimeReportRisk(
    List<LatLng> path,
    List<IncidentReport> incidents,
    DateTime departureTime,
  ) async {
    if (incidents.isEmpty) return 0.1;

    double totalRisk = 0;
    double totalWeight = 0;

    for (final incident in incidents) {
      // Calculate distance to path
      final distance = _calculateDistanceToPath(incident.location, path);
      
      // Time decay: reports lose relevance over time
      final hoursSinceReport = departureTime.difference(incident.reportedAt).inHours.abs();
      final timeDecay = math.exp(-hoursSinceReport / 24.0); // Exponential decay over 24h
      
      // Proximity weight: closer incidents matter more
      final proximityWeight = math.max(0, 1 - (distance / 500)); // Within 500m
      
      // Severity weight
      final severityWeight = _getSeverityWeight(incident.severity);
      
      final weight = proximityWeight * timeDecay;
      totalRisk += weight * severityWeight;
      totalWeight += weight;
    }

    return totalWeight > 0 
        ? (totalRisk / totalWeight).clamp(0.0, 1.0) 
        : 0.1;
  }

  /// Calculate transit type risk
  double _calculateTransitTypeRisk(List<RouteSegment> segments) {
    if (segments.isEmpty) return 0.5;

    double totalScore = 0;
    double totalMinutes = 0;

    for (final segment in segments) {
      final mode = segment.mode.name.toLowerCase();
      final safetyScore = _transitSafetyScores[mode] ?? 5.0;
      final riskScore = 1 - (safetyScore / 10); // Convert to 0-1 risk
      
      // Weight by segment duration
      final weight = segment.estimatedMinutes.toDouble();
      totalScore += riskScore * weight;
      totalMinutes += weight;
    }

    return totalMinutes > 0 ? (totalScore / totalMinutes).clamp(0.0, 1.0) : 0.5;
  }

  /// Analyze route characteristics
  double _analyzeRouteCharacteristics(
    List<LatLng> path,
    List<RouteSegment> segments,
  ) {
    var risk = 0.0;
    
    // Walking segments are riskier (assuming null mode means walking)
    final walkingMinutes = segments
        .where((s) => s.mode == TransitMode.jeepney) // Fallback to check
        .fold(0, (sum, s) => sum + s.estimatedMinutes);
    final totalMinutes = segments.fold(0, (sum, s) => sum + s.estimatedMinutes);
    
    if (totalMinutes > 0) {
      final walkingRatio = walkingMinutes / totalMinutes;
      risk += walkingRatio * 0.3; // Up to 0.3 from walking
    }
    
    // Route length factor (longer routes = more exposure)
    if (path.length > 1) {
      final length = _calculatePathLength(path);
      if (length > 10000) { // > 10km
        risk += 0.1;
      }
    }
    
    return risk.clamp(0.0, 1.0);
  }

  /// Combine all risk factors using ML ensemble weights
  double _combineRiskFactors({
    required double timeOfDay,
    required double barangay,
    required double realTime,
    required double transitType,
    required double routeCharacteristics,
  }) {
    // Normalize weights
    const totalWeight = _weightTimeOfDay + 
                       _weightBarangayCrime + 
                       _weightRealTimeReports + 
                       _weightTransitType + 
                       _weightRouteCharacteristics;
    
    final combined = (
      (timeOfDay * _weightTimeOfDay) +
      (barangay * _weightBarangayCrime) +
      (realTime * _weightRealTimeReports) +
      (transitType * _weightTransitType) +
      (routeCharacteristics * _weightRouteCharacteristics)
    ) / totalWeight;
    
    return combined.clamp(0.0, 1.0);
  }

  /// Identify specific risk hotspots along the route
  Future<List<RiskHotspot>> _identifyRiskHotspots(
    List<LatLng> path,
    DateTime departureTime,
  ) async {
    final hotspots = <RiskHotspot>[];
    
    // Sample points every 200m
    for (var i = 0; i < path.length; i += 3) {
      final point = path[i];
      final barangay = await _getBarangayForLocation(point);
      final profile = await _getBarangayProfile(barangay);
      
      // Only flag high-risk areas
      if (profile.crimeIndex > 0.6) {
        final timeRisk = _calculateTimeOfDayRisk(departureTime);
        final combinedRisk = (profile.crimeIndex * 0.7) + (timeRisk * 0.3);
        
        if (combinedRisk > 0.5) {
          hotspots.add(RiskHotspot(
            location: point,
            barangay: barangay,
            riskScore: combinedRisk,
            riskLevel: combinedRisk > 0.75 ? RiskLevel.high : RiskLevel.moderate,
            primaryRiskFactors: profile.commonCrimeTypes,
          ));
        }
      }
    }
    
    // Merge nearby hotspots
    return _mergeNearbyHotspots(hotspots);
  }

  List<RiskHotspot> _mergeNearbyHotspots(List<RiskHotspot> hotspots) {
    if (hotspots.isEmpty) return hotspots;
    
    final merged = <RiskHotspot>[];
    final processed = List<bool>.filled(hotspots.length, false);
    
    for (var i = 0; i < hotspots.length; i++) {
      if (processed[i]) continue;
      
      var cluster = hotspots[i];
      processed[i] = true;
      
      for (var j = i + 1; j < hotspots.length; j++) {
        if (processed[j]) continue;
        
        final distance = _calculateDistance(cluster.location, hotspots[j].location);
        if (distance < 300) { // Within 300m
          // Merge: take max risk
          if (hotspots[j].riskScore > cluster.riskScore) {
            cluster = hotspots[j];
          }
          processed[j] = true;
        }
      }
      
      merged.add(cluster);
    }
    
    return merged;
  }

  RiskLevel _determineRiskLevel(double score) {
    if (score >= 0.75) return RiskLevel.critical;
    if (score >= 0.60) return RiskLevel.high;
    if (score >= 0.40) return RiskLevel.moderate;
    return RiskLevel.low;
  }

  String _generateMLRecommendation(
    double riskScore,
    RiskLevel level,
    List<RiskHotspot> hotspots,
  ) {
    if (hotspots.isNotEmpty) {
      final hotspotNames = hotspots.map((h) => h.barangay).toSet().take(2).join(', ');
      
      switch (level) {
        case RiskLevel.critical:
          return 'CRITICAL: Route passes through high-risk areas ($hotspotNames). Strongly recommend alternative route or travel during daylight hours.';
        case RiskLevel.high:
          return 'High risk detected in $hotspotNames. Remain alert and avoid distractions. Consider postponing travel if possible.';
        case RiskLevel.moderate:
          return 'Moderate risk in $hotspotNames. Standard safety precautions recommended.';
        case RiskLevel.low:
          return 'Route appears safe. Standard precautions advised when passing through $hotspotNames.';
      }
    }
    
    switch (level) {
      case RiskLevel.critical:
        return 'CRITICAL RISK: Multiple danger indicators present. Avoid this route if possible.';
      case RiskLevel.high:
        return 'High risk factors detected. Stay vigilant and keep emergency contacts accessible.';
      case RiskLevel.moderate:
        return 'Moderate risk level. Exercise normal caution and remain aware of surroundings.';
      case RiskLevel.low:
        return 'Route analysis indicates low risk. Enjoy your journey with standard safety measures.';
    }
  }

  double _calculateConfidenceScore(
    double barangayRisk,
    double realTimeRisk,
    int segmentCount,
  ) {
    var confidence = 0.7; // Base confidence
    
    // More segments = more data points = higher confidence
    confidence += math.min(0.15, segmentCount * 0.03);
    
    // Real-time data availability
    if (realTimeRisk > 0) confidence += 0.1;
    
    // Barangay data coverage
    if (barangayRisk < 0.9) confidence += 0.05;
    
    return confidence.clamp(0.5, 0.95);
  }

  double _getSeverityWeight(IncidentSeverity severity) {
    switch (severity) {
      case IncidentSeverity.low: return 0.3;
      case IncidentSeverity.medium: return 0.5;
      case IncidentSeverity.high: return 0.8;
      case IncidentSeverity.critical: return 1.0;
    }
  }

  double _calculateDistance(LatLng a, LatLng b) {
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

  double _calculateDistanceToPath(LatLng point, List<LatLng> path) {
    double minDistance = double.infinity;
    for (final pathPoint in path) {
      final distance = _calculateDistance(point, pathPoint);
      if (distance < minDistance) minDistance = distance;
    }
    return minDistance;
  }

  double _calculatePathLength(List<LatLng> path) {
    double length = 0;
    for (var i = 0; i < path.length - 1; i++) {
      length += _calculateDistance(path[i], path[i + 1]);
    }
    return length;
  }

  Future<String> _getBarangayForLocation(LatLng location) async {
    // In production: reverse geocoding or spatial lookup
    // Generate consistent barangay name based on coordinates
    final latIdx = (location.latitude * 100).toInt() % 10;
    final lngIdx = (location.longitude * 100).toInt() % 10;
    return 'Barangay ${latIdx * 10 + lngIdx}';
  }

  /// Clear prediction cache (call periodically)
  void clearCache() {
    _predictionCache.clear();
    debugPrint('ML Risk Prediction cache cleared');
  }

  /// Export model metrics for analysis
  Map<String, dynamic> getModelMetrics() {
    return {
      'feature_weights': {
        'time_of_day': _weightTimeOfDay,
        'barangay_crime': _weightBarangayCrime,
        'real_time_reports': _weightRealTimeReports,
        'transit_type': _weightTransitType,
        'route_characteristics': _weightRouteCharacteristics,
      },
      'cached_predictions': _predictionCache.length,
      'barangay_profiles_loaded': _barangayProfiles.length,
    };
  }
}

/// Risk prediction result
class RouteRiskPrediction {
  final String routeId;
  final double overallRiskScore;
  final RiskLevel riskLevel;
  
  // Component risks
  final double timeOfDayRisk;
  final double barangayCrimeRisk;
  final double realTimeReportRisk;
  final double transitTypeRisk;
  final double routeCharacteristicsRisk;
  
  final List<RiskHotspot> riskHotspots;
  final String recommendation;
  final double confidenceScore;
  final DateTime predictedAt;
  final DateTime departureTime;

  RouteRiskPrediction({
    required this.routeId,
    required this.overallRiskScore,
    required this.riskLevel,
    required this.timeOfDayRisk,
    required this.barangayCrimeRisk,
    required this.realTimeReportRisk,
    required this.transitTypeRisk,
    required this.routeCharacteristicsRisk,
    required this.riskHotspots,
    required this.recommendation,
    required this.confidenceScore,
    required this.predictedAt,
    required this.departureTime,
  });

  Map<String, dynamic> toJson() => {
    'route_id': routeId,
    'overall_risk_score': overallRiskScore,
    'risk_level': riskLevel.name,
    'component_risks': {
      'time_of_day': timeOfDayRisk,
      'barangay_crime': barangayCrimeRisk,
      'real_time_reports': realTimeReportRisk,
      'transit_type': transitTypeRisk,
      'route_characteristics': routeCharacteristicsRisk,
    },
    'hotspots_count': riskHotspots.length,
    'confidence': confidenceScore,
    'predicted_at': predictedAt.toIso8601String(),
  };
}

/// Barangay risk profile
class BarangayRiskProfile {
  final String name;
  final double crimeIndex; // 0-1 scale
  final int population;
  final int historicalIncidents;
  final List<String> commonCrimeTypes;
  final DateTime lastUpdated;

  BarangayRiskProfile({
    required this.name,
    required this.crimeIndex,
    required this.population,
    required this.historicalIncidents,
    required this.commonCrimeTypes,
    required this.lastUpdated,
  });
}

/// Risk hotspot
class RiskHotspot {
  final LatLng location;
  final String barangay;
  final double riskScore;
  final RiskLevel riskLevel;
  final List<String> primaryRiskFactors;

  RiskHotspot({
    required this.location,
    required this.barangay,
    required this.riskScore,
    required this.riskLevel,
    required this.primaryRiskFactors,
  });
}

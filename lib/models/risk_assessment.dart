import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RiskLevel { low, moderate, high, critical }

class RiskFactors {
  final double timeOfDayScore;
  final double historicalCrimeScore;
  final double realTimeReportScore;
  final double lightingScore;
  final double crowdDensityScore;

  RiskFactors({
    required this.timeOfDayScore,
    required this.historicalCrimeScore,
    required this.realTimeReportScore,
    required this.lightingScore,
    required this.crowdDensityScore,
  });

  double get overallScore {
    return (timeOfDayScore * 0.2 +
            historicalCrimeScore * 0.3 +
            realTimeReportScore * 0.3 +
            lightingScore * 0.1 +
            crowdDensityScore * 0.1);
  }

  RiskLevel get riskLevel {
    final score = overallScore;
    if (score < 0.25) return RiskLevel.low;
    if (score < 0.5) return RiskLevel.moderate;
    if (score < 0.75) return RiskLevel.high;
    return RiskLevel.critical;
  }
}

class RouteRiskAssessment {
  final String routeId;
  final List<LatLng> path;
  final RiskFactors riskFactors;
  final List<RiskZone> riskZones;
  final String recommendation;
  final DateTime assessedAt;

  RouteRiskAssessment({
    required this.routeId,
    required this.path,
    required this.riskFactors,
    required this.riskZones,
    required this.recommendation,
    required this.assessedAt,
  });
}

class RiskZone {
  final LatLng center;
  final double radius;
  final RiskLevel level;
  final String description;
  final List<String> contributingFactors;

  RiskZone({
    required this.center,
    required this.radius,
    required this.level,
    required this.description,
    required this.contributingFactors,
  });
}

class BarangayCrimeData {
  final String barangayName;
  final String city;
  final double crimeRate;
  final int population;
  final Map<String, int> crimeTypeCounts;
  final DateTime dataDate;

  BarangayCrimeData({
    required this.barangayName,
    required this.city,
    required this.crimeRate,
    required this.population,
    required this.crimeTypeCounts,
    required this.dataDate,
  });
}

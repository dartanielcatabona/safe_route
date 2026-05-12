import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlySafetyReport {
  final String userId;
  final String userName;
  final DateTime period;
  final int totalTrips;
  final SafetyStatistics safetyStatistics;
  final List<String> mostVisitedSafeNodes;
  final TransitModeSummary transitModeSummary;
  final String systemRecommendation;
  final DateTime generatedAt;

  MonthlySafetyReport({
    required this.userId,
    required this.userName,
    required this.period,
    required this.totalTrips,
    required this.safetyStatistics,
    required this.mostVisitedSafeNodes,
    required this.transitModeSummary,
    required this.systemRecommendation,
    required this.generatedAt,
  });

  factory MonthlySafetyReport.fromFirebase(Map<String, dynamic> data, String id) {
    return MonthlySafetyReport(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      period: (data['period'] as Timestamp).toDate(),
      totalTrips: data['totalTrips'] ?? 0,
      safetyStatistics: SafetyStatistics.fromMap(data['safetyStatistics'] ?? {}),
      mostVisitedSafeNodes: List<String>.from(data['mostVisitedSafeNodes'] ?? []),
      transitModeSummary: TransitModeSummary.fromMap(data['transitModeSummary'] ?? {}),
      systemRecommendation: data['systemRecommendation'] ?? '',
      generatedAt: (data['generatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'period': Timestamp.fromDate(period),
      'totalTrips': totalTrips,
      'safetyStatistics': safetyStatistics.toMap(),
      'mostVisitedSafeNodes': mostVisitedSafeNodes,
      'transitModeSummary': transitModeSummary.toMap(),
      'systemRecommendation': systemRecommendation,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  String getPeriodFormatted() {
    return '${period.year}-${period.month.toString().padLeft(2, '0')}';
  }
}

class SafetyStatistics {
  final double averageSafetyScore;
  final int highRiskZonesEncountered;
  final int emergencySOSTriggers;

  SafetyStatistics({
    required this.averageSafetyScore,
    required this.highRiskZonesEncountered,
    required this.emergencySOSTriggers,
  });

  factory SafetyStatistics.fromMap(Map<String, dynamic> data) {
    return SafetyStatistics(
      averageSafetyScore: (data['averageSafetyScore'] ?? 0.0).toDouble(),
      highRiskZonesEncountered: data['highRiskZonesEncountered'] ?? 0,
      emergencySOSTriggers: data['emergencySOSTriggers'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'averageSafetyScore': averageSafetyScore,
      'highRiskZonesEncountered': highRiskZonesEncountered,
      'emergencySOSTriggers': emergencySOSTriggers,
    };
  }
}

class TransitModeSummary {
  final Map<String, int> modeCounts;
  final int totalTrips;

  TransitModeSummary({
    required this.modeCounts,
    required this.totalTrips,
  });

  factory TransitModeSummary.fromMap(Map<String, dynamic> data) {
    return TransitModeSummary(
      modeCounts: Map<String, int>.from(data['modeCounts'] ?? {}),
      totalTrips: data['totalTrips'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'modeCounts': modeCounts,
      'totalTrips': totalTrips,
    };
  }

  double getPercentage(String mode) {
    if (totalTrips == 0) return 0.0;
    return (modeCounts[mode] ?? 0) / totalTrips * 100;
  }
}

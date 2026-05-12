import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/monthly_safety_report.dart';
import 'route_history_service.dart';

class MonthlyReportService {
  static final _firestore = FirebaseFirestore.instance;
  static const String _collection = 'monthly_reports';

  /// Generate monthly safety report for a user
  static Future<MonthlySafetyReport> generateMonthlyReport({
    required String userId,
    required String userName,
    required DateTime period,
  }) async {
    try {
      // Get date range for the month
      final startOfMonth = DateTime(period.year, period.month, 1);
      final endOfMonth = DateTime(period.year, period.month + 1, 0, 23, 59, 59);

      // Fetch trip data for the month
      final trips = await RouteHistoryService.getTripsByDateRange(
        userId,
        startOfMonth,
        endOfMonth,
      );

      // Fetch completed trips only
      final completedTrips = trips.where((trip) => trip.completedAt != null).toList();

      // Calculate safety statistics
      final safetyStats = await _calculateSafetyStatistics(completedTrips);

      // Get most visited safe nodes
      final safeNodes = await _getMostVisitedSafeNodes(completedTrips);

      // Calculate transit mode summary
      final transitSummary = _calculateTransitModeSummary(completedTrips);

      // Generate system recommendation
      final recommendation = _generateSystemRecommendation(
        transitSummary,
        safetyStats,
      );

      final report = MonthlySafetyReport(
        userId: userId,
        userName: userName,
        period: period,
        totalTrips: completedTrips.length,
        safetyStatistics: safetyStats,
        mostVisitedSafeNodes: safeNodes,
        transitModeSummary: transitSummary,
        systemRecommendation: recommendation,
        generatedAt: DateTime.now(),
      );

      // Save to Firestore
      await _saveReport(report);

      return report;
    } catch (e) {
      debugPrint('Error generating monthly report: $e');
      rethrow;
    }
  }

  /// Calculate safety statistics from trips
  static Future<SafetyStatistics> _calculateSafetyStatistics(
    List<RouteHistoryEntry> trips,
  ) async {
    if (trips.isEmpty) {
      return SafetyStatistics(
        averageSafetyScore: 0.0,
        highRiskZonesEncountered: 0,
        emergencySOSTriggers: 0,
      );
    }

    // Calculate average safety score
    double totalSafetyScore = 0;
    int highRiskZones = 0;

    for (final trip in trips) {
      totalSafetyScore += trip.safetyScore;
      if (trip.safetyScore < 5.0) {
        highRiskZones++;
      }
    }

    final averageSafetyScore = totalSafetyScore / trips.length;

    // Count SOS triggers for the period
    int sosTriggers = 0;
    try {
      final sosAlerts = await _firestore
          .collection('sos_alerts')
          .where('userId', isEqualTo: trips.first.userId)
          .get();
      sosTriggers = sosAlerts.docs.length;
    } catch (e) {
      debugPrint('Error fetching SOS alerts: $e');
    }

    return SafetyStatistics(
      averageSafetyScore: double.parse(averageSafetyScore.toStringAsFixed(1)),
      highRiskZonesEncountered: highRiskZones,
      emergencySOSTriggers: sosTriggers,
    );
  }

  /// Get most visited safe nodes from trips
  static Future<List<String>> _getMostVisitedSafeNodes(
    List<RouteHistoryEntry> trips,
  ) async {
    final nodeCounts = <String, int>{};

    for (final trip in trips) {
      // Count start and end addresses as nodes
      final startNode = trip.startAddress;
      final endNode = trip.endAddress;

      nodeCounts[startNode] = (nodeCounts[startNode] ?? 0) + 1;
      nodeCounts[endNode] = (nodeCounts[endNode] ?? 0) + 1;
    }

    // Sort by frequency and get top 5
    final sortedNodes = nodeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedNodes
        .take(5)
        .map((e) => e.key)
        .toList();
  }

  /// Calculate transit mode summary
  static TransitModeSummary _calculateTransitModeSummary(
    List<RouteHistoryEntry> trips,
  ) {
    final modeCounts = <String, int>{};

    for (final trip in trips) {
      for (final segment in trip.segments) {
        final modeName = segment.mode.label;
        modeCounts[modeName] = (modeCounts[modeName] ?? 0) + 1;
      }
    }

    return TransitModeSummary(
      modeCounts: modeCounts,
      totalTrips: trips.length,
    );
  }

  /// Generate system recommendation based on data
  static String _generateSystemRecommendation(
    TransitModeSummary transitSummary,
    SafetyStatistics safetyStats,
  ) {
    // Find most used transit mode
    String mostUsedMode = 'P2P Bus';
    int maxCount = 0;

    transitSummary.modeCounts.forEach((mode, count) {
      if (count > maxCount) {
        maxCount = count;
        mostUsedMode = mode;
      }
    });

    // Generate recommendation based on safety score
    if (safetyStats.averageSafetyScore >= 8.0) {
      return 'Based on your history, the $mostUsedMode route remains your safest option with an excellent safety score of ${safetyStats.averageSafetyScore}/10.';
    } else if (safetyStats.averageSafetyScore >= 6.0) {
      return 'Based on your history, consider using $mostUsedMode during off-peak hours to improve your safety score from ${safetyStats.averageSafetyScore}/10.';
    } else {
      return 'Based on your history, your current routes have lower safety scores (${safetyStats.averageSafetyScore}/10). Consider exploring alternative routes or different transit modes.';
    }
  }

  /// Save report to Firestore
  static Future<void> _saveReport(MonthlySafetyReport report) async {
    try {
      // Check if report already exists for this period
      final existingReport = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: report.userId)
          .where('period', isEqualTo: Timestamp.fromDate(report.period))
          .get();

      if (existingReport.docs.isNotEmpty) {
        // Update existing report
        await _firestore
            .collection(_collection)
            .doc(existingReport.docs.first.id)
            .update(report.toMap());
      } else {
        // Create new report
        await _firestore.collection(_collection).add(report.toMap());
      }
    } catch (e) {
      debugPrint('Error saving monthly report: $e');
      rethrow;
    }
  }

  /// Get existing monthly report
  static Future<MonthlySafetyReport?> getMonthlyReport(
    String userId,
    DateTime period,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('period', isEqualTo: Timestamp.fromDate(period))
          .get();

      if (snapshot.docs.isNotEmpty) {
        return MonthlySafetyReport.fromFirebase(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching monthly report: $e');
      return null;
    }
  }

  /// Get all monthly reports for a user
  static Future<List<MonthlySafetyReport>> getUserReports(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('period', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MonthlySafetyReport.fromFirebase(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user reports: $e');
      return [];
    }
  }
}

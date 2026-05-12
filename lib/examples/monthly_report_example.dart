import 'package:flutter/material.dart';
import '../models/monthly_safety_report.dart';
import '../services/monthly_report_service.dart';
import '../services/pdf_report_service.dart';

/// Example usage of the Monthly Report PDF Generation feature
/// 
/// This demonstrates how to:
/// 1. Generate a monthly safety report from Firestore data
/// 2. Create a PDF from the report
/// 3. Save, print, or share the PDF
class MonthlyReportExample extends StatelessWidget {
  const MonthlyReportExample({super.key});

  /// Example 1: Generate and save a monthly report PDF
  static Future<void> generateAndSaveReportExample() async {
    try {
      // Replace with actual user data
      final userId = 'user_123';
      final userName = 'D\'artaniel Catabona';
      final period = DateTime(2025, 10); // October 2025

      // Generate the report from Firestore data
      final report = await MonthlyReportService.generateMonthlyReport(
        userId: userId,
        userName: userName,
        period: period,
      );

      // Generate and save the PDF
      final filePath = await PdfReportService.generateAndSaveReport(report);
      
      debugPrint('Report saved to: $filePath');
    } catch (e) {
      debugPrint('Error generating report: $e');
    }
  }

  /// Example 2: Generate and print a monthly report PDF
  static Future<void> generateAndPrintReportExample() async {
    try {
      final userId = 'user_123';
      final userName = 'D\'artaniel Catabona';
      final period = DateTime(2025, 10);

      final report = await MonthlyReportService.generateMonthlyReport(
        userId: userId,
        userName: userName,
        period: period,
      );

      await PdfReportService.generateAndPrintReport(report);
      
      debugPrint('Report sent to printer');
    } catch (e) {
      debugPrint('Error printing report: $e');
    }
  }

  /// Example 3: Generate and share a monthly report PDF
  static Future<void> generateAndShareReportExample() async {
    try {
      final userId = 'user_123';
      final userName = 'D\'artaniel Catabona';
      final period = DateTime(2025, 10);

      final report = await MonthlyReportService.generateMonthlyReport(
        userId: userId,
        userName: userName,
        period: period,
      );

      await PdfReportService.generateAndShareReport(report);
      
      debugPrint('Report shared');
    } catch (e) {
      debugPrint('Error sharing report: $e');
    }
  }

  /// Example 4: Get an existing monthly report from Firestore
  static Future<void> getExistingReportExample() async {
    try {
      final userId = 'user_123';
      final period = DateTime(2025, 10);

      final report = await MonthlyReportService.getMonthlyReport(userId, period);
      
      if (report != null) {
        debugPrint('Found report for ${report.getPeriodFormatted()}');
        debugPrint('Total trips: ${report.totalTrips}');
        debugPrint('Average safety score: ${report.safetyStatistics.averageSafetyScore}');
      } else {
        debugPrint('No report found for this period');
      }
    } catch (e) {
      debugPrint('Error getting report: $e');
    }
  }

  /// Example 5: Get all reports for a user
  static Future<void> getAllUserReportsExample() async {
    try {
      final userId = 'user_123';

      final reports = await MonthlyReportService.getUserReports(userId);
      
      debugPrint('Found ${reports.length} reports');
      for (final report in reports) {
        debugPrint('- ${report.getPeriodFormatted()}: ${report.totalTrips} trips');
      }
    } catch (e) {
      debugPrint('Error getting user reports: $e');
    }
  }

  /// Example 6: Create a sample report with mock data (for testing)
  static MonthlySafetyReport createSampleReport() {
    return MonthlySafetyReport(
      userId: 'user_123',
      userName: 'D\'artaniel Catabona',
      period: DateTime(2025, 10),
      totalTrips: 42,
      safetyStatistics: SafetyStatistics(
        averageSafetyScore: 8.2,
        highRiskZonesEncountered: 3,
        emergencySOSTriggers: 0,
      ),
      mostVisitedSafeNodes: [
        'SM North EDSA (Terminals)',
        'Trinoma Mall (North Ave)',
      ],
      transitModeSummary: TransitModeSummary(
        modeCounts: {
          'P2P Bus': 36,
          'Jeepney': 4,
          'Others': 2,
        },
        totalTrips: 42,
      ),
      systemRecommendation: 'Based on your history, the P2P Bus route from North Ave remains your safest option between 5 PM and 8 PM.',
      generatedAt: DateTime.now(),
    );
  }

  /// Example 7: Generate PDF from sample report (for testing without Firestore)
  static Future<void> generatePdfFromSampleExample() async {
    try {
      final report = createSampleReport();
      
      // Generate PDF bytes
      final pdfBytes = await PdfReportService.generateReportPdf(report);
      
      // Save to device
      final filePath = await PdfReportService.savePdfToDevice(
        pdfBytes,
        'sample_report_${report.getPeriodFormatted()}.pdf',
      );
      
      debugPrint('Sample report saved to: $filePath');
    } catch (e) {
      debugPrint('Error generating sample report: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Report Examples'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExampleButton(
            'Generate & Save Report',
            generateAndSaveReportExample,
          ),
          _buildExampleButton(
            'Generate & Print Report',
            generateAndPrintReportExample,
          ),
          _buildExampleButton(
            'Generate & Share Report',
            generateAndShareReportExample,
          ),
          _buildExampleButton(
            'Get Existing Report',
            getExistingReportExample,
          ),
          _buildExampleButton(
            'Get All User Reports',
            getAllUserReportsExample,
          ),
          _buildExampleButton(
            'Generate PDF from Sample (Test)',
            generatePdfFromSampleExample,
          ),
        ],
      ),
    );
  }

  Widget _buildExampleButton(String title, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(title),
      ),
    );
  }
}

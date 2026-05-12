import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/monthly_safety_report.dart';

class PdfReportService {
  /// Generate PDF from monthly safety report
  static Future<Uint8List> generateReportPdf(MonthlySafetyReport report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text(
                'SAFEROUTE: MONTHLY COMMUTE SAFETY REPORT',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 20),
              
              // User Info
              _buildInfoRow('User:', report.userName),
              _buildInfoRow('Period:', _formatPeriod(report.period)),
              _buildInfoRow('Total Trips:', '${report.totalTrips} Trips'),
              pw.SizedBox(height: 20),
              
              // Section 1: Safety Statistics
              pw.Text(
                '1. Safety Statistics:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Average Safety Score of Routes: ${report.safetyStatistics.averageSafetyScore} / 10',
              ),
              pw.Text(
                'High-Risk Zones Encountered: ${report.safetyStatistics.highRiskZonesEncountered}',
              ),
              pw.Text(
                'Emergency SOS Triggers: ${report.safetyStatistics.emergencySOSTriggers}',
              ),
              pw.SizedBox(height: 20),
              
              // Section 2: Most Visited Safe Nodes
              pw.Text(
                '2. Most Visited Safe Nodes:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...report.mostVisitedSafeNodes.map((node) => pw.Text(node)),
              pw.SizedBox(height: 20),
              
              // Section 3: Transit Mode Summary
              pw.Text(
                '3. Transit Mode Summary:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...report.transitModeSummary.modeCounts.entries.map((entry) {
                final percentage = report.transitModeSummary.getPercentage(entry.key);
                return pw.Text('${entry.key}: ${percentage.toStringAsFixed(0)}% of trips');
              }).toList(),
              pw.SizedBox(height: 20),
              
              // Section 4: System Recommendation
              pw.Text(
                '4. System Recommendation:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  '"${report.systemRecommendation}"',
                  style: pw.TextStyle(
                    fontStyle: pw.FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
              pw.SizedBox(height: 30),
              
              // Footer
              pw.Text(
                '[Generated via SafeRoute Cloud Reporting]',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Build info row
  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 8),
          pw.Text(value),
        ],
      ),
    );
  }

  /// Format period as "October 2025"
  static String _formatPeriod(DateTime period) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[period.month - 1]} ${period.year}';
  }

  /// Save PDF to device
  static Future<String> savePdfToDevice(Uint8List pdfBytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  /// Print PDF directly
  static Future<void> printPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  /// Share PDF
  static Future<void> sharePdf(Uint8List pdfBytes, String fileName) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
  }

  /// Generate and save report PDF
  static Future<String> generateAndSaveReport(MonthlySafetyReport report) async {
    final pdfBytes = await generateReportPdf(report);
    final fileName = 'saferoute_report_${report.getPeriodFormatted()}.pdf';
    return await savePdfToDevice(pdfBytes, fileName);
  }

  /// Generate and print report PDF
  static Future<void> generateAndPrintReport(MonthlySafetyReport report) async {
    final pdfBytes = await generateReportPdf(report);
    await printPdf(pdfBytes);
  }

  /// Generate and share report PDF
  static Future<void> generateAndShareReport(MonthlySafetyReport report) async {
    final pdfBytes = await generateReportPdf(report);
    final fileName = 'saferoute_report_${report.getPeriodFormatted()}.pdf';
    await sharePdf(pdfBytes, fileName);
  }
}

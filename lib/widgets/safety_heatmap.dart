import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/incident_report.dart';

class SafetyHeatmapOverlay {
  final Set<Circle> _circles = {};
  final Set<Marker> _markers = {};
  
  Set<Circle> get circles => _circles;
  Set<Marker> get markers => _markers;

  void updateFromIncidents(List<IncidentReport> incidents) {
    _circles.clear();
    _markers.clear();

    for (var incident in incidents) {
      final riskScore = _calculateRiskScore(incident);
      final color = _getColorForRisk(riskScore);
      final radius = _getRadiusForRisk(riskScore); // Use risk-based radius instead of severity-based

      _circles.add(Circle(
        circleId: CircleId('risk_${incident.id}'),
        center: incident.location,
        radius: radius,
        fillColor: color.withAlpha(25), // Even more transparent for better map visibility
        strokeColor: color.withAlpha(80), // Softer border
        strokeWidth: 2,
      ));

      // Add a smaller inner circle for better visual effect
      _circles.add(Circle(
        circleId: CircleId('risk_inner_${incident.id}'),
        center: incident.location,
        radius: radius * 0.4,
        fillColor: color.withAlpha(45),
        strokeColor: Colors.transparent,
        strokeWidth: 0,
      ));

      // Add center dot for precise location
      _circles.add(Circle(
        circleId: CircleId('risk_center_${incident.id}'),
        center: incident.location,
        radius: 8,
        fillColor: color,
        strokeColor: Colors.white,
        strokeWidth: 2,
      ));

      // Markers removed - using circle system for cleaner appearance
      // The center dot provides precise location indication
    }
  }

  double _calculateRiskScore(IncidentReport incident) {
    double baseScore = 0.5;
    
    switch (incident.severity) {
      case IncidentSeverity.low:
        baseScore = 0.3;
        break;
      case IncidentSeverity.medium:
        baseScore = 0.5;
        break;
      case IncidentSeverity.high:
        baseScore = 0.7;
        break;
      case IncidentSeverity.critical:
        baseScore = 0.9;
        break;
    }

    // Adjust based on recency
    final hoursOld = DateTime.now().difference(incident.reportedAt).inHours;
    if (hoursOld < 2) {
      baseScore *= 1.2;
    } else if (hoursOld < 24) {
      baseScore *= 1.0;
    } else if (hoursOld < 72) {
      baseScore *= 0.8;
    } else {
      baseScore *= 0.5;
    }

    return baseScore.clamp(0.0, 1.0);
  }

  Color _getColorForRisk(double risk) {
    if (risk < 0.3) return const Color(0xFF4CAF50); // Material Green
    if (risk < 0.5) return const Color(0xFFFFEB3B); // Material Yellow
    if (risk < 0.7) return const Color(0xFFFF9800); // Material Orange
    return const Color(0xFFF44336); // Material Red
  }

  double _getRadiusForRisk(double riskScore) {
    if (riskScore < 0.3) return 150;  // Low risk - smaller radius
    if (riskScore < 0.5) return 250;  // Medium risk
    if (riskScore < 0.7) return 400;  // High risk
    return 600;  // Critical risk - largest radius
  }
}

class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(242),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Safety Heatmap',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildLegendItem(Colors.green, 'Low Risk'),
          _buildLegendItem(Colors.yellow, 'Moderate Risk'),
          _buildLegendItem(Colors.orange, 'High Risk'),
          _buildLegendItem(Colors.red, 'Critical Risk'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withAlpha(40),
              border: Border.all(color: color.withAlpha(100), width: 1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color.withAlpha(60),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

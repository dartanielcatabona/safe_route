import 'package:flutter/material.dart';
import '../models/transit_route.dart';
import '../models/risk_assessment.dart';

class RouteDetailsPanel extends StatelessWidget {
  final MultiModalRoute route;
  final RouteRiskAssessment? riskAssessment;
  final VoidCallback? onStartNavigation;

  const RouteDetailsPanel({
    super.key,
    required this.route,
    this.riskAssessment,
    this.onStartNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.15,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          Icons.schedule,
                          '${route.totalMinutes} min',
                          'Duration',
                        ),
                        _buildSummaryItem(
                          Icons.payments,
                          '₱${route.totalFare.toStringAsFixed(0)}',
                          'Est. Fare',
                        ),
                        _buildSummaryItem(
                          Icons.security,
                          '${route.overallSafetyScore.toStringAsFixed(1)}/10',
                          'Safety Score',
                          color: _getSafetyColor(route.overallSafetyScore),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    // Risk Assessment
                    if (riskAssessment != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getRiskColor(riskAssessment!.riskFactors.riskLevel)
                              .withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getRiskColor(riskAssessment!.riskFactors.riskLevel)
                                .withAlpha(76),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getRiskIcon(riskAssessment!.riskFactors.riskLevel),
                                  color: _getRiskColor(riskAssessment!.riskFactors.riskLevel),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Risk Level: ${_getRiskLabel(riskAssessment!.riskFactors.riskLevel)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getRiskColor(riskAssessment!.riskFactors.riskLevel),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              riskAssessment!.recommendation,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Transit Modes
                    const Text(
                      'Transit Options',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ...route.segments.map((segment) => _buildSegmentCard(segment)),
                    
                    // Risk Zones
                    if (riskAssessment?.riskZones.isNotEmpty ?? false) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Caution Zones',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ...riskAssessment!.riskZones.map((zone) => _buildRiskZoneCard(zone)),
                    ],
                    
                    const SizedBox(height: 80), // Space for button
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.blue, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildSegmentCard(RouteSegment segment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: segment.mode.color.withAlpha(51),
          child: Icon(segment.mode.icon, color: segment.mode.color, size: 20),
        ),
        title: Text(segment.mode.label),
        subtitle: Text('${segment.estimatedMinutes} min • ₱${segment.fare.toStringAsFixed(0)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.security, size: 16, color: _getSafetyColor(segment.safetyScore)),
            const SizedBox(width: 4),
            Text(
              segment.safetyScore.toStringAsFixed(1),
              style: TextStyle(
                color: _getSafetyColor(segment.safetyScore),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskZoneCard(RiskZone zone) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: _getRiskColor(zone.level).withAlpha(25),
      child: ListTile(
        leading: Icon(
          Icons.warning_amber,
          color: _getRiskColor(zone.level),
        ),
        title: Text(zone.description),
        subtitle: Text(zone.contributingFactors.join(', ')),
        trailing: Chip(
          label: Text(
            _getRiskLabel(zone.level),
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
          backgroundColor: _getRiskColor(zone.level),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Color _getSafetyColor(double score) {
    if (score >= 7) return Colors.green;
    if (score >= 5) return Colors.orange;
    return Colors.red;
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return Colors.green;
      case RiskLevel.moderate:
        return Colors.yellow.shade700;
      case RiskLevel.high:
        return Colors.orange;
      case RiskLevel.critical:
        return Colors.red;
    }
  }

  IconData _getRiskIcon(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return Icons.check_circle;
      case RiskLevel.moderate:
        return Icons.info;
      case RiskLevel.high:
        return Icons.warning;
      case RiskLevel.critical:
        return Icons.dangerous;
    }
  }

  String _getRiskLabel(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.moderate:
        return 'Moderate';
      case RiskLevel.high:
        return 'High';
      case RiskLevel.critical:
        return 'Critical';
    }
  }
}

class FloatingStartButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FloatingStartButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.navigation),
        label: const Text(
          'START NAVIGATION',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

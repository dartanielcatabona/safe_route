import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum IncidentType {
  darkStreet('Dark Street', Icons.dark_mode, Colors.black87),
  unsupervisedTerminal('Unsupervised Terminal', Icons.warning_amber, Colors.orange),
  ongoingIncident('Ongoing Incident', Icons.emergency, Colors.red),
  harassment('Harassment', Icons.person_off, Colors.purple),
  theft('Theft/Robbery', Icons.money_off, Colors.deepOrange),
  accident('Accident', Icons.local_hospital, Colors.blue);

  final String label;
  final IconData icon;
  final Color color;

  const IncidentType(this.label, this.icon, this.color);
}

enum IncidentSeverity { low, medium, high, critical }

class IncidentReport {
  final String id;
  final String userId;
  final IncidentType type;
  final IncidentSeverity severity;
  final LatLng location;
  final String description;
  final DateTime reportedAt;
  final String? vehicleInfo;
  final List<String>? photos;
  final int upvotes;
  final int downvotes;
  final bool isVerified;
  final String? address;

  IncidentReport({
    required this.id,
    required this.userId,
    required this.type,
    required this.severity,
    required this.location,
    required this.description,
    required this.reportedAt,
    this.vehicleInfo,
    this.photos,
    this.upvotes = 0,
    this.downvotes = 0,
    this.isVerified = false,
    this.address,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'severity': severity.name,
      'location': GeoPoint(location.latitude, location.longitude),
      'description': description,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'vehicleInfo': vehicleInfo,
      'photos': photos,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'isVerified': isVerified,
      'address': address,
    };
  }

  factory IncidentReport.fromMap(String id, Map<String, dynamic> map) {
    final geoPoint = map['location'] as GeoPoint;
    return IncidentReport(
      id: id,
      userId: map['userId'] ?? '',
      type: IncidentType.values.byName(map['type'] ?? 'ongoingIncident'),
      severity: IncidentSeverity.values.byName(map['severity'] ?? 'medium'),
      location: LatLng(geoPoint.latitude, geoPoint.longitude),
      description: map['description'] ?? '',
      reportedAt: (map['reportedAt'] as Timestamp).toDate(),
      vehicleInfo: map['vehicleInfo'],
      photos: map['photos'] != null ? List<String>.from(map['photos']) : null,
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      address: map['address'],
    );
  }
}

class SafetyHeatmapPoint {
  final LatLng location;
  final double riskScore;
  final int incidentCount;
  final List<IncidentType> commonIncidents;
  final DateTime lastUpdated;

  SafetyHeatmapPoint({
    required this.location,
    required this.riskScore,
    required this.incidentCount,
    required this.commonIncidents,
    required this.lastUpdated,
  });
}

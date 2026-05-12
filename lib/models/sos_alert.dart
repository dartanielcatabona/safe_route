import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum SOSStatus { active, resolved, cancelled }

class SOSAlert {
  final String id;
  final String userId;
  final LatLng location;
  final String? vehiclePlateNumber;
  final String? vehicleType;
  final String? routeInfo;
  final DateTime triggeredAt;
  final SOSStatus status;
  final List<EmergencyContact> notifiedContacts;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? notes;

  SOSAlert({
    required this.id,
    required this.userId,
    required this.location,
    this.vehiclePlateNumber,
    this.vehicleType,
    this.routeInfo,
    required this.triggeredAt,
    this.status = SOSStatus.active,
    required this.notifiedContacts,
    this.resolvedBy,
    this.resolvedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'location': GeoPoint(location.latitude, location.longitude),
      'vehiclePlateNumber': vehiclePlateNumber,
      'vehicleType': vehicleType,
      'routeInfo': routeInfo,
      'triggeredAt': Timestamp.fromDate(triggeredAt),
      'status': status.name,
      'notifiedContacts': notifiedContacts.map((c) => c.toMap()).toList(),
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'notes': notes,
    };
  }

  factory SOSAlert.fromMap(String id, Map<String, dynamic> map) {
    final geoPoint = map['location'] as GeoPoint;
    return SOSAlert(
      id: id,
      userId: map['userId'] ?? '',
      location: LatLng(geoPoint.latitude, geoPoint.longitude),
      vehiclePlateNumber: map['vehiclePlateNumber'],
      vehicleType: map['vehicleType'],
      routeInfo: map['routeInfo'],
      triggeredAt: (map['triggeredAt'] as Timestamp).toDate(),
      status: SOSStatus.values.byName(map['status'] ?? 'active'),
      notifiedContacts: (map['notifiedContacts'] as List?)
              ?.map((c) => EmergencyContact.fromMap(c))
              .toList() ??
          [],
      resolvedBy: map['resolvedBy'],
      resolvedAt: map['resolvedAt'] != null
          ? (map['resolvedAt'] as Timestamp).toDate()
          : null,
      notes: map['notes'],
    );
  }
}

class EmergencyContact {
  final String name;
  final String phoneNumber;
  final String? email;
  final bool isAuthority;
  final String? relationship;
  DateTime? notifiedAt;
  bool notificationSent;

  EmergencyContact({
    required this.name,
    required this.phoneNumber,
    this.email,
    this.isAuthority = false,
    this.relationship,
    this.notifiedAt,
    this.notificationSent = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'isAuthority': isAuthority,
      'relationship': relationship,
      'notifiedAt': notifiedAt != null ? Timestamp.fromDate(notifiedAt!) : null,
      'notificationSent': notificationSent,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'],
      isAuthority: map['isAuthority'] ?? false,
      relationship: map['relationship'],
      notifiedAt: map['notifiedAt'] != null
          ? (map['notifiedAt'] as Timestamp).toDate()
          : null,
      notificationSent: map['notificationSent'] ?? false,
    );
  }
}

class VehicleInfo {
  final String? plateNumber;
  final String? type;
  final String? route;
  final String? operator;
  final String? color;

  VehicleInfo({
    this.plateNumber,
    this.type,
    this.route,
    this.operator,
    this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'plateNumber': plateNumber,
      'type': type,
      'route': route,
      'operator': operator,
      'color': color,
    };
  }
}

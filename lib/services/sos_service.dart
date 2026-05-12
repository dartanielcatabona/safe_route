import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sos_alert.dart';
import 'firebase_service.dart';

class SOSService {
  static final _firestore = FirebaseService.firestore;
  static const String _collection = 'sos_alerts';
  
  static Timer? _locationUpdateTimer;
  static String? _activeAlertId;

  static Future<String> triggerSOS({
    String? vehiclePlateNumber,
    String? vehicleType,
    String? routeInfo,
    required List<EmergencyContact> emergencyContacts,
  }) async {
    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final location = LatLng(position.latitude, position.longitude);

      // Get current user
      final userId = await FirebaseService.getCurrentUserId() ?? 
          await FirebaseService.signInAnonymously();

      // Create SOS alert
      final alert = SOSAlert(
        id: '',
        userId: userId,
        location: location,
        vehiclePlateNumber: vehiclePlateNumber,
        vehicleType: vehicleType,
        routeInfo: routeInfo,
        triggeredAt: DateTime.now(),
        notifiedContacts: emergencyContacts,
      );

      // Save to Firestore
      final docRef = await _firestore.collection(_collection).add(alert.toMap());
      _activeAlertId = docRef.id;

      // Notify emergency contacts
      await _notifyEmergencyContacts(
        docRef.id,
        location,
        vehiclePlateNumber,
        vehicleType,
        routeInfo,
        emergencyContacts,
      );

      // Start location updates
      _startLocationUpdates(docRef.id);

      return docRef.id;
    } catch (e) {
      debugPrint('Error triggering SOS: $e');
      throw Exception('Failed to trigger SOS alert');
    }
  }

  static Future<void> _notifyEmergencyContacts(
    String alertId,
    LatLng location,
    String? vehiclePlate,
    String? vehicleType,
    String? routeInfo,
    List<EmergencyContact> contacts,
  ) async {
    final locationUrl = 
        'https://www.google.com/maps?q=${location.latitude},${location.longitude}';
    
    final message = _buildSOSMessage(
      locationUrl,
      vehiclePlate,
      vehicleType,
      routeInfo,
    );

    for (var contact in contacts) {
      try {
        if (contact.isAuthority) {
          // Contact authorities via phone call
          await _callEmergencyNumber(contact.phoneNumber);
        } else {
          // Send SMS to personal contacts
          await _sendSMS(contact.phoneNumber, message);
        }

        // Update contact notification status
        contact.notifiedAt = DateTime.now();
        contact.notificationSent = true;
      } catch (e) {
        debugPrint('Failed to notify ${contact.name}: $e');
      }
    }

    // Update Firestore with notification status
    await _firestore.collection(_collection).doc(alertId).update({
      'notifiedContacts': contacts.map((c) => c.toMap()).toList(),
    });
  }

  static String _buildSOSMessage(
    String locationUrl,
    String? vehiclePlate,
    String? vehicleType,
    String? routeInfo,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('🚨 EMERGENCY SOS ALERT 🚨');
    buffer.writeln('');
    buffer.writeln('Location: $locationUrl');
    
    if (vehiclePlate != null && vehiclePlate.isNotEmpty) {
      buffer.writeln('Vehicle Plate: $vehiclePlate');
    }
    if (vehicleType != null && vehicleType.isNotEmpty) {
      buffer.writeln('Vehicle Type: $vehicleType');
    }
    if (routeInfo != null && routeInfo.isNotEmpty) {
      buffer.writeln('Route: $routeInfo');
    }
    
    buffer.writeln('');
    buffer.writeln('This is an automated emergency alert from SafeRoute app.');
    buffer.writeln('Please contact the user immediately or alert authorities.');

    return buffer.toString();
  }

  static Future<void> _sendSMS(String phoneNumber, String message) async {
    // Open SMS app with pre-filled message
    final uri = Uri.parse('sms:$phoneNumber?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch SMS app');
    }
  }

  static Future<void> _callEmergencyNumber(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static void _startLocationUpdates(String alertId) {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        await _firestore.collection(_collection).doc(alertId).update({
          'location': GeoPoint(position.latitude, position.longitude),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Location update failed: $e');
      }
    });
  }

  static Future<void> cancelSOS(String alertId, {String? reason}) async {
    _locationUpdateTimer?.cancel();
    _activeAlertId = null;

    await _firestore.collection(_collection).doc(alertId).update({
      'status': SOSStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelReason': reason,
    });
  }

  static Future<void> resolveSOS(String alertId, String resolvedBy) async {
    _locationUpdateTimer?.cancel();
    _activeAlertId = null;

    await _firestore.collection(_collection).doc(alertId).update({
      'status': SOSStatus.resolved.name,
      'resolvedBy': resolvedBy,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<SOSAlert?> getActiveAlert(String alertId) {
    return _firestore
        .collection(_collection)
        .doc(alertId)
        .snapshots()
        .map((doc) => doc.exists ? SOSAlert.fromMap(doc.id, doc.data()!) : null);
  }

  /// Delete all SOS alerts created by a user
  static Future<void> deleteAllUserSosAlerts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting all SOS alerts: $e');
      throw Exception('Failed to delete SOS alerts');
    }
  }

  static Future<void> shareLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final locationUrl = 
          'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
      
      await Share.share(
        'My current location: $locationUrl',
        subject: 'SafeRoute - My Location',
      );
    } catch (e) {
      debugPrint('Error sharing location: $e');
      throw Exception('Failed to share location');
    }
  }

  static String? get activeAlertId => _activeAlertId;
}

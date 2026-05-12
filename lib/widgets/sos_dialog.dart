import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/sos_alert.dart';
import '../services/sos_service.dart';

class SOSDialog extends StatefulWidget {
  const SOSDialog({super.key});

  @override
  State<SOSDialog> createState() => _SOSDialogState();
}

class _SOSDialogState extends State<SOSDialog> {
  final _plateController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _routeController = TextEditingController();
  final _emergencyContacts = <EmergencyContact>[];
  bool _isTriggering = false;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadDefaultContacts();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _loadDefaultContacts() {
    // Default emergency contacts
    _emergencyContacts.addAll([
      EmergencyContact(
        name: 'PNP Hotline',
        phoneNumber: '911',
        isAuthority: true,
      ),
      EmergencyContact(
        name: 'MMDA Hotline',
        phoneNumber: '136',
        isAuthority: true,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.emergency, color: Colors.red),
          SizedBox(width: 8),
          Text('EMERGENCY SOS', style: TextStyle(color: Colors.red)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(76)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ This will:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('• Send your GPS location to emergency contacts'),
                  Text('• Share vehicle details (if provided)'),
                  Text('• Call emergency authorities'),
                  Text('• Update your location every minute'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Vehicle Information (Optional):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _plateController,
              decoration: const InputDecoration(
                labelText: 'Plate Number',
                hintText: 'e.g., ABC-123',
                prefixIcon: Icon(Icons.confirmation_number),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _vehicleTypeController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Type',
                hintText: 'e.g., Jeepney, Bus, UV Express',
                prefixIcon: Icon(Icons.directions_bus),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _routeController,
              decoration: const InputDecoration(
                labelText: 'Route Info',
                hintText: 'e.g., Ayala to Alabang',
                prefixIcon: Icon(Icons.route),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Emergency Contacts:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._emergencyContacts.map((contact) => ListTile(
              leading: Icon(
                contact.isAuthority ? Icons.local_police : Icons.person,
                color: contact.isAuthority ? Colors.blue : Colors.grey,
              ),
              title: Text(contact.name),
              subtitle: Text(contact.phoneNumber),
              dense: true,
            )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTriggering ? null : () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton.icon(
          onPressed: _isTriggering ? null : _triggerSOS,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          icon: _isTriggering
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.emergency),
          label: Text(_isTriggering ? 'SENDING...' : 'SEND SOS'),
        ),
      ],
    );
  }

  Future<void> _triggerSOS() async {
    if (_currentLocation == null) {
      await _getCurrentLocation();
      if (_currentLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get location. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isTriggering = true);

    try {
      final alertId = await SOSService.triggerSOS(
        vehiclePlateNumber: _plateController.text.trim().isEmpty
            ? null
            : _plateController.text.trim(),
        vehicleType: _vehicleTypeController.text.trim().isEmpty
            ? null
            : _vehicleTypeController.text.trim(),
        routeInfo: _routeController.text.trim().isEmpty
            ? null
            : _routeController.text.trim(),
        emergencyContacts: _emergencyContacts,
      );

      if (mounted) {
        Navigator.pop(context);
        _showSOSActiveDialog(alertId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SOS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTriggering = false);
    }
  }

  void _showSOSActiveDialog(String alertId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emergency, color: Colors.red),
            SizedBox(width: 8),
            Text('SOS Active'),
          ],
        ),
        content: const Text(
          'Emergency alert has been sent!\n\n'
          'Your location is being shared with emergency contacts. '
          'Stay calm and wait for assistance.',
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await SOSService.shareLocation();
            },
            icon: const Icon(Icons.share),
            label: const Text('Share Location'),
          ),
          FilledButton(
            onPressed: () async {
              await SOSService.cancelSOS(alertId, reason: 'User cancelled');
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('I\'M SAFE - Cancel SOS'),
          ),
        ],
      ),
    );
  }
}

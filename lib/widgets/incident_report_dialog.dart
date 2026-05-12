import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/incident_report.dart';
import '../services/firebase_service.dart';
import '../services/incident_service.dart';

class IncidentReportDialog extends StatefulWidget {
  final LatLng location;
  final String? address;

  const IncidentReportDialog({
    super.key,
    required this.location,
    this.address,
  });

  @override
  State<IncidentReportDialog> createState() => _IncidentReportDialogState();
}

class _IncidentReportDialogState extends State<IncidentReportDialog> {
  IncidentType _selectedType = IncidentType.darkStreet;
  IncidentSeverity _selectedSeverity = IncidentSeverity.medium;
  final _descriptionController = TextEditingController();
  final _vehicleInfoController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.report_problem, color: Colors.orange),
          SizedBox(width: 8),
          Text('Report Incident'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location: ${widget.address ?? "${widget.location.latitude.toStringAsFixed(4)}, ${widget.location.longitude.toStringAsFixed(4)}"}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text('Incident Type:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...IncidentType.values.map((type) => RadioListTile(
              title: Row(
                children: [
                  Icon(type.icon, color: type.color, size: 20),
                  const SizedBox(width: 8),
                  Text(type.label),
                ],
              ),
              value: type,
              groupValue: _selectedType,
              onChanged: (value) => setState(() => _selectedType = value!),
              dense: true,
            )),
            const SizedBox(height: 16),
            const Text('Severity:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: IncidentSeverity.values.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(_getSeverityLabel(s)),
                    selected: _selectedSeverity == s,
                    onSelected: (_) => setState(() => _selectedSeverity = s),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe what you observed...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleInfoController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Info (Optional)',
                hintText: 'e.g., Bus plate number UV-123',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitReport,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }

  String _getSeverityLabel(IncidentSeverity severity) {
    switch (severity) {
      case IncidentSeverity.low:
        return 'Low';
      case IncidentSeverity.medium:
        return 'Med';
      case IncidentSeverity.high:
        return 'High';
      case IncidentSeverity.critical:
        return 'Crit';
    }
  }

  Future<void> _submitReport() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a description')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = await FirebaseService.getCurrentUserId() ??
          await FirebaseService.signInAnonymously();

      final report = IncidentReport(
        id: '',
        userId: userId,
        type: _selectedType,
        severity: _selectedSeverity,
        location: widget.location,
        description: _descriptionController.text.trim(),
        reportedAt: DateTime.now(),
        vehicleInfo: _vehicleInfoController.text.trim().isEmpty
            ? null
            : _vehicleInfoController.text.trim(),
        address: widget.address,
      );

      await IncidentService.reportIncident(report);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident reported successfully. Thank you!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

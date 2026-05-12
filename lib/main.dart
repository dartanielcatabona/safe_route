import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Models
import 'models/transit_route.dart';
import 'models/incident_report.dart';
import 'models/risk_assessment.dart';

// Services
import 'services/firebase_service.dart';
import 'services/risk_service.dart';
import 'services/transit_service.dart';
import 'services/incident_service.dart';
import 'services/saved_route_service.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';

// Widgets
import 'widgets/safety_heatmap.dart';
import 'widgets/incident_report_dialog.dart';
import 'widgets/sos_dialog.dart';
import 'widgets/route_details_panel.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/saved_routes_screen.dart';
import 'screens/route_history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/my_apps_screen.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await FirebaseService.initialize();
    runApp(const SafeRouteApp());
  } catch (e, stackTrace) {
    debugPrint('Firebase init error: $e');
    debugPrint('Stack: $stackTrace');
    // Run app without Firebase as fallback
    runApp(const SafeRouteApp());
  }
}

class SafeRouteApp extends StatelessWidget {
  const SafeRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SafeRoute',
            theme: themeProvider.currentTheme,
            home: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                if (authProvider.isLoading) {
                  return const SplashScreen();
                } else if (authProvider.isAuthenticated) {
                  return const MapScreen();
                } else {
                  return const LoginScreen();
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            SvgPicture.asset(
              'assets/images/app_logo.svg',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              'SafeRoute',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  final TransitService _transitService = TransitService();
  final RiskAssessmentService _riskService = RiskAssessmentService();
  final SafetyHeatmapOverlay _heatmapOverlay = SafetyHeatmapOverlay();

  LatLng? startLatLng;
  LatLng? destinationLatLng;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  Set<Circle> circles = {};

  TextEditingController startController = TextEditingController();
  TextEditingController destinationController = TextEditingController();

  List<dynamic> startSuggestions = [];
  List<dynamic> destinationSuggestions = [];

  List<MultiModalRoute> _availableRoutes = [];
  MultiModalRoute? _selectedRoute;
  RouteRiskAssessment? _currentRiskAssessment;

  bool _showHeatmap = false;
  bool _isLoading = false;
  int _selectedRouteIndex = -1;

  StreamSubscription<List<IncidentReport>>? _incidentSubscription;

  // API Keys - Replace with your actual keys
  String placesApiKey =
      "AIzaSyBUI42KrDGpOY3Pg7v8nH0_cYBLcwXR150"; // For search autocomplete & place details

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _subscribeToNearbyIncidents();
  }

  @override
  void dispose() {
    _incidentSubscription?.cancel();
    mapController?.dispose();
    startController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  void _subscribeToNearbyIncidents() {
    // Subscribe to incidents in Metro Manila area
    const center = LatLng(14.5995, 120.9842); // Manila center
    _incidentSubscription = IncidentService.getNearbyIncidents(
      center,
      50, // 50km radius
      since: DateTime.now().subtract(const Duration(days: 7)),
    ).listen((incidents) {
      debugPrint('Received ${incidents.length} incidents for heatmap');
      // Always update the overlay data
      _heatmapOverlay.updateFromIncidents(incidents);
      // Only show on map if heatmap is enabled
      if (_showHeatmap) {
        setState(() {
          circles = _heatmapOverlay.circles;
          // Merge heatmap markers with existing markers (start/destination)
          final existingMarkers = markers
              .where((m) =>
                  m.markerId.value == 'start' || m.markerId.value == 'dest')
              .toSet();
          markers = {...existingMarkers, ..._heatmapOverlay.markers};
        });
      }
    });
  }

  // ================= GOOGLE AUTOCOMPLETE =================
  Future<List<dynamic>> fetchSuggestions(String input) async {
    if (input.isEmpty) return [];

    final url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$placesApiKey&components=country:ph";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['predictions'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
    return [];
  }

  Future<LatLng?> getPlaceLatLng(String placeId) async {
    final url =
        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$placesApiKey";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final loc = data['result']['geometry']['location'];
          return LatLng(loc['lat'], loc['lng']);
        }
      }
    } catch (e) {
      debugPrint('Error getting place details: \$e');
    }
    return null;
  }

  // ================= ROUTE =================
  void setStart(LatLng pos, {String? address}) {
    debugPrint('setStart called: $pos');
    setState(() {
      startLatLng = pos;
      updateMarker("start", pos, address: address);
    });
    _findMultiModalRoutes();
  }

  void setDestination(LatLng pos, {String? address}) {
    debugPrint('setDestination called: $pos');
    setState(() {
      destinationLatLng = pos;
      updateMarker("dest", pos, address: address);
    });
    // Immediately draw a direct line (for testing)
    _drawDirectLine();
    _findMultiModalRoutes();
  }

  // Draw a simple direct line between start and destination
  void _drawDirectLine() {
    if (startLatLng == null || destinationLatLng == null) return;

    debugPrint('Drawing DIRECT LINE from $startLatLng to $destinationLatLng');

    setState(() {
      polylines = {
        Polyline(
          polylineId: const PolylineId('direct_test'),
          points: [startLatLng!, destinationLatLng!],
          width: 10,
          color: Colors.blue,
          geodesic: true,
        ),
      };
    });

    debugPrint('Direct line added: ${polylines.length} polylines');
  }

  void updateMarker(String id, LatLng pos, {String? address}) {
    markers.removeWhere((m) => m.markerId.value == id);
    markers.add(Marker(
      markerId: MarkerId(id),
      position: pos,
      infoWindow: address != null
          ? InfoWindow(
              title: id == "start" ? "Start" : "Destination", snippet: address)
          : InfoWindow.noText,
    ));
  }

  Future<void> _findMultiModalRoutes() async {
    debugPrint('=== FINDING ROUTES ===');
    debugPrint('start: $startLatLng, dest: $destinationLatLng');

    if (startLatLng == null || destinationLatLng == null) {
      debugPrint('Missing start or destination, returning');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final routes = await _transitService.findMultiModalRoutes(
        startLatLng!,
        destinationLatLng!,
      );

      setState(() {
        _availableRoutes = routes;
        _selectedRoute = routes.isNotEmpty ? routes.first : null;
        _selectedRouteIndex = routes.isNotEmpty ? 0 : -1;
      });

      if (_selectedRoute != null) {
        await _assessRouteRisk();
        _drawRouteOnMap();
      }
    } catch (e, stackTrace) {
      debugPrint('Error finding routes: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assessRouteRisk() async {
    if (_selectedRoute == null) return;

    // Combine all segment paths
    final fullPath = <LatLng>[];
    for (var segment in _selectedRoute!.segments) {
      fullPath.addAll(segment.path);
    }

    final assessment = await _riskService.assessRouteRisk(
      _selectedRoute!.id,
      fullPath,
    );

    setState(() {
      _currentRiskAssessment = assessment;
    });
  }

  void _drawRouteOnMap() {
    if (_selectedRoute == null) {
      debugPrint('No selected route to draw');
      return;
    }

    debugPrint('=== DRAWING ROUTE ===');
    debugPrint('Route ID: ${_selectedRoute!.id}');
    debugPrint('Segments count: ${_selectedRoute!.segments.length}');

    // Print all segment data
    for (int i = 0; i < _selectedRoute!.segments.length; i++) {
      final seg = _selectedRoute!.segments[i];
      debugPrint(
          'Segment $i: mode=${seg.mode.name}, path=${seg.path.length} points');
      if (seg.path.isNotEmpty) {
        debugPrint(
            '  Start: ${seg.path.first.latitude}, ${seg.path.first.longitude}');
        debugPrint(
            '  End: ${seg.path.last.latitude}, ${seg.path.last.longitude}');
      }
    }

    final newPolylines = <Polyline>{};

    for (var i = 0; i < _selectedRoute!.segments.length; i++) {
      final segment = _selectedRoute!.segments[i];
      debugPrint(
          'Segment $i: mode=${segment.mode.name}, path points=${segment.path.length}');

      if (segment.path.isEmpty) {
        debugPrint('WARNING: Segment $i has empty path!');
        continue;
      }

      // Use BRIGHT RED for maximum visibility during testing
      newPolylines.add(Polyline(
        polylineId: PolylineId('segment_$i'),
        points: segment.path,
        width: 8,
        color: Colors.red,
        zIndex: 1,
      ));
    }

    debugPrint('Created ${newPolylines.length} polylines');

    // Fallback: if no segments have paths, draw a direct line from start to destination
    if (newPolylines.isEmpty &&
        startLatLng != null &&
        destinationLatLng != null) {
      debugPrint('No segments with paths - drawing direct line');
      newPolylines.add(Polyline(
        polylineId: const PolylineId('direct_line'),
        points: [startLatLng!, destinationLatLng!],
        width: 6,
        color: Colors.blue,
      ));
    }

    // Fit map to show the route
    if (mapController != null &&
        startLatLng != null &&
        destinationLatLng != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              math.min(startLatLng!.latitude, destinationLatLng!.latitude),
              math.min(startLatLng!.longitude, destinationLatLng!.longitude),
            ),
            northeast: LatLng(
              math.max(startLatLng!.latitude, destinationLatLng!.latitude),
              math.max(startLatLng!.longitude, destinationLatLng!.longitude),
            ),
          ),
          100,
        ),
      );
    }

    setState(() {
      polylines = newPolylines;
    });
  }

  void _selectRoute(int index) {
    if (index >= 0 && index < _availableRoutes.length) {
      setState(() {
        _selectedRoute = _availableRoutes[index];
        _selectedRouteIndex = index;
      });
      _assessRouteRisk();
      _drawRouteOnMap();
    }
  }

  // ================= SOS =================
  void showSOSDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SOSDialog(),
    );
  }

  // ================= SAVE ROUTE =================
  void _saveCurrentRoute() async {
    if (_selectedRoute == null ||
        startLatLng == null ||
        destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a route first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to save routes'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await SavedRouteService.saveRoute(
        userId: userId,
        name: 'Route ${DateTime.now().millisecondsSinceEpoch}',
        startLocation: startLatLng!,
        startAddress: startController.text.isNotEmpty
            ? startController.text
            : 'Selected Location',
        endLocation: destinationLatLng!,
        endAddress: destinationController.text.isNotEmpty
            ? destinationController.text
            : 'Selected Destination',
        preferredMode: _selectedRoute!.segments.isNotEmpty
            ? _selectedRoute!.segments.first.mode
            : TransitMode.jeepney,
        estimatedMinutes: _selectedRoute!.totalMinutes,
        estimatedFare: _selectedRoute!.totalFare,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save route: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ================= PROFILE =================
  void _showProfileMenu() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: authProvider.currentUser?.photoUrl != null
                      ? NetworkImage(authProvider.currentUser!.photoUrl!)
                      : null,
                  child: authProvider.currentUser?.photoUrl == null
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authProvider.currentUser?.displayName ?? 'User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        authProvider.currentUser?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.apps),
              title: const Text('My Apps'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MyAppsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Route History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RouteHistoryScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('Saved Routes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SavedRoutesScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await authProvider.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= INCIDENT REPORTING =================
  void _showIncidentReportDialog() {
    if (startLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => IncidentReportDialog(
        location: startLatLng!,
        address: startController.text.isNotEmpty ? startController.text : null,
      ),
    );
  }

  // ================= HEATMAP =================
  void _toggleHeatmap() {
    setState(() {
      _showHeatmap = !_showHeatmap;
      if (_showHeatmap) {
        circles = _heatmapOverlay.circles;
        // Add heatmap markers while keeping start/dest markers
        final existingMarkers = markers
            .where((m) =>
                m.markerId.value == 'start' || m.markerId.value == 'dest')
            .toSet();
        markers = {...existingMarkers, ..._heatmapOverlay.markers};
        debugPrint(
            'Heatmap ON: ${circles.length} circles, ${_heatmapOverlay.markers.length} markers');
      } else {
        circles.clear();
        // Remove only heatmap markers
        markers.removeWhere((m) => m.markerId.value.startsWith('incident_'));
        debugPrint('Heatmap OFF');
      }
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(14.5995, 120.9842), // Manila
              zoom: 12,
            ),
            markers: markers,
            polylines: polylines,
            circles: circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (c) => mapController = c,
            onTap: (latLng) {
              // Allow user to tap map to set location
              if (startLatLng == null) {
                setStart(latLng);
                startController.text =
                    "${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
              } else if (destinationLatLng == null) {
                setDestination(latLng);
                destinationController.text =
                    "${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
              }
            },
          ),

          // Search boxes
          Positioned(
            top: 40,
            left: 15,
            right: 15,
            child: Column(
              children: [
                _buildSearchBox(
                  hint: "Start Location",
                  controller: startController,
                  suggestions: startSuggestions,
                  icon: Icons.my_location,
                  onChanged: (v) async {
                    startSuggestions = await fetchSuggestions(v);
                    setState(() {});
                  },
                  onTap: (item) async {
                    startController.text = item['description'];
                    startSuggestions = [];
                    LatLng? pos = await getPlaceLatLng(item['place_id']);
                    if (pos != null) {
                      setStart(pos, address: item['description']);
                    }
                    setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                _buildSearchBox(
                  hint: "Destination",
                  controller: destinationController,
                  suggestions: destinationSuggestions,
                  icon: Icons.location_on,
                  onChanged: (v) async {
                    destinationSuggestions = await fetchSuggestions(v);
                    setState(() {});
                  },
                  onTap: (item) async {
                    destinationController.text = item['description'];
                    destinationSuggestions = [];
                    LatLng? pos = await getPlaceLatLng(item['place_id']);
                    if (pos != null) {
                      setDestination(pos, address: item['description']);
                    }
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          // Heatmap toggle
          Positioned(
            top: 180,
            right: 15,
            child: FloatingActionButton.small(
              heroTag: "heatmap",
              onPressed: _toggleHeatmap,
              backgroundColor: _showHeatmap ? Colors.orange : Colors.white,
              child: Icon(
                Icons.layers,
                color: _showHeatmap ? Colors.white : Colors.black,
              ),
            ),
          ),

          // Profile button
          Positioned(
            top: 230,
            right: 15,
            child: FloatingActionButton.small(
              heroTag: "profile",
              onPressed: _showProfileMenu,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.person),
            ),
          ),

          // Save route button
          Positioned(
            top: 280,
            right: 15,
            child: FloatingActionButton.small(
              heroTag: "save",
              onPressed: _saveCurrentRoute,
              backgroundColor: Colors.green,
              child: const Icon(Icons.bookmark),
            ),
          ),

          // Report incident button
          Positioned(
            top: 330,
            right: 15,
            child: FloatingActionButton.small(
              heroTag: "report",
              onPressed: _showIncidentReportDialog,
              backgroundColor: Colors.orange,
              child: const Icon(Icons.report_problem),
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Positioned(
              top: 280,
              right: 15,
              child: CircularProgressIndicator(),
            ),

          // Route selection panel
          if (_availableRoutes.isNotEmpty && _selectedRoute != null)
            RouteDetailsPanel(
              route: _selectedRoute!,
              riskAssessment: _currentRiskAssessment,
              onStartNavigation: () {
                // Start navigation with selected route
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Navigation started - Stay safe!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),

          // Multiple route options
          if (_availableRoutes.length > 1 && _selectedRoute == null)
            Positioned(
              bottom: 100,
              left: 15,
              right: 15,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableRoutes.length,
                  itemBuilder: (context, index) {
                    final route = _availableRoutes[index];
                    final isSelected = index == _selectedRouteIndex;
                    return GestureDetector(
                      onTap: () => _selectRoute(index),
                      child: Container(
                        width: 150,
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.withAlpha(25)
                              : Colors.grey.withAlpha(25),
                          border: Border.all(
                            color:
                                isSelected ? Colors.blue : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Route ${index + 1}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('${route.totalMinutes} min'),
                            Text('₱${route.totalFare.toStringAsFixed(0)}'),
                            Row(
                              children: [
                                const Icon(Icons.security,
                                    size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  route.overallSafetyScore.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Heatmap legend
          if (_showHeatmap)
            const Positioned(
              bottom: 100,
              left: 15,
              child: HeatmapLegend(),
            ),
        ],
      ),

      // SOS Button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "sos",
        backgroundColor: Colors.red,
        onPressed: showSOSDialog,
        icon: const Icon(Icons.emergency),
        label: const Text(
          "SOS",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSearchBox({
    required String hint,
    required TextEditingController controller,
    required List<dynamic> suggestions,
    required IconData icon,
    required Function(String) onChanged,
    required Function(dynamic) onTap,
  }) {
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        setState(() {
                          if (hint.contains("Start")) {
                            startLatLng = null;
                            markers.removeWhere(
                                (m) => m.markerId.value == "start");
                          } else {
                            destinationLatLng = null;
                            markers
                                .removeWhere((m) => m.markerId.value == "dest");
                          }
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.all(15),
              border: InputBorder.none,
            ),
            onChanged: onChanged,
          ),
          if (suggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              color: Colors.white,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (_, i) {
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(suggestions[i]['description']),
                    dense: true,
                    onTap: () => onTap(suggestions[i]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

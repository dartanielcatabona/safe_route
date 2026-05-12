import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transit_route.dart';
import '../services/saved_route_service.dart';
import '../providers/auth_provider.dart';

class SavedRoutesScreen extends StatefulWidget {
  const SavedRoutesScreen({super.key});

  @override
  State<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends State<SavedRoutesScreen> {
  List<SavedRoute> _savedRoutes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedRoutes();
  }

  Future<void> _loadSavedRoutes() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    debugPrint('Loading saved routes for user: $userId');
    debugPrint('User authenticated: ${authProvider.isAuthenticated}');
    debugPrint('Current user: ${authProvider.currentUser}');

    if (userId == null) {
      debugPrint('No user ID found, cannot load saved routes');
      setState(() {
        _savedRoutes = [];
        _isLoading = false;
      });
      return;
    }

    try {
      // Try simple query first without ordering
      final snapshot = await FirebaseFirestore.instance
          .collection('saved_routes')
          .where('userId', isEqualTo: userId)
          .get();
      
      debugPrint('Raw snapshot found ${snapshot.docs.length} documents');
      
      final routes = snapshot.docs
          .map((doc) => SavedRoute.fromMap(doc.id, doc.data()))
          .toList();
          
      debugPrint('Found ${routes.length} saved routes');
      setState(() {
        _savedRoutes = routes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading saved routes: $e');
      setState(() {
        _savedRoutes = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load saved routes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createSampleRoute() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) return;

    try {
      final sampleRoute = SavedRoute(
        id: 'sample_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        name: 'Home to Work',
        description: 'Daily commute route',
        startLocation: const LatLng(14.5995, 120.9842), // Manila
        startAddress: 'Home, Manila',
        endLocation: const LatLng(14.6091, 121.0223), // Makati
        endAddress: 'Office, Makati',
        preferredMode: TransitMode.jeepney,
        estimatedMinutes: 45,
        estimatedFare: 25.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isFavorite: true,
        useCount: 5,
        icon: 'work',
        color: '#4285F4',
      );

      final createdRoute = await SavedRouteService.saveRoute(
        userId: userId,
        name: sampleRoute.name,
        description: sampleRoute.description,
        startLocation: sampleRoute.startLocation,
        startAddress: sampleRoute.startAddress,
        endLocation: sampleRoute.endLocation,
        endAddress: sampleRoute.endAddress,
        preferredMode: sampleRoute.preferredMode,
        estimatedMinutes: sampleRoute.estimatedMinutes,
        estimatedFare: sampleRoute.estimatedFare,
        icon: sampleRoute.icon,
        color: sampleRoute.color,
      );
      debugPrint('Sample route created successfully with ID: ${createdRoute.id}');
      debugPrint('Route details: ${createdRoute.toMap()}');
      _loadSavedRoutes(); // Reload the routes
    } catch (e) {
      debugPrint('Error creating sample route: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create sample route: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRoute(String routeId) async {
    try {
      await SavedRouteService.deleteSavedRoute(routeId);
      _loadSavedRoutes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete route: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRouteDetails(SavedRoute route) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      route.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      route.description ?? 'No description',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Route Map Preview
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: route.startLocation,
                          zoom: 12,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('start'),
                            position: route.startLocation,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen,
                            ),
                          ),
                          Marker(
                            markerId: const MarkerId('end'),
                            position: route.endLocation,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed,
                            ),
                          ),
                        },
                        polylines: {
                          if (route.routeWaypoints != null)
                            Polyline(
                              polylineId: const PolylineId('route'),
                              points: route.routeWaypoints!
                                  .map((wp) => LatLng(wp['lat'], wp['lng']))
                                  .toList(),
                              color: Colors.blue,
                              width: 4,
                            ),
                        },
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Route Information
                    _buildInfoRow(Icons.access_time, 'Estimated Time',
                        '${route.estimatedMinutes ?? 'N/A'} min'),
                    _buildInfoRow(Icons.attach_money, 'Estimated Cost',
                        '₱${route.estimatedFare?.toStringAsFixed(0) ?? 'N/A'}'),
                    _buildInfoRow(Icons.location_on, 'Start',
                        route.startAddress),
                    _buildInfoRow(
                        Icons.flag, 'Destination', route.endAddress),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              // TODO: Navigate to map with this route
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Navigating to route...')),
                              );
                            },
                            icon: const Icon(Icons.navigation),
                            label: const Text('Navigate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteRoute(route.id);
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Routes'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedRoutes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savedRoutes.length,
                  itemBuilder: (context, index) {
                    final route = _savedRoutes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Icon(
                            _getRouteIcon(
                                route.preferredMode ?? TransitMode.p2pBus),
                            color: Colors.blue[700],
                          ),
                        ),
                        title: Text(
                          route.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              route.description ?? 'No description',
                              style: TextStyle(color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildChip(Icons.access_time,
                                    '${route.estimatedMinutes ?? 'N/A'} min'),
                                const SizedBox(width: 8),
                                _buildChip(Icons.attach_money,
                                    '₱${route.estimatedFare?.toStringAsFixed(0) ?? 'N/A'}'),
                                const SizedBox(width: 8),
                                _buildChip(Icons.security, 'Safe Route'),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'view':
                                _showRouteDetails(route);
                                break;
                              case 'delete':
                                _deleteRoute(route.id);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility),
                                  SizedBox(width: 8),
                                  Text('View Details'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _showRouteDetails(route),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSampleRoute,
        backgroundColor: Colors.blue[700],
        tooltip: 'Add Sample Route',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Saved Routes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save your favorite routes for quick access',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to map with save mode
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Go to map and save a route!')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Save Your First Route'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRouteIcon(TransitMode mode) {
    switch (mode) {
      case TransitMode.p2pBus:
      case TransitMode.carouselBus:
      case TransitMode.cityBus:
        return Icons.directions_bus;
      case TransitMode.mrt:
        return Icons.subway;
      case TransitMode.lrt:
        return Icons.tram;
      case TransitMode.jeepney:
        return Icons.local_taxi;
      case TransitMode.modernJeepney:
        return Icons.electric_rickshaw;
      case TransitMode.uvExpress:
        return Icons.airport_shuttle;
    }
  }
}

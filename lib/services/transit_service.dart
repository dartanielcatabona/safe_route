import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/transit_route.dart';
import '../data/routes.dart' as static_data;
import 'ml_risk_prediction_service.dart';

class TransitService {
  // API Key for Google Directions API
  final String _directionsApiKey = "AIzaSyADMgyjRKJ3yvKjL8xlpMvG6ZLu9Lo8-cY";
  
  // ML Risk Prediction Service
  final MLRiskPredictionService _mlRiskService = MLRiskPredictionService();

  Future<List<MultiModalRoute>> findMultiModalRoutes(
    LatLng start,
    LatLng destination, {
    List<TransitMode>? preferredModes,
    DateTime? departureTime,
  }) async {
    try {
      // First, try to match with static transit routes
      final staticRoute = _findMatchingStaticRoute(start, destination);
      if (staticRoute != null) {
        debugPrint('Found matching static route: ${staticRoute.name}');
        final route = _buildRouteFromStaticData(staticRoute, start, destination);
        if (route != null) {
          return [route];
        }
      }
      
      // Fall back to Google Directions (driving mode for road-following paths)
      debugPrint('No static route match, using driving directions...');
      final routes = await _fetchGoogleDirections(
        start,
        destination,
        transitMode: 'driving',
        departureTime: departureTime ?? DateTime.now(),
      );

      debugPrint('Fetched ${routes.length} raw routes from API');

      // Process and enhance with ML risk prediction
      final processedRoutes = await _processRoutes(routes, preferredModes, start, destination, departureTime ?? DateTime.now());
      
      // Apply ML risk prediction to each route
      for (var i = 0; i < processedRoutes.length; i++) {
        final route = processedRoutes[i];
        
        // Build full path from segments
        final fullPath = <LatLng>[];
        for (final segment in route.segments) {
          fullPath.addAll(segment.path);
        }
        
        // Get ML risk prediction
        final mlPrediction = await _mlRiskService.predictRouteRisk(
          routeId: route.id,
          path: fullPath,
          segments: route.segments,
          departureTime: departureTime ?? DateTime.now(),
        );
        
        // Update route with ML safety score (0-10 scale converted)
        final mlSafetyScore = (1 - mlPrediction.overallRiskScore) * 10;
        
        // Create enhanced segments with ML safety scores
        final enhancedSegments = route.segments.map((seg) => 
          RouteSegment(
            mode: seg.mode,
            start: seg.start,
            end: seg.end,
            path: seg.path,
            estimatedMinutes: seg.estimatedMinutes,
            fare: seg.fare,
            safetyScore: mlSafetyScore,
          )
        ).toList();
        
        processedRoutes[i] = MultiModalRoute(
          id: route.id,
          segments: enhancedSegments,
          totalFare: route.totalFare,
          totalMinutes: route.totalMinutes,
          overallSafetyScore: mlSafetyScore,
          timestamp: route.timestamp,
        );
        
        debugPrint('Route ${route.id}: ML safety score = ${mlSafetyScore.toStringAsFixed(2)}/10, risk=${mlPrediction.riskLevel.name}');
      }
      
      // Re-sort by ML safety score
      processedRoutes.sort((a, b) => b.overallSafetyScore.compareTo(a.overallSafetyScore));
      
      debugPrint('Returning ${processedRoutes.length} ML-enhanced routes');
      return processedRoutes;
    } catch (e, stackTrace) {
      debugPrint('Error in findMultiModalRoutes: $e');
      debugPrint('Stack: $stackTrace');
      return [];
    }
  }

  // Find if start/dest match any static route stops (within 500m tolerance)
  static_data.RouteModel? _findMatchingStaticRoute(LatLng start, LatLng dest) {
    const toleranceKm = 0.5; // 500 meters
    
    for (final route in static_data.routes) {
      // Check if start is near any stop on this route
      static_data.Stop? startStop;
      static_data.Stop? destStop;
      
      for (final stop in route.stops) {
        final stopLatLng = LatLng(stop.lat, stop.lng);
        if (_distanceKm(start, stopLatLng) <= toleranceKm) {
          startStop = stop;
        }
        if (_distanceKm(dest, stopLatLng) <= toleranceKm) {
          destStop = stop;
        }
      }
      
      // Both start and dest must be on same route, and start comes before dest
      if (startStop != null && destStop != null) {
        final startIdx = route.stops.indexOf(startStop);
        final destIdx = route.stops.indexOf(destStop);
        if (startIdx < destIdx) {
          debugPrint('Match: ${startStop.name} -> ${destStop.name} on ${route.name}');
          return route;
        }
      }
    }
    return null;
  }

  // Build a route using the static stop coordinates (actual path, not straight line)
  MultiModalRoute? _buildRouteFromStaticData(static_data.RouteModel routeModel, LatLng start, LatLng dest) {
    // Find start and dest stops in the route
    static_data.Stop? startStop;
    static_data.Stop? destStop;
    int startIdx = -1;
    int destIdx = -1;
    
    for (int i = 0; i < routeModel.stops.length; i++) {
      final stop = routeModel.stops[i];
      final stopLatLng = LatLng(stop.lat, stop.lng);
      if (_distanceKm(start, stopLatLng) <= 0.5 && startIdx == -1) {
        startStop = stop;
        startIdx = i;
      }
      if (_distanceKm(dest, stopLatLng) <= 0.5 && destIdx == -1) {
        destStop = stop;
        destIdx = i;
      }
    }
    
    if (startStop == null || destStop == null || startIdx >= destIdx) {
      return null;
    }
    
    // Build path through all intermediate stops (actual route path)
    final path = <LatLng>[];
    for (int i = startIdx; i <= destIdx; i++) {
      path.add(LatLng(routeModel.stops[i].lat, routeModel.stops[i].lng));
    }
    
    // Calculate approximate time (2 min per stop + walking)
    final stopCount = destIdx - startIdx;
    final estimatedMinutes = 5 + (stopCount * 3); // 5 min base + 3 min per stop
    
    // Estimate fare based on type
    double fare = 15.0; // Base fare
    if (routeModel.type == 'train') {
      fare = 20.0 + (stopCount * 5); // MRT/LRT pricing
    } else if (routeModel.type == 'jeep') {
      fare = 12.0 + (stopCount * 2); // Jeepney pricing
    }
    
    // Determine transit mode
    TransitMode mode;
    if (routeModel.type == 'train') {
      mode = TransitMode.mrt;
    } else if (routeModel.type == 'jeep') {
      mode = TransitMode.jeepney;
    } else {
      mode = TransitMode.p2pBus;
    }
    
    final segment = RouteSegment(
      mode: mode,
      start: path.first,
      end: path.last,
      path: path,
      estimatedMinutes: estimatedMinutes,
      fare: fare,
      safetyScore: _estimateTransitSafety(mode),
    );
    
    return MultiModalRoute(
      id: 'static_${routeModel.id}',
      segments: [segment],
      totalFare: fare,
      totalMinutes: estimatedMinutes,
      overallSafetyScore: segment.safetyScore,
      timestamp: DateTime.now(),
    );
  }

  // Calculate distance between two points in km
  double _distanceKm(LatLng p1, LatLng p2) {
    const R = 6371; // Earth radius in km
    final lat1Rad = p1.latitude * (3.14159 / 180);
    final lat2Rad = p2.latitude * (3.14159 / 180);
    final deltaLat = (p2.latitude - p1.latitude) * (3.14159 / 180);
    final deltaLng = (p2.longitude - p1.longitude) * (3.14159 / 180);
    
    final a = (deltaLat / 2) * (deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * (deltaLng / 2) * (deltaLng / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return R * c;
  }

  double _estimateTransitSafety(TransitMode mode) {
    switch (mode) {
      case TransitMode.mrt:
      case TransitMode.lrt:
        return 8.5; // Trains are safer
      case TransitMode.p2pBus:
        return 7.0;
      case TransitMode.jeepney:
        return 6.0;
      default:
        return 6.0;
    }
  }

  Future<List<dynamic>> _fetchGoogleDirections(
    LatLng origin,
    LatLng destination, {
    String transitMode = 'transit',
    required DateTime departureTime,
  }) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}&'
        'destination=${destination.latitude},${destination.longitude}&'
        'mode=$transitMode&'
        'alternatives=true&'
        'key=$_directionsApiKey',
      );

      final response = await http.get(url);
      
      debugPrint('Directions API status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Directions API response status: ${data['status']}');
        
        if (data['status'] == 'OK') {
          final routes = data['routes'] as List;
          debugPrint('Found ${routes.length} routes');
          
          // Print first route details
          if (routes.isNotEmpty) {
            final firstRoute = routes[0];
            final legs = firstRoute['legs'] as List;
            debugPrint('First route has ${legs.length} legs');
            if (legs.isNotEmpty) {
              final steps = legs[0]['steps'] as List;
              debugPrint('First leg has ${steps.length} steps');
              for (var i = 0; i < steps.length && i < 3; i++) {
                debugPrint('Step $i: ${steps[i]['travel_mode']}, hasPolyline=${steps[i]['polyline'] != null}');
              }
            }
          }
          
          return routes;
        } else {
          debugPrint('Directions API error: ${data['status']}');
          debugPrint('Error message: ${data['error_message'] ?? 'No details'}');
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching directions: $e');
      return [];
    }
  }

  Future<List<MultiModalRoute>> _processRoutes(
    List<dynamic> googleRoutes,
    List<TransitMode>? preferredModes,
    LatLng start,
    LatLng destination,
    DateTime departureTime,
  ) async {
    debugPrint('Processing ${googleRoutes.length} google routes');
    final List<MultiModalRoute> routes = [];

    for (var i = 0; i < googleRoutes.length; i++) {
      final route = googleRoutes[i];
      final legs = route['legs'] as List;
      debugPrint('Route $i: ${legs.length} legs');
      if (legs.isEmpty) {
        debugPrint('Route $i: no legs, skipping');
        continue;
      }

      final leg = legs[0];
      final steps = leg['steps'] as List;
      
      final segments = <RouteSegment>[];
      double totalFare = 0;
      int totalMinutes = 0;
      double totalSafetyScore = 0;

      debugPrint('Processing ${steps.length} steps for route $i');

      for (var j = 0; j < steps.length; j++) {
        final step = steps[j];
        final travelMode = step['travel_mode'];
        
        debugPrint('Step $j: travel_mode=$travelMode');
        
        // Check if polyline exists
        if (step['polyline'] == null || step['polyline']['points'] == null) {
          debugPrint('Step $j: NO polyline data!');
          continue;
        }
        
        final polyline = step['polyline']['points'] as String;
        final path = _decodePolyline(polyline);
        
        debugPrint('Step $j: decoded ${path.length} points from polyline');
        
        TransitMode? transitMode;
        double fare = 0;
        int minutes = (step['duration']['value'] as int) ~/ 60;
        double safetyScore = 5.0;

        if (travelMode == 'TRANSIT') {
          final transitDetails = step['transit_details'];
          final vehicleType = transitDetails['vehicle']['type'];
          transitMode = _mapGoogleVehicleType(vehicleType);
          fare = _estimateFare(transitMode, minutes);
        } else if (travelMode == 'WALKING') {
          transitMode = null;
          safetyScore = _estimateWalkingSafety(path);
        }

        if (path.isNotEmpty) {
          segments.add(RouteSegment(
            mode: transitMode ?? TransitMode.p2pBus,
            start: path.first,
            end: path.last,
            path: path,
            estimatedMinutes: minutes,
            fare: fare,
            safetyScore: safetyScore,
          ));
          debugPrint('Step $j: added segment with mode ${transitMode?.name ?? "WALK"}');

          totalFare += fare;
          totalMinutes += minutes;
          totalSafetyScore += safetyScore;
        }
      }

      if (segments.isNotEmpty) {
        final avgSafety = totalSafetyScore / segments.length;
        routes.add(MultiModalRoute(
          id: 'route_$i',
          segments: segments,
          totalFare: totalFare,
          totalMinutes: totalMinutes,
          overallSafetyScore: avgSafety,
          timestamp: DateTime.now(),
        ));
        debugPrint('Created route $i with ${segments.length} segments');
      } else {
        debugPrint('Route $i has no segments - skipping');
      }
    }

    debugPrint('Total routes processed: ${routes.length}');

    // Sort by safety score (higher is safer)
    routes.sort((a, b) => b.overallSafetyScore.compareTo(a.overallSafetyScore));
    return routes;
  }

  TransitMode _mapGoogleVehicleType(String type) {
    switch (type.toUpperCase()) {
      case 'BUS':
        return TransitMode.cityBus;
      case 'HEAVY_RAIL':
      case 'SUBWAY':
        return TransitMode.mrt;
      case 'LIGHT_RAIL':
      case 'TRAM':
        return TransitMode.lrt;
    }
    return TransitMode.cityBus;
  }

  double _estimateFare(TransitMode mode, int minutes) {
    // Simplified fare estimation for Metro Manila
    switch (mode) {
      case TransitMode.jeepney:
      case TransitMode.modernJeepney:
        return 12.0; // Base fare
      case TransitMode.cityBus:
      case TransitMode.p2pBus:
        return 15.0 + (minutes * 0.5);
      case TransitMode.carouselBus:
        return 20.0 + (minutes * 0.75);
      case TransitMode.mrt:
      case TransitMode.lrt:
        return 13.0 + (minutes * 0.25);
      case TransitMode.uvExpress:
        return 30.0 + (minutes * 0.8);
    }
  }

  double _estimateWalkingSafety(List<LatLng> path) {
    // In a real implementation, this would query the safety database
    // for each segment of the walking path
    return 4.0; // Default moderate safety
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  Future<List<TransitStop>> getNearbyStops(LatLng location, double radiusKm) async {
    // In production, query Firestore for nearby stops
    // For now, return mock data
    return [
      TransitStop(
        id: '1',
        name: 'Ayala Station',
        location: const LatLng(14.5547, 121.0244),
        availableModes: [TransitMode.mrt, TransitMode.p2pBus],
        safetyScore: 4.5,
      ),
      TransitStop(
        id: '2',
        name: 'Makati Ave Jeepney Terminal',
        location: const LatLng(14.5565, 121.0322),
        availableModes: [TransitMode.jeepney, TransitMode.modernJeepney],
        safetyScore: 3.8,
      ),
    ];
  }
}

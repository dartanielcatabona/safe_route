import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum TransitMode {
  p2pBus('P2P Bus', Icons.directions_bus, Colors.blue),
  carouselBus('Carousel Bus', Icons.directions_bus_filled, Colors.purple),
  cityBus('City Bus', Icons.directions_bus, Colors.orange),
  mrt('MRT', Icons.subway, Colors.yellow),
  lrt('LRT', Icons.tram, Colors.green),
  jeepney('Jeepney', Icons.local_taxi, Colors.red),
  modernJeepney('Modern Jeepney', Icons.electric_rickshaw, Colors.teal),
  uvExpress('UV Express', Icons.airport_shuttle, Colors.indigo);

  final String label;
  final IconData icon;
  final Color color;

  const TransitMode(this.label, this.icon, this.color);
}

class TransitRoute {
  final String id;
  final String name;
  final TransitMode mode;
  final List<LatLng> path;
  final List<TransitStop> stops;
  final double fare;
  final int estimatedMinutes;
  final String routeNumber;

  TransitRoute({
    required this.id,
    required this.name,
    required this.mode,
    required this.path,
    required this.stops,
    required this.fare,
    required this.estimatedMinutes,
    this.routeNumber = '',
  });
}

class TransitStop {
  final String id;
  final String name;
  final LatLng location;
  final List<TransitMode> availableModes;
  final double safetyScore;

  TransitStop({
    required this.id,
    required this.name,
    required this.location,
    required this.availableModes,
    this.safetyScore = 5.0,
  });
}

class RouteSegment {
  final TransitMode mode;
  final TransitRoute? route;
  final LatLng start;
  final LatLng end;
  final int estimatedMinutes;
  final double fare;
  final double safetyScore;
  final List<LatLng> path;

  RouteSegment({
    required this.mode,
    this.route,
    required this.start,
    required this.end,
    required this.estimatedMinutes,
    required this.fare,
    required this.safetyScore,
    required this.path,
  });
}

class MultiModalRoute {
  final String id;
  final List<RouteSegment> segments;
  final double totalFare;
  final int totalMinutes;
  final double overallSafetyScore;
  final DateTime timestamp;

  MultiModalRoute({
    required this.id,
    required this.segments,
    required this.totalFare,
    required this.totalMinutes,
    required this.overallSafetyScore,
    required this.timestamp,
  });
}

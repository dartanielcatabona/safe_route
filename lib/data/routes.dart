class Stop {
  String id;
  String name;
  double lat;
  double lng;

  Stop(this.id, this.name, this.lat, this.lng);
}

class RouteModel {
  String id;
  String name;
  String type; // jeep, train, bus
  List<Stop> stops;

  RouteModel(this.id, this.name, this.type, this.stops);
}

// ================= METRO MANILA SAMPLE DATA =================
List<RouteModel> routes = [
  // 🟢 JEEP: SM NORTH → CUBAO
  RouteModel("jeep_1", "SM North - Cubao Jeep", "jeep", [
    Stop("s1", "SM North", 14.656, 121.029),
    Stop("s2", "Trinoma", 14.653, 121.032),
    Stop("s3", "Cubao", 14.619, 121.054),
  ]),

  // 🚆 MRT LINE 3
  RouteModel("mrt_3", "MRT Line 3", "train", [
    Stop("m1", "North Ave", 14.653, 121.033),
    Stop("m2", "Quezon Ave", 14.642, 121.038),
    Stop("m3", "Cubao", 14.619, 121.054),
    Stop("m4", "Ortigas", 14.586, 121.056),
    Stop("m5", "Ayala", 14.549, 121.028),
    Stop("m6", "Taft", 14.537, 121.001),
  ]),

  // 🟢 JEEP: CUBAO → TAFT
  RouteModel("jeep_2", "Cubao - Taft Jeep", "jeep", [
    Stop("j1", "Cubao", 14.619, 121.054),
    Stop("j2", "Ortigas", 14.586, 121.056),
    Stop("j3", "Taft", 14.537, 121.001),
  ]),
];
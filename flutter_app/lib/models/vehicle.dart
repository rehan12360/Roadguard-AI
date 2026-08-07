class VehiclePreset {
  final String id;
  final String name;
  final String role; // "detector" | "alerted" | "out_of_scope"
  final double latitude;
  final double longitude;
  final String statusDescription;
  final int simulatedDistanceMeters;
  final String subtitle;

  const VehiclePreset({
    required this.id,
    required this.name,
    required this.role,
    required this.latitude,
    required this.longitude,
    required this.statusDescription,
    required this.simulatedDistanceMeters,
    required this.subtitle,
  });

  static const List<VehiclePreset> defaultPresets = [
    VehiclePreset(
      id: "car_a_detector",
      name: "Car A — AI Detection Car",
      role: "detector",
      latitude: 30.7046,
      longitude: 76.7179,
      statusDescription: "Scanning & AI Vision Active",
      simulatedDistanceMeters: 0,
      subtitle: "Detector Vehicle (Uploads Road Video)",
    ),
    VehiclePreset(
      id: "car_b_near",
      name: "Car B — Driver (250m Ahead)",
      role: "alerted",
      latitude: 30.7065,
      longitude: 76.7185,
      statusDescription: "Inside 500m Geofence",
      simulatedDistanceMeters: 250,
      subtitle: "Nearby Vehicle — Speaks Voice Alert",
    ),
    VehiclePreset(
      id: "car_c_near",
      name: "Car C — Driver (420m Ahead)",
      role: "alerted",
      latitude: 30.7080,
      longitude: 76.7195,
      statusDescription: "Inside 500m Geofence",
      simulatedDistanceMeters: 420,
      subtitle: "Nearby Vehicle — Visual Warning Card",
    ),
    VehiclePreset(
      id: "car_d_far",
      name: "Car D — Driver (850m Out)",
      role: "out_of_scope",
      latitude: 30.7120,
      longitude: 76.7250,
      statusDescription: "Clear (> 500m Radius)",
      simulatedDistanceMeters: 850,
      subtitle: "Out-of-range Vehicle — No Alert (Safe)",
    ),
  ];
}

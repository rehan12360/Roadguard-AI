/// Mirrors the hazard document shape written by the FastAPI backend
/// into Firestore's `prototype_hazards` collection.
class Hazard {
  final String hazardId;
  final String vehicleId;
  final String hazardType;
  final double confidence;
  final double latitude;
  final double longitude;
  final String lane;
  final String severity;
  final String status;
  final int verifications;
  final String source; // "ai_detection" | "manual"
  final DateTime timestamp;

  Hazard({
    required this.hazardId,
    required this.vehicleId,
    required this.hazardType,
    required this.confidence,
    required this.latitude,
    required this.longitude,
    required this.lane,
    required this.severity,
    required this.status,
    required this.verifications,
    required this.source,
    required this.timestamp,
  });

  factory Hazard.fromFirestore(Map<String, dynamic> data, String docId) {
    return Hazard(
      hazardId: data['hazard_id'] ?? docId,
      vehicleId: data['vehicle_id'] ?? 'unknown',
      hazardType: data['hazard_type'] ?? 'hazard',
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      lane: data['lane'] ?? 'unknown',
      severity: data['severity'] ?? 'medium',
      status: data['status'] ?? 'active',
      verifications: data['verifications'] ?? 1,
      source: data['source'] ?? 'ai_detection',
      timestamp: DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isAiDetected => source == 'ai_detection';
  bool get isCritical => severity == 'high';
}

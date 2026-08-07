import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hazard.dart';

class FirestoreService {
  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static const String collection = 'prototype_hazards';

  /// Live stream of all currently active hazards.
  Stream<List<Hazard>> activeHazardsStream() {
    final db = _db;
    if (db == null) {
      return const Stream<List<Hazard>>.empty();
    }
    try {
      return db
          .collection(collection)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Hazard.fromFirestore(doc.data(), doc.id))
              .toList());
    } catch (_) {
      return const Stream<List<Hazard>>.empty();
    }
  }

  Future<void> markVerified(String hazardId) async {
    final db = _db;
    if (db == null) return;
    try {
      final ref = db.collection(collection).doc(hazardId);
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final current = snap.data()!;
        final newVerifications = (current['verifications'] ?? 1) + 1;
        final newConfidence =
            ((current['confidence'] ?? 0.6) + 0.05).clamp(0.0, 0.99);
        tx.update(ref, {
          'verifications': newVerifications,
          'confidence': newConfidence,
        });
      });
    } catch (_) {}
  }

  Future<String?> reportHazardDirectly({
    required String vehicleId,
    required String hazardType,
    required double confidence,
    required double latitude,
    required double longitude,
    String lane = 'center',
    String source = 'edge_ai_detection',
  }) async {
    final db = _db;
    if (db == null) return null;
    try {
      // 1. Check for duplicates (active hazards within ~30m radius)
      // We can do a simple client-side filter of active hazards to keep it fast
      final snapshot = await db.collection(collection).where('status', isEqualTo: 'active').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['hazard_type'] == hazardType) {
          final lat = data['latitude'] as double;
          final lon = data['longitude'] as double;
          
          // Fast approximate distance check (~30m is about 0.0003 degrees)
          if ((lat - latitude).abs() < 0.0003 && (lon - longitude).abs() < 0.0003) {
            final existingId = doc.id;
            await markVerified(existingId);
            return existingId; // Deduplicated! Confidence bumped.
          }
        }
      }

      // 2. Create new hazard if no duplicate found
      final hazardId = 'haz_${DateTime.now().millisecondsSinceEpoch}';
      await db.collection(collection).doc(hazardId).set({
        'hazard_id': hazardId,
        'vehicle_id': vehicleId,
        'hazard_type': hazardType,
        'confidence': confidence,
        'latitude': latitude,
        'longitude': longitude,
        'lane': lane,
        'severity': confidence > 0.80 ? 'high' : 'medium',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'status': 'active',
        'verifications': 1,
        'source': source,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return hazardId;
    } catch (_) {
      return null;
    }
  }
}

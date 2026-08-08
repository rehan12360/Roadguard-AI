import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hazard.dart';

class DatabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String collection = 'prototype_hazards';

  /// Live stream of all currently active hazards.
  Stream<List<Hazard>> activeHazardsStream() {
    try {
      return _client
          .from(collection)
          .stream(primaryKey: ['hazard_id'])
          .eq('status', 'active')
          .map((List<Map<String, dynamic>> maps) {
            return maps.map((map) => Hazard.fromMap(map, map['hazard_id'] as String)).toList();
          });
    } catch (_) {
      return const Stream<List<Hazard>>.empty();
    }
  }

  Future<void> markVerified(String hazardId) async {
    try {
      // First, get the current hazard
      final response = await _client
          .from(collection)
          .select('verifications, confidence')
          .eq('hazard_id', hazardId)
          .maybeSingle();

      if (response == null) return;

      final currentVerifications = response['verifications'] as int? ?? 1;
      final currentConfidence = (response['confidence'] as num?)?.toDouble() ?? 0.6;

      final newVerifications = currentVerifications + 1;
      final newConfidence = (currentConfidence + 0.05).clamp(0.0, 0.99);

      // Update it
      await _client.from(collection).update({
        'verifications': newVerifications,
        'confidence': newConfidence,
      }).eq('hazard_id', hazardId);
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
    try {
      // 1. Check for duplicates
      final activeHazards = await _client
          .from(collection)
          .select()
          .eq('status', 'active');

      for (var doc in activeHazards) {
        if (doc['hazard_type'] == hazardType) {
          final lat = (doc['latitude'] as num).toDouble();
          final lon = (doc['longitude'] as num).toDouble();
          
          if ((lat - latitude).abs() < 0.0003 && (lon - longitude).abs() < 0.0003) {
            final existingId = doc['hazard_id'] as String;
            await markVerified(existingId);
            return existingId; // Deduplicated! Confidence bumped.
          }
        }
      }

      // 2. Create new hazard
      final hazardId = 'haz_${DateTime.now().millisecondsSinceEpoch}';
      await _client.from(collection).insert({
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
    } catch (e) {
      print('Error reporting hazard: $e');
      return null;
    }
  }

  Future<String?> uploadHazardMedia(String hazardId, File mediaFile, {bool isVideo = false}) async {
    try {
      final ext = isVideo ? 'mp4' : 'jpg';
      final fileName = '$hazardId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage
          .from('hazards')
          .upload(fileName, mediaFile);
      
      final publicUrl = _client.storage
          .from('hazards')
          .getPublicUrl(fileName);
          
      return publicUrl;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateHazardAttachment(String hazardId, String imageUrl) async {
    try {
      await _client.from(collection).update({
        'attachment_url': imageUrl,
      }).eq('hazard_id', hazardId);
    } catch (_) {}
  }

  Future<void> deleteHazard(String hazardId) async {
    try {
      await _client.from(collection).delete().eq('hazard_id', hazardId);
    } catch (_) {}
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Handles writes that go through the FastAPI backend rather than
/// straight to Firestore — currently just manual hazard reporting.
/// Reads are handled separately by DatabaseService's live listener.
class ApiService {
  static const String baseUrl = 'http://10.215.82.27:8000';

  Future<String?> reportHazardManually({
    required String vehicleId,
    required String hazardType,
    required double latitude,
    required double longitude,
    String lane = 'unknown',
    String severity = 'medium',
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/hazards/report');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vehicle_id': vehicleId,
          'hazard_type': hazardType,
          'latitude': latitude,
          'longitude': longitude,
          'lane': lane,
          'severity': severity,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return data['hazard_id'] as String;
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Manual report failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> uploadVideoForInference({
    required String filePath,
    required String vehicleId,
    double latitude = 30.7046,
    double longitude = 76.7179,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/process-video');
    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['vehicle_id'] = vehicleId;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Video upload failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> processImageForInference({
    required String filePath,
    required String vehicleId,
    double latitude = 30.7046,
    double longitude = 76.7179,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/process-image');
    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['vehicle_id'] = vehicleId;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Image upload failed: $e');
      return null;
    }
  }

  Future<bool> verifyHazard(String hazardId) async {
    final url = Uri.parse('$baseUrl/api/v1/verify/$hazardId');
    try {
      final response = await http.post(url);
      return response.statusCode == 200;
    } catch (e) {
      print('Verify failed: $e');
      return false;
    }
  }

  Future<bool> resetDemo() async {
    final url = Uri.parse('$baseUrl/api/v1/demo/reset');
    try {
      final response = await http.post(url);
      return response.statusCode == 200;
    } catch (e) {
      print('Reset demo failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> getAllHazards() async {
    final url = Uri.parse('$baseUrl/api/v1/hazards');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hazardsList = data['hazards'] as List<dynamic>;
        return hazardsList.map((e) => e as Map<String, dynamic>).toList();
      }
      return null;
    } catch (e) {
      print('Failed to fetch hazards: $e');
      return null;
    }
  }
}


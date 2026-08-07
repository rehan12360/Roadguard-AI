import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/hazard.dart';
import '../models/vehicle.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../services/voice_service.dart';
import '../widgets/video_box_painter.dart';

class DemoProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FirestoreService _firestoreService = FirestoreService();
  final VoiceService _voiceService = VoiceService();

  VehiclePreset _selectedVehicle = VehiclePreset.defaultPresets[0]; // Default: Car A
  VehiclePreset get selectedVehicle => _selectedVehicle;

  void setSelectedVehicle(VehiclePreset preset) {
    _selectedVehicle = preset;
    _evaluateGeofenceAlerts();
    notifyListeners();
  }

  List<VehiclePreset> get allVehicles => VehiclePreset.defaultPresets;

  List<Hazard> _hazards = [];
  List<Hazard> get hazards => _hazards;

  StreamSubscription<List<Hazard>>? _hazardSubscription;
  Timer? _apiPollingTimer;

  // Video processing state
  bool _isProcessingVideo = false;
  bool get isProcessingVideo => _isProcessingVideo;

  String? _uploadedVideoName;
  String? get uploadedVideoName => _uploadedVideoName;

  List<DetectionBox> _currentDetections = [];
  List<DetectionBox> get currentDetections => _currentDetections;

  List<Hazard> _latestUploadedHazards = [];
  List<Hazard> get latestUploadedHazards => _latestUploadedHazards;

  List<Hazard> _nearbyActiveAlerts = [];
  List<Hazard> get nearbyActiveAlerts => _nearbyActiveAlerts;
  
  final Set<String> _announcedAlertIds = {};
  
  int _totalAlertsSent = 0;
  int get totalAlertsSent => _totalAlertsSent;

  int get networkAlertsBroadcasted {
    int total = 0;
    for (var h in _hazards) {
      if (h.status == 'active') {
         total += h.verifications; 
      }
    }
    return total;
  }

  DemoProvider() {
    _initServices();
  }

  void _initServices() {
    _voiceService.init();
    _listenToFirestoreHazards();
  }

  void _listenToFirestoreHazards() {
    _hazardSubscription?.cancel();
    _hazardSubscription = _firestoreService.activeHazardsStream().listen((list) {
      if (list.isNotEmpty) {
        _hazards = list;
        _evaluateGeofenceAlerts();
        notifyListeners();
      }
    });

    _apiPollingTimer?.cancel();
    _apiPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollApiHazards());
  }

  Future<void> _pollApiHazards() async {
    final list = await _apiService.getAllHazards();
    if (list != null) {
      final newHazards = list.map((data) => Hazard.fromFirestore(data, data['id'] ?? data['hazard_id'] ?? '')).toList();
      _hazards = newHazards;
      _evaluateGeofenceAlerts();
      notifyListeners();
    }
  }

  void selectVehicle(VehiclePreset preset) {
    _selectedVehicle = preset;
    _evaluateGeofenceAlerts();
    notifyListeners();
  }

  double calculateDistanceM(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLambda = (lon2 - lon1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  Hazard? getAlertForVehicle(VehiclePreset vehicle, {outDistanceM}) {
    if (_hazards.isEmpty || vehicle.role == "detector") {
      return null;
    }
    Hazard? closest;
    double minDistance = double.infinity;
    for (final h in _hazards) {
      final dist = calculateDistanceM(vehicle.latitude, vehicle.longitude, h.latitude, h.longitude);
      if (dist <= 500.0 && dist < minDistance) {
        minDistance = dist;
        closest = h;
      }
    }
    if (outDistanceM != null && closest != null) {
      outDistanceM[0] = minDistance.round();
    }
    return closest;
  }

  void _evaluateGeofenceAlerts() {
    if (_hazards.isEmpty || _selectedVehicle.role == "detector") {
      _nearbyActiveAlerts = [];
      return;
    }
    
    List<Hazard> nearby = [];
    for (final h in _hazards) {
      if (h.status != 'active') continue;
      final dist = calculateDistanceM(_selectedVehicle.latitude, _selectedVehicle.longitude, h.latitude, h.longitude);
      if (dist <= 500.0) {
        nearby.add(h);
        if (!_announcedAlertIds.contains(h.hazardId)) {
          _announcedAlertIds.add(h.hazardId);
          _totalAlertsSent++;
          _voiceService.speakAlert(h.hazardType, dist.round());
        }
      }
    }
    _nearbyActiveAlerts = nearby;
  }

  Future<bool> processVideoUpload(String filePath, String fileName, {VehiclePreset? preset}) async {
    final vehicle = preset ?? _selectedVehicle;
    _isProcessingVideo = true;
    _uploadedVideoName = fileName;
    _currentDetections = [];
    notifyListeners();

    Hazard? existingHazard;
    if (vehicle.role != 'detector') {
      existingHazard = getAlertForVehicle(vehicle);
    }

    try {
      final result = await _apiService.uploadVideoForInference(
        filePath: filePath,
        vehicleId: vehicle.id,
        latitude: vehicle.latitude,
        longitude: vehicle.longitude,
      );

      if (result != null) {
        if (result['status'] == 'success') {
          final rawBoxes = result['detections'] as List<dynamic>? ?? [];
          _currentDetections = rawBoxes.map((b) {
            return DetectionBox(
              x1: (b['x1'] as num).toDouble(),
              y1: (b['y1'] as num).toDouble(),
              x2: (b['x2'] as num).toDouble(),
              y2: (b['y2'] as num).toDouble(),
              label: b['label'] as String? ?? 'pothole',
              confidence: (b['confidence'] as num).toDouble(),
              lane: b['lane'] as String? ?? 'center',
            );
          }).toList();

          final allHazards = result['all_hazards'] as List<dynamic>? ?? [];
          if (allHazards.isNotEmpty) {
            _latestUploadedHazards.clear();
            for (var hData in allHazards) {
              final newHazard = Hazard(
                hazardId: hData['hazard_id'] ?? hData['id'], // Support both keys
                vehicleId: vehicle.id,
                hazardType: hData['type'] ?? 'pothole',
                confidence: (hData['conf'] as num?)?.toDouble() ?? 0.70, // Fixed to read 'conf' from backend
                latitude: vehicle.latitude,
                longitude: vehicle.longitude,
                lane: 'center',
                severity: 'high',
                status: 'active',
                verifications: 1,
                source: 'ai_detection',
                timestamp: DateTime.now(),
              );
              
              final existingIndex = _hazards.indexWhere((h) => h.hazardId == newHazard.hazardId);
              if (existingIndex >= 0) {
                _hazards[existingIndex] = newHazard;
              } else {
                _hazards.add(newHazard);
              }
              _latestUploadedHazards.add(newHazard);
            }
          }
          
          _isProcessingVideo = false;
          notifyListeners();
          return true;
        } else if (result['status'] == 'no_hazard_found') {
          // Valid response from backend stating no high confidence hazards were found.
          _currentDetections = result['detections'] != null ? (result['detections'] as List<dynamic>).map((b) => DetectionBox(
              x1: (b['x1'] as num).toDouble(),
              y1: (b['y1'] as num).toDouble(),
              x2: (b['x2'] as num).toDouble(),
              y2: (b['y2'] as num).toDouble(),
              label: b['label'] as String? ?? 'pothole',
              confidence: (b['confidence'] as num).toDouble(),
              lane: b['lane'] as String? ?? 'center',
            )).toList() : [];
          _latestUploadedHazards = [];
          _isProcessingVideo = false;
          notifyListeners();
          return false;
        }
      }
    } catch (e) {
      print('Error in processVideoUpload: $e');
    }

    _isProcessingVideo = false;
    notifyListeners();
    return false;
  }

  Future<bool> simulateVideoUpload({VehiclePreset? preset}) async {
    final vehicle = preset ?? _selectedVehicle;
    _isProcessingVideo = true;
    _uploadedVideoName = 'Simulated Dashcam';
    notifyListeners();
    
    // Simulate API processing delay
    await Future.delayed(const Duration(seconds: 2));
    
    final mockHazardId = await _apiService.reportHazardManually(
      vehicleId: vehicle.id,
      hazardType: 'pothole',
      latitude: vehicle.latitude,
      longitude: vehicle.longitude,
      lane: 'center',
      severity: 'high',
    );
    
    if (mockHazardId != null) {
      _currentDetections = [
        DetectionBox(
          x1: 0.3, y1: 0.5, x2: 0.7, y2: 0.9,
          label: 'pothole',
          confidence: 0.95,
          lane: 'center'
        )
      ];
      
      final newHazard = Hazard(
        hazardId: mockHazardId,
        vehicleId: vehicle.id,
        hazardType: 'pothole',
        confidence: 0.95,
        latitude: vehicle.latitude,
        longitude: vehicle.longitude,
        lane: 'center',
        severity: 'high',
        status: 'active',
        verifications: 1,
        source: 'ai_detection',
        timestamp: DateTime.now(),
      );
      
      _latestUploadedHazards = [newHazard];
      final existingIndex = _hazards.indexWhere((h) => h.hazardId == newHazard.hazardId);
      if (existingIndex >= 0) {
        _hazards[existingIndex] = newHazard;
      } else {
        _hazards.add(newHazard);
      }
      
      _isProcessingVideo = false;
      notifyListeners();
      return true;
    }
    
    _isProcessingVideo = false;
    notifyListeners();
    return false;
  }

  Future<void> verifyActiveHazard() async {
    // Verify ALL active hazards currently known (cluster verification)
    final activeHazards = _hazards.where((h) => h.status == 'active').toList();
    if (activeHazards.isEmpty) return;

    for (var hazard in activeHazards) {
      await _apiService.verifyHazard(hazard.hazardId);
      _firestoreService.markVerified(hazard.hazardId);
    }

    _voiceService.speak('${activeHazards.length} hazards verified. Updating road status.');
    notifyListeners();
  }

  Future<void> resetDemo() async {
    await _apiService.resetDemo();
    _hazards.clear();
    _currentDetections.clear();
    _uploadedVideoName = null;
    _latestUploadedHazards.clear();
    _nearbyActiveAlerts.clear();
    _announcedAlertIds.clear();
    _totalAlertsSent = 0;
    _voiceService.stop();
    notifyListeners();
  }

  void playVoiceAlert(String hazardType, int distanceM) {
    _voiceService.speakAlert(hazardType, distanceM);
  }

  @override
  void dispose() {
    _hazardSubscription?.cancel();
    _apiPollingTimer?.cancel();
    _voiceService.stop();
    super.dispose();
  }
}

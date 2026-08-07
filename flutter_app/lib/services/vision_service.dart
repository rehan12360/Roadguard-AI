import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';

class DetectedHazard {
  final String label;
  final double confidence;
  final double x1, y1, x2, y2;
  final DateTime timestamp;

  DetectedHazard({
    required this.label,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.timestamp,
  });

  double get centerX => (x1 + x2) / 2;
  double get centerY => (y1 + y2) / 2;
}

class VisionService {
  final FlutterVision vision = FlutterVision();
  bool isLoaded = false;
  List<DetectedHazard> _recentHazards = [];

  Future<void> initModel() async {
    await vision.loadYoloModel(
      labels: 'assets/models/labels.txt',
      modelPath: 'assets/models/roadguard_custom.tflite',
      modelVersion: "yolov8",
      quantization: false,
      numThreads: 4,
      useGpu: false, // Turned off GPU to prevent silent delegate failures on some phones
    );
    isLoaded = true;
  }

  Future<List<Map<String, dynamic>>> runInferenceOnFrame(CameraImage image) async {
    if (!isLoaded) return [];

    try {
      final result = await vision.yoloOnFrame(
        bytesList: image.planes.map((plane) => plane.bytes).toList(),
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.1,
        confThreshold: 0.1, // Ignored in v2 for yolov8, but kept for signature
        classThreshold: 0.1, // This is the actual threshold used for yolov8 in v2
      );
      if (result.isNotEmpty) {
        print("Detected ${result.length} items in frame");
      }
      return result;
    } catch (e) {
      print("Vision error: $e");
      return [];
    }
  }

  /// Merges duplicate potholes using spatiotemporal NMS (similar to the Python backend)
  List<DetectedHazard> processDetections(List<Map<String, dynamic>> rawDetections, int imageWidth, int imageHeight) {
    final now = DateTime.now();
    
    // Clean up old hazards (> 2.5 seconds old)
    _recentHazards.removeWhere((h) => now.difference(h.timestamp).inMilliseconds > 2500);

    List<DetectedHazard> currentFrameHazards = [];

    for (var d in rawDetections) {
      List<dynamic> box = d['box'];
      double x1 = box[0] / imageWidth;
      double y1 = box[1] / imageHeight;
      double x2 = box[2] / imageWidth;
      double y2 = box[3] / imageHeight;
      double conf = box[4] * 1.0;
      String label = d['tag'];

      final newHazard = DetectedHazard(
        label: label,
        confidence: conf,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        timestamp: now,
      );

      // Check against recent hazards to merge
      bool matched = false;
      for (var existing in _recentHazards) {
        double dist = sqrt(pow(newHazard.centerX - existing.centerX, 2) + pow(newHazard.centerY - existing.centerY, 2));
        if (dist < 0.15 && newHazard.label == existing.label) {
          matched = true;
          break;
        }
      }

      if (!matched) {
        currentFrameHazards.add(newHazard);
        _recentHazards.add(newHazard);
      }
    }

    return currentFrameHazards;
  }

  Future<void> dispose() async {
    await vision.closeYoloModel();
  }
}

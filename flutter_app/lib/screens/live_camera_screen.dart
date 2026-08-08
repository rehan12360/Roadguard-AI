import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/voice_service.dart';
import '../providers/demo_provider.dart';
import '../models/vehicle.dart';
import '../services/vision_service.dart'; // Keep for DetectedHazard model
import 'detection_video_screen.dart';

class LiveCameraScreen extends StatefulWidget {
  final VehiclePreset preset;
  const LiveCameraScreen({super.key, required this.preset});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  CameraController? _cameraController;
  final ApiService _apiService = ApiService();
  final DatabaseService _databaseService = DatabaseService();
  final VoiceService _voiceService = VoiceService();
  bool _isProcessing = false;
  List<DetectedHazard> _currentHazards = [];
  DateTime? _lastSpeakTime;
  Timer? _frameTimer;

  @override
  void initState() {
    super.initState();
    _voiceService.init();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    final cameras = await availableCameras();
    final firstCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first);

    // Using medium resolution for faster HTTP upload while preserving details
    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController!.initialize();

    if (mounted) {
      setState(() {});
      // HYBRID EDGE AI: Stream frames to the Python backend to bypass broken TFLite
      _frameTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
        if (_isProcessing || !_cameraController!.value.isInitialized) return;
        if (_cameraController!.value.isTakingPicture) return;
        
        _isProcessing = true;
        try {
          final xFile = await _cameraController!.takePicture();
          
          final result = await _apiService.processImageForInference(
            filePath: xFile.path,
            vehicleId: widget.preset.id,
            latitude: widget.preset.latitude,
            longitude: widget.preset.longitude,
          );

          if (result != null && result['status'] == 'success') {
             final List<dynamic> rawDetections = result['detections'];
             final List<DetectedHazard> newHazards = [];
             
             for (var d in rawDetections) {
                newHazards.add(DetectedHazard(
                   label: d['label'],
                   confidence: (d['confidence'] as num).toDouble(),
                   x1: (d['x1'] as num).toDouble(),
                   y1: (d['y1'] as num).toDouble(),
                   x2: (d['x2'] as num).toDouble(),
                   y2: (d['y2'] as num).toDouble(),
                   timestamp: DateTime.now(),
                ));
             }
             
             if (mounted) {
                setState(() {
                   _currentHazards = newHazards;
                });
             }
             
             // TTS Logic
             if (result['best_hazard'] != null) {
                final double conf = (result['best_hazard']['conf'] as num).toDouble();
                if (conf > 0.40) {
                    final now = DateTime.now();
                    if (_lastSpeakTime == null || now.difference(_lastSpeakTime!) > const Duration(seconds: 5)) {
                      _voiceService.speak('${result['best_hazard']['type']} detected ahead.');
                      _lastSpeakTime = now;
                    }
                }
             }
          }
        } catch (e) {
           print("Hybrid Edge stream error: $e");
        } finally {
           _isProcessing = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Live Edge AI Detection')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          CustomPaint(
            painter: BoundingBoxPainter(_currentHazards),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                _currentHazards.isEmpty
                    ? 'Scanning...'
                    : 'Hazard Detected!',
                style: TextStyle(
                  color: _currentHazards.isEmpty ? Colors.green : Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetectionVideoScreen(preset: widget.preset),
            ),
          );
        },
        icon: const Icon(Icons.video_library),
        label: const Text('Upload Video'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<DetectedHazard> hazards;

  BoundingBoxPainter(this.hazards);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.red;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var h in hazards) {
      // Coordinates from vision service are normalized 0..1
      final rect = Rect.fromLTRB(
        h.x1 * size.width,
        h.y1 * size.height,
        h.x2 * size.width,
        h.y2 * size.height,
      );
      canvas.drawRect(rect, paint);

      textPainter.text = TextSpan(
        text: '\${h.label} \${(h.confidence * 100).toStringAsFixed(0)}%',
        style: const TextStyle(color: Colors.white, backgroundColor: Colors.red),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

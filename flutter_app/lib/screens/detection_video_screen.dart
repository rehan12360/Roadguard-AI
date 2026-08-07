import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/demo_provider.dart';
import '../widgets/video_box_painter.dart';
import '../models/vehicle.dart';

class DetectionVideoScreen extends StatefulWidget {
  final VehiclePreset? preset;

  const DetectionVideoScreen({super.key, this.preset});

  @override
  State<DetectionVideoScreen> createState() => _DetectionVideoScreenState();
}

class _DetectionVideoScreenState extends State<DetectionVideoScreen> {
  VideoPlayerController? _videoController;
  final ImagePicker _picker = ImagePicker();
  bool _isPlaying = false;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadVideo() async {
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    await _setupVideoPlayer(File(file.path), file.name);
  }

  Future<void> _setupVideoPlayer(File videoFile, String fileName) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(videoFile);

    await _videoController!.initialize();
    _videoController!.setLooping(true);
    _videoController!.play();

    setState(() => _isPlaying = true);

    final demoProvider = Provider.of<DemoProvider>(context, listen: false);
    final success = await demoProvider.processVideoUpload(videoFile.path, fileName, preset: widget.preset);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No high-confidence hazards (> 70%) detected in this video.'),
          backgroundColor: Color(0xFF121826),
        ),
      );
    }
  }

  void _triggerSimulatedVideoDemo() async {
    final demoProvider = Provider.of<DemoProvider>(context, listen: false);
    // Simulate processing with built-in telemetry clip data
    await demoProvider.simulateVideoUpload(preset: widget.preset);
  }

  @override
  Widget build(BuildContext context) {
    final demoProvider = Provider.of<DemoProvider>(context);
    final isProcessing = demoProvider.isProcessingVideo;
    final detections = demoProvider.currentDetections;
    final hazards = demoProvider.latestUploadedHazards;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.videocam_outlined, color: Color(0xFFFF2A5F)),
            const SizedBox(width: 8),
            Text(
              widget.preset != null ? '${widget.preset!.name.split('—').first.trim()} — AI Detector Mode' : 'Car A — AI Detector Mode', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ],
        ),
        backgroundColor: const Color(0xFF121826),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Colors.white70),
            tooltip: 'Reset Demo',
            onPressed: () async {
              await Provider.of<DemoProvider>(context, listen: false).resetDemo();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demo reset successfully!'),
                  backgroundColor: Color(0xFF121826),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF121826),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isProcessing ? null : _pickAndUploadVideo,
                        icon: const Icon(Icons.upload_file, color: Colors.black),
                        label: const Text('UPLOAD MP4 DASHCAM', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F2FE),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: isProcessing ? null : _triggerSimulatedVideoDemo,
                      icon: const Icon(Icons.auto_awesome, color: Color(0xFF00F2FE)),
                      label: const Text('DEMO CLIP', style: TextStyle(color: Color(0xFF00F2FE), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        side: const BorderSide(color: Color(0xFF00F2FE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Video Player Box with Canvas Bounding Box Painter
              Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00F2FE).withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F2FE).withOpacity(0.15),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Video Player or Placeholder
                      _videoController != null && _videoController!.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            )
                          : Container(
                              color: const Color(0xFF151C2C),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.video_library_outlined, size: 48, color: Colors.grey[600]),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Upload dashcam video to start YOLOv8 AI detection',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),

                      // Bounding Box Overlay Canvas
                      if (detections.isNotEmpty)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: VideoBoxPainter(
                              boxes: detections,
                              showLaneOverlay: true,
                            ),
                          ),
                        ),

                      // HUD Top Bar
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFF2A5F)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.circle, color: Color(0xFFFF2A5F), size: 10),
                                  SizedBox(width: 6),
                                  Text(
                                    'AI CAM ACTIVE',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '30.7046° N, 76.7179° E',
                                style: TextStyle(color: Color(0xFF00F2FE), fontSize: 11, fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Processing Spinner
                      if (isProcessing)
                        Container(
                          color: Colors.black.withOpacity(0.7),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF00F2FE)),
                              SizedBox(height: 12),
                              Text(
                                'YOLOv8 Processing Video Frames...',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Live Telemetry Cards for EACH hazard detected!
              if (hazards.isNotEmpty) ...hazards.map((hazard) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121826),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'AI DETECTION TELEMETRY (${hazard.hazardId.substring(0, 8)})',
                            style: const TextStyle(color: Color(0xFF00F2FE), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                          ),
                          const Icon(Icons.radar, color: Color(0xFF00F2FE), size: 18),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTelemetryItem(
                            'HAZARD',
                            hazard.hazardType.toUpperCase(),
                            const Color(0xFFFF2A5F),
                          ),
                          _buildTelemetryItem(
                            'CONFIDENCE',
                            '${(hazard.confidence * 100).round()}%',
                            const Color(0xFF00F2FE),
                          ),
                          _buildTelemetryItem(
                            'LANE',
                            hazard.lane.toUpperCase(),
                            const Color(0xFFFFB300),
                          ),
                          _buildTelemetryItem(
                            'SEVERITY',
                            hazard.severity.toUpperCase(),
                            const Color(0xFFFF2A5F),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )).toList(),

              if (hazards.isEmpty && !isProcessing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121826),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Center(
                    child: Text('NO HAZARDS DETECTED YET', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),

              const SizedBox(height: 16),

              // Upload Confirmation Card
              if (hazards.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00E676).withOpacity(0.15),
                        const Color(0xFF121826),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF00E676).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_upload, color: Colors.black, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${hazards.length} Hazard(s) Logged & Uploaded ✅',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Broadcasted to all vehicles within 500m geofence radius via Cloud Backend.',
                              style: TextStyle(color: Colors.grey[300], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}

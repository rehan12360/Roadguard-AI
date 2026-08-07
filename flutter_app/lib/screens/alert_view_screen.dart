import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/demo_provider.dart';
import '../models/vehicle.dart';
import 'detection_video_screen.dart';
import 'live_camera_screen.dart';

class AlertViewScreen extends StatefulWidget {
  final VehiclePreset preset;

  const AlertViewScreen({super.key, required this.preset});

  @override
  State<AlertViewScreen> createState() => _AlertViewScreenState();
}

class _AlertViewScreenState extends State<AlertViewScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  final Set<String> _localAnnouncedAlertIds = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demoProvider = Provider.of<DemoProvider>(context);
    final vehicle = widget.preset;
    final distanceList = <int>[0];
    final alert = demoProvider.getAlertForVehicle(vehicle, outDistanceM: distanceList);
    final distanceM = distanceList[0];

    // Trigger local voice alert if this screen is acting as this vehicle
    if (alert != null && !_localAnnouncedAlertIds.contains(alert.hazardId)) {
      _localAnnouncedAlertIds.add(alert.hazardId);
      // Wait a tick to allow build to finish before playing sound
      WidgetsBinding.instance.addPostFrameCallback((_) {
        demoProvider.playVoiceAlert(alert.hazardType, distanceM);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        title: Text(
          'Alert HUD · ${vehicle.name.split('—').first.trim()}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: demoProvider.nearbyActiveAlerts.isNotEmpty
              ? Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: demoProvider.nearbyActiveAlerts.length,
                        itemBuilder: (context, index) {
                          final h = demoProvider.nearbyActiveAlerts[index];
                          // calculate distance on the fly for UI
                          final dist = demoProvider.calculateDistanceM(
                            vehicle.latitude, vehicle.longitude,
                            h.latitude, h.longitude,
                          ).round();
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2E0814), Color(0xFF121826)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFFF2A5F), width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF2A5F).withOpacity(0.35),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF2A5F), size: 36),
                                        const SizedBox(width: 10),
                                        Text(
                                          'HAZARD ALERT (< 500m)',
                                          style: TextStyle(
                                            color: const Color(0xFFFF2A5F).withOpacity(0.9),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      h.hazardType.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 32,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFB300).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFFFFB300)),
                                      ),
                                      child: Text(
                                        'Distance: $dist meters ahead',
                                        style: const TextStyle(
                                          color: Color(0xFFFFB300),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
        
                                    // Lane & Safety Guidance
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'RECOMMENDED ACTION',
                                            style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Pothole detected in ${h.lane.toUpperCase()} LANE. Slow down & steer right.',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFF00F2FE),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
        
                                    const SizedBox(height: 20),
        
                                    // Climbing Live Confidence Bar
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Network Confidence', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        Text(
                                          '${(h.confidence * 100).round()}%',
                                          style: const TextStyle(color: Color(0xFF00F2FE), fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: h.confidence,
                                        minHeight: 8,
                                        backgroundColor: Colors.white10,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Verify Button (Verifies all nearby hazards at once when Dashcam finishes)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveCameraScreen(preset: widget.preset),
                            ),
                          );
                        },
                        icon: const Icon(Icons.camera_alt_outlined, color: Colors.black),
                        label: Text(
                          'OPEN CAMERA TO VERIFY ${demoProvider.nearbyActiveAlerts.length} HAZARDS',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 64),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'ROAD CLEAR — NO HAZARDS NEARBY',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        vehicle.role == 'out_of_scope'
                            ? 'Vehicle is > 500m outside active hazard geofence radius.'
                            : 'Scanning network for live V2V road hazards...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

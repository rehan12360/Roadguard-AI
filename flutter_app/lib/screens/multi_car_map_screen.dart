import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../providers/demo_provider.dart';
import 'hazard_detail_sheet.dart';

class MultiCarMapScreen extends StatefulWidget {
  const MultiCarMapScreen({super.key});

  @override
  State<MultiCarMapScreen> createState() => _MultiCarMapScreenState();
}

class _MultiCarMapScreenState extends State<MultiCarMapScreen> {
  GoogleMapController? _mapController;

  static const LatLng _centerPos = LatLng(30.7070, 76.7195);

  @override
  Widget build(BuildContext context) {
    final demoProvider = Provider.of<DemoProvider>(context);
    final hazards = demoProvider.hazards;
    final selectedVehicle = demoProvider.selectedVehicle;

    // Build vehicle markers for Car A, B, C, D
    final Set<Marker> markers = {};

    for (final v in VehiclePreset.defaultPresets) {
      final isSelected = v.id == selectedVehicle.id;

      BitmapDescriptor icon;
      if (v.role == 'detector') {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      } else if (v.role == 'alerted') {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      } else {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      }

      markers.add(
        Marker(
          markerId: MarkerId(v.id),
          position: LatLng(v.latitude, v.longitude),
          icon: icon,
          infoWindow: InfoWindow(
            title: '${v.name} ${isSelected ? '(YOU)' : ''}',
            snippet: '${v.statusDescription} · Distance: ${v.simulatedDistanceMeters}m',
          ),
        ),
      );
    }

    // Add hazard markers
    for (final h in hazards) {
      markers.add(
        Marker(
          markerId: MarkerId(h.hazardId),
          position: LatLng(h.latitude, h.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => HazardDetailSheet(hazard: h),
            );
          },
        ),
      );
    }

    // Build 500m geofence circle around detector / hazard
    final Set<Circle> circles = {
      Circle(
        circleId: const CircleId('geofence_500m'),
        center: const LatLng(30.7046, 76.7179), // Car A location
        radius: 500, // 500 meters
        fillColor: const Color(0xFFFF2A5F).withOpacity(0.12),
        strokeColor: const Color(0xFFFF2A5F),
        strokeWidth: 2,
      ),
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.map_outlined, color: Color(0xFF00F2FE)),
            SizedBox(width: 8),
            Text('Multi-Vehicle 500m Radar Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        backgroundColor: const Color(0xFF121826),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: _centerPos, zoom: 14.5),
            markers: markers,
            circles: circles,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (controller) => _mapController = controller,
          ),

          // Map Legend Banner
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF121826).withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(const Color(0xFFFF2A5F), 'Car A (Detector)'),
                  _buildLegendItem(const Color(0xFFFFB300), 'Car B & C (< 500m)'),
                  _buildLegendItem(Colors.cyan, 'Car D (> 500m)'),
                ],
              ),
            ),
          ),

          // Bottom Vehicle Status Carousel
          Positioned(
            bottom: 16,
            left: 12,
            right: 12,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF121826).withOpacity(0.95),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00F2FE).withOpacity(0.3)),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: VehiclePreset.defaultPresets.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                itemBuilder: (ctx, index) {
                  final v = VehiclePreset.defaultPresets[index];
                  final isSelected = v.id == selectedVehicle.id;

                  Color statusColor;
                  if (v.role == 'detector') {
                    statusColor = const Color(0xFFFF2A5F);
                  } else if (v.role == 'alerted') {
                    statusColor = const Color(0xFFFFB300);
                  } else {
                    statusColor = Colors.grey;
                  }

                  return GestureDetector(
                    onTap: () {
                      demoProvider.selectVehicle(v);
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(LatLng(v.latitude, v.longitude), 15.5),
                      );
                    },
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? statusColor.withOpacity(0.18) : const Color(0xFF1A2234),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? statusColor : Colors.white10,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            v.name.split('—').first.trim(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            v.statusDescription,
                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

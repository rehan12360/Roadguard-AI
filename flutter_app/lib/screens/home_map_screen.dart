import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/hazard.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../widgets/alert_popup.dart';

const double kAlertRadiusMeters = 500;

class HomeMapScreen extends StatefulWidget {
  final String vehicleId;
  const HomeMapScreen({super.key, required this.vehicleId});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final _firestoreService = FirestoreService();
  final _apiService = ApiService();
  final _voiceService = VoiceService();

  GoogleMapController? _mapController;
  StreamSubscription<List<Hazard>>? _hazardSub;
  StreamSubscription<Position>? _positionSub;

  Position? _currentPosition;
  List<Hazard> _allHazards = [];
  final Set<String> _alreadyAnnounced = {};
  Hazard? _activeAlert;
  int _activeAlertDistance = 0;

  @override
  void initState() {
    super.initState();
    _voiceService.init();
    _initLocation();
    _listenToHazards();
  }

  Future<void> _initLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = pos);

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // meters before triggering an update
      ),
    ).listen((pos) {
      setState(() => _currentPosition = pos);
      _checkForNearbyHazards();
    });
  }

  void _listenToHazards() {
    _hazardSub = _firestoreService.activeHazardsStream().listen((hazards) {
      setState(() => _allHazards = hazards);
      _checkForNearbyHazards();
    });
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLambda = (lon2 - lon1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void _checkForNearbyHazards() {
    if (_currentPosition == null) return;

    for (final h in _allHazards) {
      if (h.vehicleId == widget.vehicleId) continue; // skip own reports
      if (_alreadyAnnounced.contains(h.hazardId)) continue;

      final dist = _distanceMeters(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        h.latitude,
        h.longitude,
      );

      if (dist <= kAlertRadiusMeters) {
        _alreadyAnnounced.add(h.hazardId);
        setState(() {
          _activeAlert = h;
          _activeAlertDistance = dist.round();
        });
        _voiceService.speakAlert(h.hazardType, dist.round());
        break; // one alert at a time on screen
      }
    }
  }

  Future<void> _reportHazardAtCurrentLocation() async {
    if (_currentPosition == null) return;

    final type = await _pickHazardType();
    if (type == null) return;

    final id = await _apiService.reportHazardManually(
      vehicleId: widget.vehicleId,
      hazardType: type,
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(id != null
              ? 'Hazard reported successfully'
              : 'Failed to report hazard — check backend connection'),
        ),
      );
    }
  }

  Future<String?> _pickHazardType() {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.warning_amber),
              title: const Text('Pothole'),
              onTap: () => Navigator.pop(ctx, 'pothole'),
            ),
            ListTile(
              leading: const Icon(Icons.water_drop),
              title: const Text('Waterlogging'),
              onTap: () => Navigator.pop(ctx, 'waterlogging'),
            ),
            ListTile(
              leading: const Icon(Icons.construction),
              title: const Text('Road Damage'),
              onTap: () => Navigator.pop(ctx, 'road_damage'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Obstruction'),
              onTap: () => Navigator.pop(ctx, 'obstruction'),
            ),
          ],
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    return _allHazards.map((h) {
      return Marker(
        markerId: MarkerId(h.hazardId),
        position: LatLng(h.latitude, h.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          h.isCritical ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: h.hazardType.toUpperCase(),
          snippet:
              '${(h.confidence * 100).round()}% confidence · ${h.source == 'manual' ? 'Reported by driver' : 'AI detected'}',
        ),
      );
    }).toSet();
  }

  @override
  void dispose() {
    _hazardSub?.cancel();
    _positionSub?.cancel();
    _voiceService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialPos = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(30.7046, 76.7179); // fallback default

    return Scaffold(
      appBar: AppBar(
        title: Text('RoadGuard · ${widget.vehicleId}'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialPos, zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _buildMarkers(),
            onMapCreated: (controller) => _mapController = controller,
          ),
          if (_activeAlert != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: AlertPopup(
                hazard: _activeAlert!,
                distanceMeters: _activeAlertDistance,
                onDismiss: () => setState(() => _activeAlert = null),
                onVerify: () {
                  _firestoreService.markVerified(_activeAlert!.hazardId);
                  setState(() => _activeAlert = null);
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _reportHazardAtCurrentLocation,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Report Hazard'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}

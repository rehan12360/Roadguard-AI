import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/demo_provider.dart';
import '../models/hazard.dart';
import '../services/database_service.dart';
import '../services/pdf_export_service.dart';
import 'hazard_detail_sheet.dart';

enum Role { driver, admin }

class CommandCenterScreen extends StatefulWidget {
  const CommandCenterScreen({super.key});

  @override
  State<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends State<CommandCenterScreen> {
  Role _currentRole = Role.driver;
  GoogleMapController? _mapController;
  bool _isGeneratingReport = false;
  
  static const LatLng _centerPos = LatLng(30.7070, 76.7195);

  @override
  Widget build(BuildContext context) {
    final demoProvider = Provider.of<DemoProvider>(context);
    final hazards = demoProvider.hazards;

    final filteredHazards = List<Hazard>.from(hazards);
    if (_currentRole == Role.admin) {
      filteredHazards.sort((a, b) => b.confidence.compareTo(a.confidence));
    } else {
      filteredHazards.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    final Set<Marker> markers = filteredHazards.map((h) {
      final hue = _currentRole == Role.admin
          ? (h.isCritical ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange)
          : BitmapDescriptor.hueCyan;
          
      return Marker(
        markerId: MarkerId(h.hazardId),
        position: LatLng(h.latitude, h.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => HazardDetailSheet(hazard: h),
          );
        },
      );
    }).toSet();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Command Center', style: TextStyle(fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 4,
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(target: _centerPos, zoom: 14.5),
                  markers: markers,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) => _mapController = controller,
                ),
              ),
              Expanded(flex: 6, child: Container(color: const Color(0xFF0A0E17))),
            ],
          ),
          
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: _buildRoleSwitcher(),
            ),
          ),
          
          DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161618).withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentRole == Role.admin ? 'Municipality Dashboard' : 'Driver Dashboard',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_currentRole == Role.admin) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          if (_isGeneratingReport) return;
                          setState(() => _isGeneratingReport = true);
                          
                          // Mock slight delay for animation
                          await Future.delayed(const Duration(milliseconds: 1500));
                          
                          if (mounted) {
                            await PdfExportService.exportAndShareReport(filteredHazards);
                            setState(() => _isGeneratingReport = false);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: _isGeneratingReport ? Colors.blueGrey : const Color(0xFF00F2FE),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              if (!_isGeneratingReport)
                                BoxShadow(
                                  color: const Color(0xFF00F2FE).withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _isGeneratingReport 
                                  ? const SizedBox(
                                      width: 16, height: 16, 
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                    )
                                  : const Icon(Icons.picture_as_pdf, color: Colors.black, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _isGeneratingReport ? 'AI Generating Insights...' : 'Export Smart Report',
                                style: TextStyle(
                                  color: _isGeneratingReport ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.2),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: ListView.builder(
                          key: ValueKey<Role>(_currentRole),
                          controller: scrollController,
                          itemCount: filteredHazards.length,
                          itemBuilder: (context, index) {
                            return _buildAnimatedListItem(filteredHazards[index], index);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSwitcher() {
    final isAdmin = _currentRole == Role.admin;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentRole = isAdmin ? Role.driver : Role.admin;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 260,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: 4,
              bottom: 4,
              left: isAdmin ? 130 : 4,
              right: isAdmin ? 4 : 130,
              child: Container(
                decoration: BoxDecoration(
                  color: isAdmin ? const Color(0xFFE94057) : const Color(0xFF00F2FE),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: (isAdmin ? const Color(0xFFE94057) : const Color(0xFF00F2FE)).withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Driver Mode',
                      style: TextStyle(
                        color: isAdmin ? Colors.white54 : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Municipality',
                      style: TextStyle(
                        color: isAdmin ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedListItem(Hazard hazard, int index) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(hazard.hazardId + _currentRole.toString()),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Interval(
        (index * 0.1).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: _buildHazardCard(hazard),
    );
  }

  Widget _buildHazardCard(Hazard hazard) {
    final isAdmin = _currentRole == Role.admin;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAdmin 
                ? (hazard.isCritical ? Colors.redAccent.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2))
                : Colors.cyan.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAdmin ? Icons.warning_amber_rounded : Icons.drive_eta,
              color: isAdmin 
                ? (hazard.isCritical ? Colors.redAccent : Colors.orangeAccent)
                : Colors.cyan,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hazard.hazardType.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                if (isAdmin) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red),
                        ),
                        child: const Text('NEEDS REPAIR', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text('Confidence: ${(hazard.confidence * 100).toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ] else ...[
                  const Text('Approaching hazard - Reduce speed', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ],
            ),
          ),
          if (isAdmin)
            Column(
              children: [
                const Icon(Icons.people, color: Colors.white54, size: 16),
                Text('${hazard.verifications}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    await DatabaseService().deleteHazard(hazard.hazardId);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Text('MARK REPAIRED', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          else
            const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
        ],
      ),
    );
  }
}

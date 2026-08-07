import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/demo_provider.dart';

class StatsDashboardScreen extends StatelessWidget {
  const StatsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demoProvider = Provider.of<DemoProvider>(context);
    final hazards = demoProvider.hazards;
    final totalAlerts = demoProvider.networkAlertsBroadcasted;

    final totalVerifications = hazards.fold<int>(0, (sum, h) => sum + h.verifications);
    final avgConfidence = hazards.isNotEmpty
        ? (hazards.fold<double>(0.0, (sum, h) => sum + h.confidence) / hazards.length)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bar_chart_outlined, color: Color(0xFF00F2FE)),
            SizedBox(width: 8),
            Text('Pitch Analytics & Controls', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        backgroundColor: const Color(0xFF121826),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pitch Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B263B), Color(0xFF0F1523)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00F2FE).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HACKATHON DEMO METRICS',
                      style: TextStyle(color: Color(0xFF00F2FE), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'RoadGuard Network Performance',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time stats tracked live during pitch demonstrations.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Stat Grid Cards
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _buildStatCard(
                    'HAZARDS DETECTED',
                    '${hazards.length}',
                    'Logged via AI Video',
                    const Color(0xFFFF2A5F),
                    Icons.warning_amber_rounded,
                  ),
                  _buildStatCard(
                    'ALERTS BROADCAST',
                    '$totalAlerts',
                    'Within 500m Radius',
                    const Color(0xFFFFB300),
                    Icons.cell_tower,
                  ),
                  _buildStatCard(
                    'VERIFICATIONS',
                    '$totalVerifications',
                    'Peer Consensus',
                    const Color(0xFF00E676),
                    Icons.verified_user_outlined,
                  ),
                  _buildStatCard(
                    'AVG CONFIDENCE',
                    avgConfidence > 0 ? '${(avgConfidence * 100).round()}%' : '--',
                    'Live Network Accuracy',
                    const Color(0xFF00F2FE),
                    Icons.speed,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Latency Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF121826),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt, color: Color(0xFF00F2FE), size: 28),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'V2V Alert Latency',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Cloud Backend Sync Time',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '< 0.8s',
                      style: TextStyle(color: Color(0xFF00F2FE), fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Reset Demo Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await demoProvider.resetDemo();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Demo environment reset successfully! Ready for next rehearsal.'),
                        backgroundColor: Color(0xFF121826),
                      ),
                    );
                  },
                  icon: const Icon(Icons.restart_alt, color: Colors.white),
                  label: const Text(
                    'RESET DEMO ENVIRONMENT',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.0),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A2234),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 20),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'providers/demo_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/multi_car_map_screen.dart';
import 'screens/stats_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: 'https://ipnuxbyyphzqayguosia.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlwbnV4Ynl5cGh6cWF5Z3Vvc2lhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxMzkxNjIsImV4cCI6MjEwMTcxNTE2Mn0.Z4XaIeCDxQUXWeHO19yzZKhYzyAQJaA2Z2w7KEhh_Zc',
    );
  } catch (e) {
    print('Supabase init warning: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => DemoProvider(),
      child: const RoadGuardApp(),
    ),
  );
}

class RoadGuardApp extends StatelessWidget {
  const RoadGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoadGuard AI Pitch Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFFFF2A5F),
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF2A5F),
          secondary: Color(0xFF00F2FE),
          surface: Color(0xFF121826),
        ),
      ),
      home: const PitchMainNavigation(),
    );
  }
}

class PitchMainNavigation extends StatefulWidget {
  const PitchMainNavigation({super.key});

  @override
  State<PitchMainNavigation> createState() => _PitchMainNavigationState();
}

class _PitchMainNavigationState extends State<PitchMainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const DashboardScreen(),
      const MultiCarMapScreen(),
      const StatsDashboardScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121826),
          border: const Border(top: BorderSide(color: Colors.white10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF121826),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFF2A5F),
          unselectedItemColor: Colors.grey[500],
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_customize_outlined),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              label: 'Radar Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights),
              label: 'Pitch Stats',
            ),
          ],
        ),
      ),
    );
  }
}

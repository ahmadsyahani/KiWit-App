import 'package:flutter/material.dart';
import '../../core/widgets/custom_bottom_nav.dart';
import '../home/presentation/screens/home_screen.dart';
import '../map/presentation/screens/map_screen.dart';
import '../report/presentation/screens/report_screen.dart';
import '../profile/presentation/screens/profile_screen.dart';
import '../scan/presentation/screens/scan_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    MapScreen(),
    ReportScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        onScanPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScanScreen()),
          );
        },
      ),
    );
  }
}
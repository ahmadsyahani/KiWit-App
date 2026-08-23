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

  // Track which tabs have been activated to lazy-load heavy widgets (e.g. Map, Charts)
  final Set<int> _activatedTabs = {0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Home (Always loaded first)
          const HomeScreen(),

          // Tab 1: Map (Lazy loaded only when clicked to prevent startup frame drop)
          _activatedTabs.contains(1)
              ? const MapScreen()
              : const SizedBox.shrink(),

          // Tab 2: Report
          _activatedTabs.contains(2)
              ? const ReportScreen()
              : const SizedBox.shrink(),

          // Tab 3: Profile
          _activatedTabs.contains(3)
              ? const ProfileScreen()
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (!_activatedTabs.contains(index)) {
            setState(() {
              _activatedTabs.add(index);
              _currentIndex = index;
            });
          } else {
            setState(() => _currentIndex = index);
          }
        },
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
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/home_header.dart';
import '../widgets/hero_banner_card.dart';
import '../widgets/inspection_chart_card.dart';
import '../widgets/recent_inspection_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: const [
            HomeHeader(),
            SizedBox(height: 24),
            HeroBannerCard(),
            SizedBox(height: 24),
            InspectionChartCard(),
            SizedBox(height: 24),
            RecentInspectionList(),
            SizedBox(height: 100), // Bottom padding for navbar
          ],
        ),
      ),
    );
  }
}

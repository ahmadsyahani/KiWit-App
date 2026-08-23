import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';

class TreeDetailScreen extends StatelessWidget {
  const TreeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image with info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.textMuted,
                  ),
                  child: Stack(
                    children: [
                      // Temp icon instead of image
                      const Center(child: Icon(Icons.park, size: 80, color: Colors.white54)),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),

                                  child: const Text('ID #104', style: TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                                const SizedBox(width: 8),
                                const RiskBadge(level: RiskLevel.rendah),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Pohon Trembesi',
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: const [
                                Icon(LucideIcons.mapPin, color: Colors.white70, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Jl. Kertajaya, Surabaya',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Stats Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _buildStatCard('Spesies', 'Trembesi')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('DBH', '85 cm')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('Kemiringan', '70°')),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Cacat Terdeteksi
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Cacat Terdeteksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildDefectCard(title: 'Rongga Batang', status: 'Sedang', statusColor: Colors.amber, isProgress: true, progressValue: 0.35, progressText: '35%'),
                  const SizedBox(height: 12),
                  _buildDefectCard(title: 'Jamur Pelapuk', status: 'Positif', statusColor: Colors.deepOrange, isProgress: false),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Riwayat Inspeksi
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Riwayat Inspeksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildHistoryTimeline(score: 85, date: '14 Agt 2026', inspector: 'Ahmad Syahani', notes: 'Kondisi stabil, tidak ada perubahan signifikan.', isFirst: true, isLast: false),
                  _buildHistoryTimeline(score: 78, date: '30 Jul 2026', inspector: 'Ahmad Syahani', notes: 'Ditemukan bekas luka kecil pada batang.', isFirst: false, isLast: true, isOld: true),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDefectCard({
    required String title,
    required String status,
    required Color statusColor,
    required bool isProgress,
    double? progressValue,
    String? progressText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),

                child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (isProgress) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(progressText!, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildHistoryTimeline({
    required int score,
    required String date,
    required String inspector,
    required String notes,
    required bool isFirst,
    required bool isLast,
    bool isOld = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isOld ? AppColors.surface : AppColors.primary,
                    shape: BoxShape.circle,
                    border: isOld ? Border.all(color: AppColors.border) : null,
                  ),
                  child: Center(
                    child: Text(
                      score.toString(),
                      style: TextStyle(
                        color: isOld ? AppColors.textMuted : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(date, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        const RiskBadge(level: RiskLevel.rendah),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(inspector, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(notes, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

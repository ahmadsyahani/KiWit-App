import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../scan/data/models/saved_inspection.dart';

class InspectionChartCard extends StatelessWidget {
  const InspectionChartCard({
    required this.records,
    required this.today,
    super.key,
  });

  final List<SavedInspection> records;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final days = inspectionWeekDays(today);
    final counts = inspectionDailyCounts(records, today);
    final total = counts.fold<int>(0, (sum, count) => sum + count);
    final largest = counts.fold<int>(0, (max, count) => count > max ? count : max);
    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tren Inspeksi Harian',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('7 hari terakhir', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  const Text('total', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= days.length) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          space: 8,
                          child: Text(
                            weekdays[days[index].weekday - 1],
                            style: TextStyle(
                              color: index == 6 ? AppColors.primary : AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((spot) {
                      final index = spot.x.round();
                      return LineTooltipItem(
                        '${formatInspectionDate(days[index])}\n${counts[index]} inspeksi',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    }).toList(),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: largest == 0 ? 1 : largest + 1.0,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(7, (index) => FlSpot(index.toDouble(), counts[index].toDouble())),
                    isCurved: false,
                    color: AppColors.primary,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: AppColors.primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (total == 0) ...[
            const SizedBox(height: 12),
            const Text(
              'Belum ada inspeksi dalam 7 hari terakhir.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

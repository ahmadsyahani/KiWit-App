import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';

class ReportAnalyticsChart extends StatefulWidget {
  final int totalInspected;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;

  const ReportAnalyticsChart({
    super.key,
    required this.totalInspected,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
  });

  @override
  State<ReportAnalyticsChart> createState() => _ReportAnalyticsChartState();
}

class _ReportAnalyticsChartState extends State<ReportAnalyticsChart> {
  int _selectedView = 0; // 0: Distribusi Risiko, 1: Tingkat Kesehatan Avg
  int _touchedBarIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.barChart3,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistik Risiko Pohon',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Matriks Evaluasi ISA-TRAQ',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // View Switcher Tabs
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _buildSwitchTab('Risiko', 0),
                    _buildSwitchTab('Tren', 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart Display Area
          SizedBox(
            height: 160,
            child: _selectedView == 0
                ? _buildRiskDistributionChart()
                : _buildWeeklyTrendChart(),
          ),

          const SizedBox(height: 16),
          // Interactive Legend Pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendPill(
                color: const Color(0xFFEF4444),
                label: 'Kritis',
                count: widget.criticalCount,
              ),
              _buildLegendPill(
                color: const Color(0xFFF97316),
                label: 'Tinggi',
                count: widget.highCount,
              ),
              _buildLegendPill(
                color: const Color(0xFFEAB308),
                label: 'Sedang',
                count: widget.mediumCount,
              ),
              _buildLegendPill(
                color: const Color(0xFF10B981),
                label: 'Rendah',
                count: widget.lowCount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTab(String text, int index) {
    final isSelected = _selectedView == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedView = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRiskDistributionChart() {
    final values = [
      widget.criticalCount.toDouble(),
      widget.highCount.toDouble(),
      widget.mediumCount.toDouble(),
      widget.lowCount.toDouble(),
    ];
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final topLimit = (maxVal < 4 ? 4.0 : (maxVal + 2)).toDouble();

    final colors = [
      const [Color(0xFFFF4B55), Color(0xFFDC2626)],
      const [Color(0xFFFB923C), Color(0xFFEA580C)],
      const [Color(0xFFFDE047), Color(0xFFCA8A04)],
      const [Color(0xFF34D399), Color(0xFF059669)],
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: topLimit,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E293B),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              const labels = ['Kritis', 'Tinggi', 'Sedang', 'Rendah'];
              return BarTooltipItem(
                '${labels[groupIndex]}\n${rod.toY.toInt()} Pohon',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
          touchCallback: (event, response) {
            if (response?.spot != null) {
              setState(() {
                _touchedBarIndex = response!.spot!.touchedBarGroupIndex;
              });
            } else {
              setState(() {
                _touchedBarIndex = -1;
              });
            }
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const titles = ['Kritis', 'Tinggi', 'Sedang', 'Rendah'];
                if (value.toInt() >= 0 && value.toInt() < titles.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      titles[value.toInt()],
                      style: TextStyle(
                        color: _touchedBarIndex == value.toInt()
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: _touchedBarIndex == value.toInt()
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withValues(alpha: 0.7),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(4, (index) {
          final isTouched = index == _touchedBarIndex;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index],
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors[index],
                ),
                width: isTouched ? 28 : 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: topLimit,
                  color: AppColors.background,
                ),
              ),
            ],
          );
        }),
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutBack,
    );
  }

  Widget _buildWeeklyTrendChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const weeks = ['Mgu 1', 'Mgu 2', 'Mgu 3', 'Mgu 4'];
                if (value.toInt() >= 0 && value.toInt() < weeks.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      weeks[value.toInt()],
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 3,
        minY: 0,
        maxY: 12,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 4),
              FlSpot(1, 7),
              FlSpot(2, 6),
              FlSpot(3, 9),
            ],
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 3,
                strokeColor: AppColors.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.25),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPill({
    required Color color,
    required String label,
    required int count,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$label ($count)',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

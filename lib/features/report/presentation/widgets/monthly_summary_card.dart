import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class MonthlySummaryCard extends StatelessWidget {
  const MonthlySummaryCard({
    required this.inspectedCount,
    required this.criticalCount,
    required this.highCount,
    required this.pendingSyncCount,
    required this.periodLabel,
    this.loading = false,
    super.key,
  });

  final int inspectedCount;
  final int criticalCount;
  final int highCount;
  final int pendingSyncCount;
  final String periodLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ringkasan inspeksi', style: TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 5),
        Text(periodLabel, style: const TextStyle(
          color: Color(0xFFD0E5D7), fontSize: 12,
        )),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(12) <= 15 ? 4 : 2;
          final gap = columns == 4 ? 4.0 : 10.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap, runSpacing: 10,
            children: [
              _stat(width, inspectedCount, 'Diinspeksi'),
              _stat(width, criticalCount, 'Kritis'),
              _stat(width, highCount, 'Tinggi'),
              _stat(width, pendingSyncCount, 'Belum sinkron'),
            ],
          );
        }),
      ],
    ),
  );

  Widget _stat(double width, int value, String label) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loading ? '—' : '$value', style: const TextStyle(
            color: Colors.white, fontSize: 27, fontWeight: FontWeight.w700,
            height: 1.15,
          )),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(
            color: Color(0xFFE1EEE5), fontSize: 11, height: 1.4,
          )),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/report_providers.dart';

/// Keeps edits local until Apply, so dismissing the sheet preserves the report.
class ReportPeriodSheet extends StatefulWidget {
  const ReportPeriodSheet({
    required this.period,
    required this.customDate,
    required this.now,
    super.key,
  });

  final ReportPeriod period;
  final DateTime customDate;
  final DateTime now;

  @override
  State<ReportPeriodSheet> createState() => _ReportPeriodSheetState();
}

class _ReportPeriodSheetState extends State<ReportPeriodSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _year;
  late int _month;
  late bool _custom;

  @override
  void initState() {
    super.initState();
    _year = TextEditingController(text: '${widget.customDate.year}');
    _month = widget.period == ReportPeriod.customYear ? 0 : widget.customDate.month;
    _custom = widget.period == ReportPeriod.customMonth ||
        widget.period == ReportPeriod.customYear;
  }

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  void _quick(ReportPeriod period) {
    Navigator.pop(context, (period, widget.customDate));
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, (
      _month == 0 ? ReportPeriod.customYear : ReportPeriod.customMonth,
      DateTime(int.parse(_year.text), _month == 0 ? 1 : _month),
    ));
  }

  Widget _option(String title, String subtitle, bool selected, VoidCallback action) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selected: selected,
        selectedTileColor: AppColors.primaryLight,
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.5)),
        trailing: Icon(selected ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          color: selected ? AppColors.primary : AppColors.textMuted, size: 22),
        onTap: action,
      );

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Periode laporan', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _option('Bulan ini', reportMonthLabel(widget.now),
            !_custom && widget.period == ReportPeriod.currentMonth,
            () => _quick(ReportPeriod.currentMonth)),
          _option('Semua waktu', 'Seluruh inspeksi yang tersimpan',
            !_custom && widget.period == ReportPeriod.allTime,
            () => _quick(ReportPeriod.allTime)),
          _option('Pilih bulan dan tahun', 'Lihat laporan bulanan atau satu tahun penuh',
            _custom, () => setState(() => _custom = true)),
          if (_custom) ...[
            const SizedBox(height: 20),
            Form(key: _form, child: Column(children: [
              DropdownButtonFormField<int>(
                initialValue: _month,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Bulan', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('Semua bulan')),
                  for (var month = 1; month <= 12; month++)
                    DropdownMenuItem(value: month,
                      child: Text(reportMonthLabel(DateTime(2000, month)).split(' ').first)),
                ],
                onChanged: (value) => setState(() => _month = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _year,
                decoration: const InputDecoration(
                  labelText: 'Tahun', hintText: 'Contoh: 2026', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4)],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _apply(),
                validator: (value) {
                  final year = int.tryParse(value ?? '');
                  return year == null || year < 1 || year > 9999
                      ? 'Masukkan tahun antara 1 dan 9999.' : null;
                },
              ),
            ])),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _apply,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Terapkan periode'),
            ),
          ],
        ],
      ),
    ),
  );
}

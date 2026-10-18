import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class CurrentMonthLabel extends StatefulWidget {
  const CurrentMonthLabel({super.key});

  @override
  State<CurrentMonthLabel> createState() => _CurrentMonthLabelState();
}

class _CurrentMonthLabelState extends State<CurrentMonthLabel>
    with WidgetsBindingObserver {
  static const _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  DateTime _currentMonth = DateTime.now();
  Timer? _dateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextDay();
  }

  void _scheduleNextDay() {
    _dateTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dateTimer = Timer(nextDay.difference(now), _refreshMonth);
  }

  void _refreshMonth() {
    if (!mounted) return;
    final now = DateTime.now();
    if (now.month != _currentMonth.month || now.year != _currentMonth.year) {
      setState(() => _currentMonth = now);
    }
    _scheduleNextDay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMonth();
    } else {
      _dateTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/weather_service.dart';
import '../../../scan/presentation/screens/scan_screen.dart';

class HeroBannerCard extends StatefulWidget {
  const HeroBannerCard({super.key, this.weatherLoader});
  final Future<WeatherData?> Function()? weatherLoader;

  @override
  State<HeroBannerCard> createState() => HeroBannerCardState();
}

class HeroBannerCardState extends State<HeroBannerCard> {
  WeatherData? _weatherData;
  bool _isLoadingWeather = true;
  Future<void>? _loadingWeather;

  @override
  void initState() {
    super.initState();
    unawaited(refreshWeather());
  }

  Future<void> refreshWeather() => _loadingWeather ??= _loadWeather()
      .whenComplete(() => _loadingWeather = null);

  Future<void> _loadWeather() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherData = null;
    });
    WeatherData? data;
    try {
      data =
          await (widget.weatherLoader ?? WeatherService.fetchSurabayaWeather)();
    } catch (_) {
      // Show unavailable, never fabricated normal conditions.
    }
    if (mounted) {
      setState(() {
        _weatherData = data;
        _isLoadingWeather = false;
      });
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const months = [
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
    return 'Hari ini, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  void _showWeatherBottomSheet(BuildContext context) {
    if (_weatherData == null) return;
    final w = _weatherData!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.paddingOf(ctx).bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.cloudSun,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cuaca & Angin Lapangan',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Data Riil Open-Meteo API • Surabaya',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildWeatherParam(
                        icon: LucideIcons.wind,
                        label: 'Kecepatan Angin',
                        value: '${w.windSpeedKmH.toStringAsFixed(1)} km/h',
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                    Container(height: 32, width: 1, color: AppColors.border),
                    Expanded(
                      child: _buildWeatherParam(
                        icon: LucideIcons.thermometer,
                        label: 'Suhu Udara',
                        value: '${w.temperature.toStringAsFixed(1)}°C',
                        color: const Color(0xFFEA580C),
                      ),
                    ),
                    Container(height: 32, width: 1, color: AppColors.border),
                    Expanded(
                      child: _buildWeatherParam(
                        icon: LucideIcons.droplets,
                        label: 'Kelembaban',
                        value: '${w.humidity}%',
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Kondisi: ${w.condition}. Periksa kondisi lapangan sebelum melakukan inspeksi.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Diperbarui ${w.updatedAt.toLocal().day}/${w.updatedAt.toLocal().month} '
                '${w.updatedAt.toLocal().hour.toString().padLeft(2, '0')}:'
                '${w.updatedAt.toLocal().minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherParam({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final windText = _isLoadingWeather
        ? 'Memuat angin...'
        : _weatherData == null
        ? 'Cuaca belum tersedia'
        : 'Angin ${_weatherData!.windSpeedKmH.toStringAsFixed(0)} km/h';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Decorative Circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFormattedDate(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'KiWit\nSolusi preventif dalam\nmengelola kesehatan\nhutan kota',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Button Scan
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ScanScreen(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'Scan',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  LucideIcons.scan,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Open-Meteo Wind/Weather Pill
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: IntrinsicWidth(
                          child: GestureDetector(
                            onTap: () {
                              if (_isLoadingWeather) return;
                              if (_weatherData == null) {
                                unawaited(refreshWeather());
                              } else {
                                _showWeatherBottomSheet(context);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isLoadingWeather)
                                    const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      LucideIcons.wind,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      windText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

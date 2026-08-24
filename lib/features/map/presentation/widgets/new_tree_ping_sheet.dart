import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../controllers/map_controller.dart';

class NewTreePingSheet extends ConsumerStatefulWidget {
  final LatLng position;
  final String activeRayon;

  const NewTreePingSheet({
    super.key,
    required this.position,
    required this.activeRayon,
  });

  @override
  ConsumerState<NewTreePingSheet> createState() => _NewTreePingSheetState();
}

class _NewTreePingSheetState extends ConsumerState<NewTreePingSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _speciesController;
  late final TextEditingController _addressController;
  late final TextEditingController _conditionController;

  RiskLevel _selectedRisk = RiskLevel.sedang;
  bool _isSubmitting = false;
  bool _isGeocoding = true;
  String _detectedRayon = '';

  final List<String> _commonSpecies = [
    'Pohon Angsana',
    'Pohon Tabebuya Kuning',
    'Pohon Trembesi',
    'Pohon Mahoni',
    'Pohon Ketapang Kencana',
    'Pohon Flamboyan',
    'Pohon Beringin',
    'Pohon Asam Jawa',
    'Pohon Tanjung',
    'Pohon Bungur',
    'Pohon Kiara Payung',
  ];

  final Map<String, String> _speciesCodeMap = {
    'Pohon Angsana': 'ANG',
    'Pohon Tabebuya Kuning': 'TAB',
    'Pohon Trembesi': 'TRM',
    'Pohon Mahoni': 'MAH',
    'Pohon Ketapang Kencana': 'KTP',
    'Pohon Flamboyan': 'FLA',
    'Pohon Beringin': 'BRG',
    'Pohon Asam Jawa': 'ASM',
    'Pohon Tanjung': 'TNJ',
    'Pohon Bungur': 'BGR',
    'Pohon Kiara Payung': 'KPY',
  };

  final Map<String, String> _rayonCodeMap = {
    'Rayon 1 — Genteng (Surabaya Pusat)': 'GTG',
    'Rayon 2 — Rungkut (Surabaya Timur)': 'RKT',
    'Rayon 3 — Sukolilo (Surabaya Timur II)': 'SKL',
    'Rayon 4 — Sawahan (Surabaya Selatan)': 'SWH',
    'Rayon 5 — Tandes (Surabaya Barat)': 'TDS',
    'Rayon 6 — Kenjeran (Surabaya Utara)': 'KJR',
  };

  // Koordinat Titik Pusat Rayon di Surabaya
  final Map<String, LatLng> _rayonCenters = {
    'Rayon 1 — Genteng (Surabaya Pusat)': const LatLng(-7.2620, 112.7430),
    'Rayon 2 — Rungkut (Surabaya Timur)': const LatLng(-7.3200, 112.7720),
    'Rayon 3 — Sukolilo (Surabaya Timur II)': const LatLng(-7.2856, 112.7915),
    'Rayon 4 — Sawahan (Surabaya Selatan)': const LatLng(-7.2950, 112.7260),
    'Rayon 5 — Tandes (Surabaya Barat)': const LatLng(-7.2580, 112.6780),
    'Rayon 6 — Kenjeran (Surabaya Utara)': const LatLng(-7.2280, 112.7660),
  };

  @override
  void initState() {
    super.initState();
    _speciesController = TextEditingController(text: _commonSpecies[0]);
    _codeController = TextEditingController();
    _addressController = TextEditingController(text: 'Mendeteksi ruas jalan...');
    _conditionController = TextEditingController(text: 'Perlu verifikasi dahan & risiko tumbang');

    _detectedRayon = _detectRayonByCoordinates(widget.position);
    _updateSmartTreeCode();
    _reverseGeocodePosition();
  }

  void _updateSmartTreeCode({String? species, String? rayon}) {
    final targetSpecies = species ?? _speciesController.text;
    final targetRayon = rayon ?? (_detectedRayon.isNotEmpty ? _detectedRayon : widget.activeRayon);

    String rCode = 'SKL';
    for (final entry in _rayonCodeMap.entries) {
      if (targetRayon.contains(entry.key.split(' — ')[0])) {
        rCode = entry.value;
        break;
      }
    }

    final sCode = _speciesCodeMap[targetSpecies] ?? 'GEN';
    final randomSeq = 100 + (DateTime.now().millisecondsSinceEpoch % 900);
    final generatedCode = 'TR-$rCode-$sCode-$randomSeq';

    setState(() {
      _codeController.text = generatedCode;
    });
  }

  String _detectRayonByCoordinates(LatLng point) {
    const distanceCalculator = Distance();
    String closestRayon = _rayonCenters.keys.first;
    double minDistance = double.infinity;

    for (final entry in _rayonCenters.entries) {
      final dist = distanceCalculator.as(LengthUnit.Meter, point, entry.value);
      if (dist < minDistance) {
        minDistance = dist;
        closestRayon = entry.key;
      }
    }
    return closestRayon;
  }

  Future<void> _reverseGeocodePosition() async {
    setState(() => _isGeocoding = true);

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${widget.position.latitude}&lon=${widget.position.longitude}&zoom=18&addressdetails=1',
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'KiWit-AI/1.0 (Surabaya DLH Tree Monitor; contact@kiwit.app)',
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = json.decode(responseBody) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final road = address['road'] ?? address['pedestrian'] ?? address['highway'] ?? address['suburb'];
          final suburb = address['suburb'] ?? address['city_district'] ?? address['quarter'] ?? address['village'];
          final city = address['city'] ?? address['town'] ?? address['county'] ?? 'Surabaya';
          final houseNumber = address['house_number'];

          final fullAddressText = data['display_name']?.toString().toLowerCase() ?? '';
          _detectedRayon = _determineRayonFromAddressText(fullAddressText, widget.position);

          String resolvedStreet;
          if (road != null && suburb != null) {
            final numStr = houseNumber != null ? ' No. $houseNumber' : '';
            resolvedStreet = '$road$numStr, $suburb, $city';
          } else if (road != null) {
            resolvedStreet = '$road, $city';
          } else if (suburb != null) {
            resolvedStreet = 'Jl. Sekitar $suburb, $city';
          } else {
            resolvedStreet = data['name'] ?? 'Wilayah $_detectedRayon, Surabaya';
          }

          if (mounted) {
            setState(() {
              _addressController.text = resolvedStreet;
              _isGeocoding = false;
            });
            _updateSmartTreeCode(rayon: _detectedRayon);
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _detectedRayon = _detectRayonByCoordinates(widget.position);
        _addressController.text =
            'Jl. Wilayah ${_detectedRayon.split(' — ')[0]}, Surabaya (${widget.position.latitude.toStringAsFixed(4)}, ${widget.position.longitude.toStringAsFixed(4)})';
        _isGeocoding = false;
      });
      _updateSmartTreeCode(rayon: _detectedRayon);
    }
  }

  String _determineRayonFromAddressText(String fullText, LatLng pos) {
    if (fullText.contains('genteng') ||
        fullText.contains('tegalsari') ||
        fullText.contains('bubutan') ||
        fullText.contains('simokerto')) {
      return 'Rayon 1 — Genteng (Surabaya Pusat)';
    }
    if (fullText.contains('rungkut') ||
        fullText.contains('gunung anyar') ||
        fullText.contains('tenggilis')) {
      return 'Rayon 2 — Rungkut (Surabaya Timur)';
    }
    if (fullText.contains('sukolilo') ||
        fullText.contains('mulyorejo') ||
        fullText.contains('gubeng') ||
        fullText.contains('menur') ||
        fullText.contains('kertajaya') ||
        fullText.contains('its') ||
        fullText.contains('gebang')) {
      return 'Rayon 3 — Sukolilo (Surabaya Timur II)';
    }
    if (fullText.contains('sawahan') ||
        fullText.contains('wonokromo') ||
        fullText.contains('gayungan') ||
        fullText.contains('jambangan') ||
        fullText.contains('karang pilang') ||
        fullText.contains('wiyung') ||
        fullText.contains('darmo')) {
      return 'Rayon 4 — Sawahan (Surabaya Selatan)';
    }
    if (fullText.contains('tandes') ||
        fullText.contains('sukomanunggal') ||
        fullText.contains('asemrowo') ||
        fullText.contains('benowo') ||
        fullText.contains('pakal') ||
        fullText.contains('sambikerep') ||
        fullText.contains('lakarsantri')) {
      return 'Rayon 5 — Tandes (Surabaya Barat)';
    }
    if (fullText.contains('kenjeran') ||
        fullText.contains('bulak') ||
        fullText.contains('semampir') ||
        fullText.contains('pabean') ||
        fullText.contains('krembangan')) {
      return 'Rayon 6 — Kenjeran (Surabaya Utara)';
    }

    return _detectRayonByCoordinates(pos);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _speciesController.dispose();
    _addressController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final repository = ref.read(treeMapRepositoryProvider);
    final success = await repository.reportTree(
      treeCode: _codeController.text.trim(),
      speciesName: _speciesController.text.trim(),
      latitude: widget.position.latitude,
      longitude: widget.position.longitude,
      address: _addressController.text.trim(),
      rayon: _detectedRayon.isNotEmpty ? _detectedRayon : widget.activeRayon,
      healthStatus: _conditionController.text.trim(),
      riskLevel: _selectedRisk,
      heightMeters: 12.0,
      diameterCm: 45.0,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ref.invalidate(mapTreesListProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: const [
                Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Laporan ping pohon berhasil disimpan!')),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayRayon = _detectedRayon.isNotEmpty ? _detectedRayon : widget.activeRayon;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.mapPinPlus, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Ping Laporan Pohon',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Coordinates Pill with Auto-Detect Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.crosshair, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Koordinat: ${widget.position.latitude.toStringAsFixed(6)}, ${widget.position.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _isGeocoding ? Colors.amber.shade700 : AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isGeocoding ? 'Mendeteksi alamat & rayon...' : 'Alamat & Rayon Terdeteksi Otomatis',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: _isGeocoding ? Colors.amber.shade800 : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_isGeocoding)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    else
                      InkWell(
                        onTap: _reverseGeocodePosition,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(LucideIcons.refreshCw, size: 14, color: AppColors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 1. Jenis / Spesies Pohon Dropdown (Driver for Smart Tree Code)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Jenis / Spesies Pohon', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(
                    'Pilih untuk update kode',
                    style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _speciesController.text,
                decoration: _inputDeco('').copyWith(
                  prefixIcon: const Icon(LucideIcons.trees, color: AppColors.primary, size: 18),
                ),
                items: _commonSpecies.map((species) {
                  final code = _speciesCodeMap[species] ?? 'GEN';
                  return DropdownMenuItem<String>(
                    value: species,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(species, style: const TextStyle(fontSize: 13.5)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _speciesController.text = val);
                    _updateSmartTreeCode(species: val);
                  }
                },
              ),
              const SizedBox(height: 14),

              // 2. Tree Code (Auto-Generated) & Rayon (Auto-Detected)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Text('Kode Pohon', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            SizedBox(width: 4),
                            Icon(LucideIcons.sparkles, size: 12, color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _codeController,
                          decoration: _inputDeco('TR-XXX-000').copyWith(
                            suffixIcon: InkWell(
                              onTap: () => _updateSmartTreeCode(),
                              borderRadius: BorderRadius.circular(8),
                              child: const Icon(LucideIcons.refreshCw, size: 14, color: AppColors.primary),
                            ),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Kode wajib' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Text('Rayon DLH', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            SizedBox(width: 4),
                            Icon(LucideIcons.check, size: 12, color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            displayRayon.split(' — ')[0],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Address / Lokasi Jalan (Auto-Resolved with manual edit ability)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Alamat / Ruas Jalan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  if (!_isGeocoding)
                    const Text(
                      'Bisa diedit bila ada patokan',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: _inputDeco('Contoh: Jl. Raya Kertajaya Indah No. 12').copyWith(
                  prefixIcon: const Icon(LucideIcons.mapPin, color: AppColors.primary, size: 18),
                  suffixIcon: _isGeocoding
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                        )
                      : null,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Alamat wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              // 4. Tingkat Risiko ISA-TRAQ
              const Text('Tingkat Risiko Potensi Tumbang (ISA-TRAQ)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildRiskOption(RiskLevel.kritis, 'Kritis', Colors.red),
                  const SizedBox(width: 8),
                  _buildRiskOption(RiskLevel.tinggi, 'Tinggi', Colors.orange),
                  const SizedBox(width: 8),
                  _buildRiskOption(RiskLevel.sedang, 'Sedang', Colors.amber.shade700),
                  const SizedBox(width: 8),
                  _buildRiskOption(RiskLevel.rendah, 'Rendah', Colors.green),
                ],
              ),
              const SizedBox(height: 20),

              // 5. Submit Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan & Pasang Pin di Peta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskOption(RiskLevel level, String label, Color color) {
    final isSelected = _selectedRisk == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRisk = level),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }
}

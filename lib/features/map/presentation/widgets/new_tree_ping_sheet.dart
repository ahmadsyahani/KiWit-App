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

  final List<String> _commonSpecies = [
    'Pohon Trembesi',
    'Pohon Mahoni',
    'Pohon Tabebuya Kuning',
    'Pohon Angsana',
    'Pohon Flamboyan',
    'Pohon Beringin',
    'Pohon Ketapang Kencana',
  ];

  @override
  void initState() {
    super.initState();
    final randomNum = DateTime.now().millisecond;
    _codeController = TextEditingController(text: 'TR-NEW-$randomNum');
    _speciesController = TextEditingController(text: _commonSpecies[0]);
    _addressController = TextEditingController(
      text: 'Sekitar Lat: ${widget.position.latitude.toStringAsFixed(4)}, Lng: ${widget.position.longitude.toStringAsFixed(4)}',
    );
    _conditionController = TextEditingController(text: 'Perlu verifikasi dahan & risiko tumbang');
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
      rayon: widget.activeRayon,
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
                        child: const Icon(LucideIcons.mapPin, color: AppColors.primary, size: 20),
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
              const SizedBox(height: 16),

              // Coordinates Pill
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.crosshair, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Koordinat: ${widget.position.latitude.toStringAsFixed(6)}, ${widget.position.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tree Code & Rayon
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kode Pohon', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _codeController,
                          decoration: _inputDeco('TR-XXX-000'),
                          validator: (val) => val == null || val.isEmpty ? 'Kode wajib' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rayon', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          initialValue: widget.activeRayon.split(' — ')[0],
                          readOnly: true,
                          decoration: _inputDeco('').copyWith(fillColor: AppColors.border.withValues(alpha: 0.3)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Species Name Dropdown
              const Text('Jenis / Spesies Pohon', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _speciesController.text,
                decoration: _inputDeco(''),

                items: _commonSpecies.map((species) {
                  return DropdownMenuItem<String>(
                    value: species,
                    child: Text(species, style: const TextStyle(fontSize: 13.5)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _speciesController.text = val);
                },
              ),
              const SizedBox(height: 14),

              // Address / Lokasi Jalan
              const Text('Alamat / Ruas Jalan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressController,
                decoration: _inputDeco('Contoh: Jl. Raya Kertajaya Indah'),
                validator: (val) => val == null || val.isEmpty ? 'Alamat wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              // Tingkat Risiko ISA-TRAQ
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

              // Submit Button
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

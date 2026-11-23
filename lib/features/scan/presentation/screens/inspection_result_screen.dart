import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../providers/inspection_providers.dart';
import '../../../../core/services/onnx_service.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../domain/models/inspection_result_data.dart';
import '../../domain/models/inspection_location.dart';
import 'scan_screen.dart';
import 'inspection_location_editor.dart';

class InspectionResultScreen extends ConsumerStatefulWidget {
  final InspectionResultData data;

  const InspectionResultScreen({super.key, required this.data});

  @override
  ConsumerState<InspectionResultScreen> createState() =>
      _InspectionResultScreenState();
}

class _InspectionResultScreenState
    extends ConsumerState<InspectionResultScreen> {
  late InspectionResultData _data;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  final List<String> _speciesList = [
    'Pohon Mahoni',
    'Pohon Angsana',
    'Pohon Tabebuya Kuning',
    'Pohon Trembesi',
    'Pohon Ketapang Kencana',
    'Pohon Flamboyan',
    'Pohon Beringin',
    'Pohon Asam Jawa',
    'Pohon Tanjung',
    'Pohon Bungur',
    'Pohon Kiara Payung',
  ];

  @override
  void initState() {
    super.initState();
    _data = widget.data;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  RiskLevel _getRiskLevel(String status) {
    switch (status.toLowerCase()) {
      case 'rendah':
        return RiskLevel.rendah;
      case 'sedang':
        return RiskLevel.sedang;
      case 'tinggi':
        return RiskLevel.tinggi;
      case 'kritis':
        return RiskLevel.kritis;
      default:
        return RiskLevel.sedang;
    }
  }

  void _navigateToRetake(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          selectedLocation:
              validInspectionCoordinates(_data.latitude, _data.longitude)
              ? InspectionLocation(
                  latitude: _data.latitude!,
                  longitude: _data.longitude!,
                  address: _data.locationAddress,
                )
              : null,
        ),
      ),
    );
  }

  /// Update the preliminary photo priority. Optional measured DBH is recorded
  /// separately and never changes the photo-area screening category.
  void _recalculateIsaTraq({double? newDbh, EnvironmentalImpact? newImpact}) {
    final dbh = newDbh ?? _data.diameter;
    final currentImpact =
        newImpact ?? EnvironmentalImpact.fromString(_data.environmentalImpact);

    final failure = IsaTraqEvaluator.evaluateFailurePotential(
      _data.persentaseLuka,
      dbh,
    );
    final decision = IsaTraqEvaluator.evaluateMatrix(
      failurePotential: failure,
      environmentalImpact: currentImpact,
    );

    setState(() {
      _data = _data.copyWith(
        diameter: dbh,
        hasMeasuredDiameter: newDbh != null || _data.hasMeasuredDiameter,
        failurePotential: failure.label,
        environmentalImpact: currentImpact.label,
        riskStatus: _data.isOfficerAssessed
            ? _data.riskStatus
            : decision.riskStatus,
        riskAction: _data.isOfficerAssessed
            ? _data.riskAction
            : decision.actionTitle,
        modelRiskStatus: decision.riskStatus,
      );
    });
  }

  Future<void> _showEditDbhDialog() async {
    final dbhController = TextEditingController(
      text: _data.hasMeasuredDiameter ? _data.diameter.toStringAsFixed(1) : '',
    );
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Ubah Diameter Batang (DBH)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Opsional: masukkan diameter hasil pengukuran langsung. Foto tanpa skala tidak dapat menentukan diameter dalam cm.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dbhController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  suffixText: 'cm',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(dbhController.text.trim());
                if (val != null && val.isFinite && val > 0) {
                  _recalculateIsaTraq(newDbh: val);
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan pengukuran'),
            ),
          ],
        );
      },
    );
    dbhController.dispose();
  }

  Future<void> _showEditSpeciesSheet() async {
    final customController = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Jenis Pohon',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sesuaikan jenis pohon yang diinspeksi oleh petugas DLH.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _speciesList.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sp = _speciesList[index];
                    final isSelected = sp == _data.treeSpecies;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      leading: Icon(
                        LucideIcons.trees,
                        color: isSelected ? AppColors.primary : Colors.grey,
                        size: 20,
                      ),
                      title: Text(
                        sp,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              LucideIcons.check,
                              color: AppColors.primary,
                              size: 18,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _data = _data.copyWith(treeSpecies: sp);
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customController,
                decoration: InputDecoration(
                  hintText: 'Atau ketik nama pohon lainnya...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(LucideIcons.plus, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(LucideIcons.arrowRight, size: 18),
                    onPressed: () {
                      final val = customController.text.trim();
                      if (val.isNotEmpty) {
                        setState(() {
                          _data = _data.copyWith(treeSpecies: val);
                        });
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    setState(() {
                      _data = _data.copyWith(treeSpecies: val.trim());
                    });
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditLocationSheet() async {
    final edit = await showModalBottomSheet<InspectionLocationEdit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => InspectionLocationEditor(
        initialAddress: _data.locationAddress,
        initialLocation:
            validInspectionCoordinates(_data.latitude, _data.longitude)
            ? InspectionLocation(
                latitude: _data.latitude!,
                longitude: _data.longitude!,
                address: _data.locationAddress,
              )
            : null,
      ),
    );
    if (!mounted || edit == null) return;
    setState(
      () => _data = _data.copyWith(
        locationAddress: edit.address,
        latitude: edit.point?.latitude,
        longitude: edit.point?.longitude,
      ),
    );
  }

  Future<void> _showEditIdDialog() async {
    final idController = TextEditingController(text: _data.inspectionId);
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Ubah ID Pohon',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: idController,
            decoration: InputDecoration(
              prefixText: 'ID #',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = idController.text.trim();
                if (val.isNotEmpty) {
                  setState(() {
                    _data = _data.copyWith(inspectionId: val);
                  });
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRiskConditionPicker() async {
    final risks = ['Rendah', 'Sedang', 'Tinggi', 'Kritis'];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status & Risiko Pohon',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sesuaikan tingkat resiko pohon berdasarkan observasi visual petugas:',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                ...risks.map((r) {
                  final isSelected =
                      r.toLowerCase() == _data.riskStatus.toLowerCase();
                  return ListTile(
                    title: Text(
                      r,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            LucideIcons.check,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        final model = IsaTraqEvaluator.evaluateMatrix(
                          failurePotential: FailurePotential.fromString(
                            _data.failurePotential,
                          ),
                          environmentalImpact: EnvironmentalImpact.fromString(
                            _data.environmentalImpact,
                          ),
                        );
                        final officer = IsaTraqEvaluator.decisionForOfficerRisk(
                          r,
                        );
                        _data = _data.copyWith(
                          riskStatus: officer.riskStatus,
                          riskAction: officer.actionTitle,
                          isOfficerAssessed: true,
                          modelRiskStatus: model.riskStatus,
                        );
                      });
                      Navigator.pop(ctx);
                    },
                  );
                }),
                if (_data.isOfficerAssessed)
                  TextButton(
                    onPressed: () {
                      final model = IsaTraqEvaluator.evaluateMatrix(
                        failurePotential: FailurePotential.fromString(
                          _data.failurePotential,
                        ),
                        environmentalImpact: EnvironmentalImpact.fromString(
                          _data.environmentalImpact,
                        ),
                      );
                      setState(
                        () => _data = _data.copyWith(
                          riskStatus: model.riskStatus,
                          riskAction: model.actionTitle,
                          modelRiskStatus: model.riskStatus,
                          isOfficerAssessed: false,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('Gunakan hasil model'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveInspectionResult() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final profile = ref.read(userProfileProvider).valueOrNull;
      final user = ref.read(currentUserProvider);
      await ref
          .read(inspectionControllerProvider.notifier)
          .save(
            data: _data,
            notes: _notesController.text.trim(),
            inspectorName:
                profile?.fullName ??
                user?.userMetadata?['full_name'] as String? ??
                '',
            rayon:
                profile?.rayon ?? user?.userMetadata?['rayon'] as String? ?? '',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          content: Text(
            user == null
                ? 'Inspeksi tersimpan di perangkat. Masuk ke akun untuk sinkronisasi.'
                : 'Inspeksi tersimpan di perangkat. Sinkronisasi cloud berjalan otomatis.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Inspeksi belum berhasil disimpan. Coba lagi.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildUnassessedResult(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Hasil Inspeksi')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(
              File(_data.imagePath),
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => const SizedBox(
                height: 160,
                child: Icon(Icons.image_not_supported_outlined, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: RiskBadge(level: RiskLevel.belumDinilai),
          ),
          const SizedBox(height: 14),
          const Text(
            'Kondisi belum dapat dinilai',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Foto berhasil diambil. Model belum menghasilkan penilaian kondisi yang cukup. Simpan foto sebagai catatan inspeksi dan periksa pohon secara manual.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Lokasi inspeksi'),
            subtitle: Text(_data.locationAddress),
            trailing: TextButton(
              onPressed: _isSaving ? null : _showEditLocationSheet,
              child: const Text('Ubah'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            enabled: !_isSaving,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Catatan lapangan',
              hintText: 'Tuliskan kondisi yang terlihat (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveInspectionResult,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Menyimpan...' : 'Simpan inspeksi'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _navigateToRetake(context),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Foto ulang'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!_data.hasAssessment) return _buildUnassessedResult(context);
    final impact = EnvironmentalImpact.fromString(_data.environmentalImpact);
    final failure = FailurePotential.fromString(_data.failurePotential);
    final modelDecision = IsaTraqEvaluator.evaluateMatrix(
      failurePotential: failure,
      environmentalImpact: impact,
    );
    final decision = _data.isOfficerAssessed
        ? IsaTraqEvaluator.decisionForOfficerRisk(_data.riskStatus)
        : modelDecision;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            LucideIcons.chevronLeft,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hasil Inspeksi',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Image with dynamic info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: const BoxDecoration(color: AppColors.textMuted),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(
                          File(_data.imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) => const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.white70,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badges (ID & Risk)
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                InkWell(
                                  onTap: _showEditIdDialog,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'ID #${_data.inspectionId.length > 12 ? _data.inspectionId.substring(0, 8).toUpperCase() : _data.inspectionId}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          LucideIcons.pencil,
                                          size: 10,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: _showRiskConditionPicker,
                                  borderRadius: BorderRadius.circular(12),
                                  child: RiskBadge(
                                    level: _getRiskLevel(_data.riskStatus),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Dynamic Species Title (Interactive)
                            InkWell(
                              onTap: _showEditSpeciesSheet,
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _data.treeSpecies,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      LucideIcons.pencil,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Dynamic Location (Interactive)
                            InkWell(
                              onTap: _showEditLocationSheet,
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.mapPin,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _data.locationAddress,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    color: Colors.white60,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validInspectionCoordinates(
                                  _data.latitude,
                                  _data.longitude,
                                )
                                ? 'Lokasi inspeksi'
                                : 'Lokasi belum tersedia',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      validInspectionCoordinates(
                            _data.latitude,
                            _data.longitude,
                          )
                          ? _data.locationAddress
                          : 'Foto sudah dianalisis. Lengkapi lokasi agar inspeksi muncul di peta.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _showEditLocationSheet,
                      child: Text(
                        validInspectionCoordinates(
                              _data.latitude,
                              _data.longitude,
                            )
                            ? 'Ubah lokasi'
                            : 'Lengkapi lokasi',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // AI Pathology Diagnosis Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.sparkles,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hasil analisis foto',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _data.detectedCondition,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // =========================================================
            // MATRIKS RISIKO ISA TRAQ SECTION (requirements.md)
            // =========================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: decision.statusColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: decision.statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            LucideIcons.shieldAlert,
                            color: decision.statusColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _data.isOfficerAssessed
                                    ? 'Penilaian petugas'
                                    : 'Prioritas pemeriksaan awal',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _data.isOfficerAssessed
                                    ? 'Skrining foto: ${modelDecision.riskStatus}. Risiko akhir ditetapkan petugas.'
                                    : 'Skrining foto, bukan penilaian keselamatan pohon',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Tahap 3: Vonis Laporan Banner (Warna Sesuai Spesifikasi)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: decision.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: decision.statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            decision.riskLevel == RiskLevel.kritis
                                ? LucideIcons.alertOctagon
                                : decision.riskLevel == RiskLevel.tinggi
                                ? LucideIcons.alertTriangle
                                : decision.riskLevel == RiskLevel.sedang
                                ? LucideIcons.alertCircle
                                : LucideIcons.checkCircle2,
                            color: decision.statusColor,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Saran tindak lanjut:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  decision.displayText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: decision.statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Variabel A: Potensi Kegagalan (Otomatis dari AI & DBH)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Pola kerusakan pada foto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: decision.statusColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_data.persentaseLuka.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: decision.statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${failure.description}. Persentase dihitung dari area kulit yang dikenali, bukan kedalaman rongga atau kekuatan batang.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Variabel B: Dampak Lingkungan (Input Manual Pengguna dari UI)
                    const Text(
                      'Variabel B: Dampak Lingkungan (Target Risiko)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih kepadatan fasilitas/orang di sekitar pohon:',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Radio / Segmented Selector untuk Dampak Lingkungan
                    Row(
                      children: EnvironmentalImpact.values.map((imp) {
                        final isSelected = imp == impact;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _recalculateIsaTraq(newImpact: imp),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    imp.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    imp == EnvironmentalImpact.low
                                        ? 'Lahan kosong'
                                        : imp == EnvironmentalImpact.medium
                                        ? 'Taman / Sepi'
                                        : 'Jalan raya',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSelected
                                          ? Colors.white70
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Kesehatan Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Indeks tampilan kulit pada foto',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(
                          '${_data.healthScore}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6.0),
                          child: Text(
                            ' / 100',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text(
                            _data.healthScore > 75
                                ? 'Pola kerusakan sedikit'
                                : _data.healthScore > 50
                                ? 'Pola kerusakan sedang'
                                : 'Pola kerusakan dominan',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _data.healthScore / 100.0,
                        minHeight: 8,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          decision.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Metrics Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Persentase Luka (AI)',
                      '${_data.persentaseLuka.toStringAsFixed(1)}%',
                      subtitle: _data.defectPixelCount > 0
                          ? '${_data.defectPixelCount} px cacat'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      'Sudut Kemiringan',
                      _data.hasMeasuredInclination
                          ? '${_data.sudutKemiringan.toStringAsFixed(1)}°'
                          : 'Belum diukur',
                      subtitle: 'Tidak ditentukan dari foto',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _showEditDbhDialog,
                      child: _buildMetricCard(
                        'Diameter Batang (DBH)',
                        _data.hasMeasuredDiameter
                            ? '${_data.diameter.toStringAsFixed(1)} cm'
                            : 'Belum diukur',
                        isEditable: true,
                        subtitle: 'Pengukuran langsung (opsional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      'Jamur Pelapuk',
                      _data.hasPathologyAssessment
                          ? (_data.isJamurPelapuk
                                ? 'Tercatat positif'
                                : 'Tercatat negatif')
                          : 'Tidak dinilai',
                      subtitle: 'Model mengenali pola kulit',
                      valueColor: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Notes Textfield
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 100,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'Tambahkan catatan observasi lapangan...',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToRetake(context),
                  icon: const Icon(LucideIcons.camera, size: 18),
                  label: const Text(
                    'Foto Ulang',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveInspectionResult,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan Hasil',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value, {
    Color? valueColor,
    bool isEditable = false,
    String? subtitle,
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
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isEditable)
                const Icon(
                  LucideIcons.pencil,
                  size: 11,
                  color: AppColors.primary,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

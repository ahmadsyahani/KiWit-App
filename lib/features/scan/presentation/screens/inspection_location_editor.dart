import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/services/scan_location_service.dart';
import '../../domain/models/inspection_location.dart';
import 'inspection_location_picker.dart';

class InspectionLocationEdit {
  const InspectionLocationEdit({required this.address, this.point});
  final String address;
  final InspectionLocation? point;
}

class InspectionLocationEditor extends StatefulWidget {
  const InspectionLocationEditor({
    this.initialLocation, this.initialAddress = '', this.locationLoader, super.key,
  });
  final InspectionLocation? initialLocation;
  final String initialAddress;
  final Future<InspectionLocation?> Function()? locationLoader;

  @override
  State<InspectionLocationEditor> createState() => _InspectionLocationEditorState();
}

class _InspectionLocationEditorState extends State<InspectionLocationEditor> {
  late final TextEditingController _address;
  InspectionLocation? _point;
  bool _locating = false;
  String? _issue;

  @override
  void initState() {
    super.initState();
    _point = widget.initialLocation?.isValid == true ? widget.initialLocation : null;
    final address = widget.initialAddress;
    _address = TextEditingController(text:
      address.startsWith('Lokasi belum') ? '' : address);
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _gps() async {
    setState(() { _locating = true; _issue = null; });
    try {
      final point = await (widget.locationLoader ?? resolveScanLocation)()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (point == null || !point.isValid) {
        setState(() => _issue =
          'GPS belum tersedia. Aktifkan lokasi dan izinkan akses, atau pilih titik di peta.');
      } else {
        setState(() {
          _point = point;
          _address.text = point.label;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _issue =
          'Lokasi belum berhasil didapat. Coba GPS lagi atau pilih titik di peta.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pick() async {
    FocusScope.of(context).unfocus();
    final point = await Navigator.push<InspectionLocation>(context, MaterialPageRoute(
      builder: (_) => InspectionLocationPicker(initialLocation: _point)));
    if (!mounted || point == null) return;
    setState(() {
      _point = point;
      _address.text = point.label;
      _issue = null;
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 8, 24,
        MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_point == null ? 'Lengkapi lokasi' : 'Ubah lokasi',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Gunakan GPS atau koreksi titik pohon di peta.',
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        TextField(
          controller: _address, enabled: !_locating, maxLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Alamat / patokan (opsional)',
            hintText: 'Contoh: sisi utara taman',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Text(_point != null
          ? 'Koordinat: ${_point!.latitude.toStringAsFixed(6)}, ${_point!.longitude.toStringAsFixed(6)}'
          : 'Titik belum tercatat. Alamat saja belum bisa ditampilkan sebagai penanda peta.',
          style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
        if (_issue != null) ...[
          const SizedBox(height: 12),
          Text(_issue!, style: const TextStyle(color: AppColors.riskHighText, height: 1.5)),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _locating ? null : _gps,
          icon: _locating
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location_rounded, size: 18),
          label: Text(_locating ? 'Mencari lokasi…' : 'Coba GPS lagi'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _locating ? null : _pick,
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Pilih di peta'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _locating || (_point == null && _address.text.trim().isEmpty)
            ? null : () => Navigator.pop(context, InspectionLocationEdit(
                point: _point,
                address: _address.text.trim().isNotEmpty
                  ? _address.text.trim() : _point!.label)),
          child: const Text('Simpan lokasi'),
        ),
      ]),
    ),
  );
}

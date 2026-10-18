import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/services/scan_analyzer.dart';
import '../../data/services/scan_camera.dart';
import '../../data/services/scan_location_service.dart';
import '../../domain/models/inspection_location.dart';
import '../controllers/scan_controller.dart';
import 'inspection_result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({this.selectedLocation, this.controller, super.key});
  final InspectionLocation? selectedLocation;
  /// Optional adapter-backed controller for host integration and camera-free tests.
  final ScanController? controller;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final ScanController _scan;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scan = widget.controller ?? ScanController(
      camera: DeviceScanCamera(),
      analyzer: OnnxPhotoAnalyzer(),
      locationLoader: resolveScanLocation,
      selectedLocation: widget.selectedLocation,
    );
    unawaited(_scan.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _scan.setActive(state == AppLifecycleState.resumed);
  }

  Future<void> _capture() async {
    final result = await _scan.capture();
    if (!mounted || result == null || _navigating) return;
    _navigating = true;
    // Release the native preview while the result route is replacing this page.
    _scan.setActive(false);
    Navigator.pushReplacement(context, MaterialPageRoute<void>(
      builder: (_) => InspectionResultScreen(data: result),
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scan.dispose();
    super.dispose();
  }

  String get _title => switch (_scan.stage) {
    ScanStage.loading => 'Menyiapkan kamera…',
    ScanStage.capturing => 'Mengambil foto…',
    ScanStage.analyzing => 'Menganalisis foto…',
    ScanStage.locating => 'Menyiapkan lokasi foto…',
    ScanStage.paused => 'Kamera dijeda',
    ScanStage.error => 'Kamera belum siap',
    ScanStage.completed => 'Foto selesai dianalisis',
    ScanStage.ready => 'Arahkan ke batang pohon',
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scan,
    builder: (context, _) => Scaffold(
      backgroundColor: const Color(0xFF15241F),
      body: Stack(fit: StackFit.expand, children: [
        if (_scan.cameraReady) _scan.camera.preview(),
        const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x99000000), Colors.transparent, Color(0xCC000000)],
            stops: [0, .35, 1]),
        ))),
        SafeArea(child: LayoutBuilder(builder: (context, constraints) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
            child: Row(children: [
              IconButton.filledTonal(
                tooltip: 'Tutup kamera',
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(backgroundColor: Colors.black38,
                    foregroundColor: Colors.white, minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.close_rounded),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Inspeksi pohon',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
            ]),
          ),
          Expanded(child: _scan.stage == ScanStage.error
            ? _errorView()
            : LayoutBuilder(builder: (context, space) => Center(
                child: SizedBox(
                  width: math.min(space.maxWidth * .68, 280),
                  height: math.min(space.maxHeight * .82, 350),
                  child: CustomPaint(painter: ScannerCornersPainter()),
                ),
              )),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: SingleChildScrollView(child: Column(children: [
                Text(_title, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(_scan.notice ?? 'Isi bingkai dengan batang pohon. Pastikan foto fokus dan cukup terang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _scan.notice == null ? Colors.white70 : const Color(0xFFFFDFAC),
                      fontSize: 13, height: 1.5)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white60, size: 15),
                  const SizedBox(width: 4),
                  Flexible(child: Text(
                    _scan.location != null
                      ? 'Lokasi inspeksi tercatat'
                      : (_scan.locationPending ? 'Mencari lokasi otomatis…' : 'Lokasi bisa dilengkapi nanti'),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 12))),
                ]),
                ]))),
                const SizedBox(height: 16),
                SizedBox(width: 80, height: 80, child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: _scan.canCapture ? Colors.white : Colors.white38, width: 3)),
                  child: Padding(padding: const EdgeInsets.all(5),
                    child: IconButton(
                      tooltip: 'Ambil foto',
                      onPressed: _scan.canCapture ? _capture : null,
                      style: IconButton.styleFrom(
                        backgroundColor: _scan.canCapture ? AppColors.primary : Colors.white12,
                        foregroundColor: Colors.white, disabledForegroundColor: Colors.white38),
                      icon: _scan.busy || _scan.stage == ScanStage.loading
                        ? const SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.camera_alt_outlined, size: 30),
                    ),
                  ),
                )),
              ]),
            ),
          ),
        ]))),
      ]),
    ),
  );

  Widget _errorView() => Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 40),
      const SizedBox(height: 14),
      const Text('Akses kamera diperlukan', textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => unawaited(_scan.start()),
        icon: const Icon(Icons.refresh_rounded), label: const Text('Coba lagi')),
      if (_scan.settingsRequired) TextButton(
        onPressed: () async { await openAppSettings(); },
        child: const Text('Buka pengaturan', style: TextStyle(color: Colors.white))),
    ]),
  ));
}

class ScannerCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .9)
      ..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final length = math.min(30.0, math.min(size.width, size.height) / 3);
    final path = Path()
      ..moveTo(0, length)..lineTo(0, 12)..quadraticBezierTo(0, 0, 12, 0)..lineTo(length, 0)
      ..moveTo(size.width - length, 0)..lineTo(size.width - 12, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 12)..lineTo(size.width, length)
      ..moveTo(size.width, size.height - length)..lineTo(size.width, size.height - 12)
      ..quadraticBezierTo(size.width, size.height, size.width - 12, size.height)
      ..lineTo(size.width - length, size.height)
      ..moveTo(length, size.height)..lineTo(12, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 12)..lineTo(0, size.height - length);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

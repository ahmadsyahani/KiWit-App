import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanCameraFailure implements Exception {
  const ScanCameraFailure(this.message, {this.settingsRequired = false});
  final String message;
  final bool settingsRequired;
}

abstract interface class ScanCamera {
  Future<void> open();
  Future<String> capture();
  Future<void> close();
  Widget preview();
}

class DeviceScanCamera implements ScanCamera {
  CameraController? _controller;

  @override
  Future<void> open() async {
    await close();
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      throw ScanCameraFailure(
        'Izinkan akses kamera untuk mengambil foto batang pohon.',
        settingsRequired: permission.isPermanentlyDenied || permission.isRestricted,
      );
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw const ScanCameraFailure('Kamera tidak ditemukan pada perangkat ini.');
    }
    final camera = cameras.firstWhere(
      (item) => item.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);
    try {
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } on CameraException {
        // Some devices do not expose a flash unit.
      }
      _controller = controller;
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  @override
  Future<String> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      throw const ScanCameraFailure('Kamera belum siap. Coba lagi sebentar.');
    }
    return (await controller.takePicture()).path;
  }

  @override
  Future<void> close() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  @override
  Widget preview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(builder: (context, constraints) {
      final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
      final ratio = portrait ? 1 / controller.value.aspectRatio : controller.value.aspectRatio;
      return ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxWidth / ratio,
              child: CameraPreview(controller),
            ),
          ),
        ),
      );
    });
  }
}

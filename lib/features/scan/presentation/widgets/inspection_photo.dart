import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/saved_inspection.dart';
import '../providers/inspection_providers.dart';

class InspectionPhoto extends StatelessWidget {
  const InspectionPhoto({
    required this.record,
    required this.width,
    required this.height,
    super.key,
  });

  final SavedInspection record;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: record.data.imagePath.isEmpty
        ? _RemoteInspectionPhoto(record: record)
        : Image.file(
            File(record.data.imagePath),
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => _RemoteInspectionPhoto(record: record),
          ),
  );
}

class _RemoteInspectionPhoto extends ConsumerWidget {
  const _RemoteInspectionPhoto({required this.record});
  final SavedInspection record;

  Widget _placeholder() => const ColoredBox(
    color: AppColors.border,
    child: Center(child: Icon(Icons.park, color: AppColors.textMuted, size: 32)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = record.photoStoragePath;
    if (path == null) return _placeholder();
    return ref.watch(inspectionPhotoUrlProvider(path)).when(
      data: (url) => url == null
          ? _placeholder()
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => _placeholder(),
            ),
      loading: _placeholder,
      error: (_, stackTrace) => _placeholder(),
    );
  }
}

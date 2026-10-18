import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/inspection_location.dart';

/// Optional correction after taking a photo. It never starts another scan.
class InspectionLocationPicker extends StatefulWidget {
  const InspectionLocationPicker({this.initialLocation, this.tileProvider, super.key});
  final InspectionLocation? initialLocation;
  final TileProvider? tileProvider;

  @override
  State<InspectionLocationPicker> createState() => _InspectionLocationPickerState();
}

class _InspectionLocationPickerState extends State<InspectionLocationPicker> {
  final _map = MapController();
  late LatLng _point;
  late bool _confirmedPoint;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLocation;
    _confirmedPoint = initial?.isValid == true;
    _point = _confirmedPoint
      ? LatLng(initial!.latitude, initial.longitude)
      : const LatLng(-7.2856, 112.7915);
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ubah lokasi pohon')),
    body: FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _point, initialZoom: 18, minZoom: 3, maxZoom: 19,
        onMapReady: () => setState(() => _ready = true),
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) {
            setState(() {
              _point = camera.center;
              _confirmedPoint = true;
            });
          }
        },
        onTap: (_, point) {
          _map.move(point, _map.camera.zoom);
          setState(() {
            _point = point;
            _confirmedPoint = true;
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.kiwit.app',
          tileProvider: widget.tileProvider,
        ),
        IgnorePointer(child: Center(
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2)),
            child: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 30)))),
        const Align(alignment: Alignment.bottomRight,
          child: ColoredBox(color: Colors.white,
            child: Padding(padding: EdgeInsets.all(4),
              child: Text('© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: Colors.black87))))),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Geser atau ketuk peta ke lokasi pohon.',
              style: TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 6),
            Text(_confirmedPoint
              ? '${_point.latitude.toStringAsFixed(6)}, ${_point.longitude.toStringAsFixed(6)}'
              : 'Tentukan titik pohon untuk menggunakan lokasi ini.',
              style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _ready && _confirmedPoint ? () => Navigator.pop(context,
                InspectionLocation(latitude: _point.latitude, longitude: _point.longitude)) : null,
              child: const Text('Gunakan lokasi ini'),
            ),
          ],
        ),
      ),
    ),
  );
}

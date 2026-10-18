import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../../scan/data/models/saved_inspection.dart';
import '../../../scan/domain/models/inspection_location.dart';
import '../../../scan/presentation/providers/inspection_providers.dart';
import '../../../scan/presentation/screens/saved_inspection_detail_screen.dart';
import '../../../scan/presentation/screens/scan_screen.dart';
import '../../data/models/tree_map_model.dart';
import '../../data/services/map_location_service.dart';
import '../controllers/map_controller.dart';
import '../widgets/map_data_status_card.dart';
import '../widgets/map_inspection_card.dart';
import '../widgets/map_layer_sheet.dart';
import '../widgets/map_search_panel.dart';
import '../widgets/user_location_marker.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({this.tileProvider, this.locationLoader, super.key});

  final TileProvider? tileProvider;
  final Future<LatLng> Function()? locationLoader;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with WidgetsBindingObserver {
  final _mapController = MapController();
  final _mapSurfaceKey = GlobalKey();
  final _mapWindowKey = GlobalKey();
  final _searchController = TextEditingController();
  bool _mapReady = false;
  bool _hasCentered = false;
  bool _isLocating = false;
  bool _initialLocationPending = true;
  int _viewRevision = 0;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (ref.read(inspectionControllerProvider).hasError) {
      ref.invalidate(inspectionControllerProvider);
      return;
    }
    try {
      await ref.read(inspectionControllerProvider.notifier).refresh();
    } catch (_) {
      // The shared inspection provider exposes the error and keeps cached data.
    }
  }

  Future<void> _locateUser({bool initial = false}) async {
    if (_isLocating || !_mapReady) return;
    final revision = _viewRevision;
    setState(() => _isLocating = true);
    try {
      final point = await (widget.locationLoader ?? resolveMapLocation)();
      if (!mounted) return;
      if (!validInspectionCoordinates(point.latitude, point.longitude)) {
        throw const FormatException('Lokasi belum valid. Coba Lokasi saya lagi.');
      }
      setState(() => _userLocation = point);
      // A late GPS fix must never undo a gesture or a deliberate map action.
      if (revision == _viewRevision && (!initial || !_hasCentered)) {
        _focusPoints([point]);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is FormatException
              ? error.message
              : 'Lokasi belum tersedia. Tekan Lokasi saya untuk mencoba lagi.'),
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
        if (initial) {
          _initialLocationPending = false;
          _scheduleInitialCenter();
        }
      }
    }
  }

  void _scheduleInitialCenter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady || _initialLocationPending || _hasCentered) return;
      final point = _userLocation;
      if (point != null) {
        _focusPoints([point]);
      } else {
        _fitMarkers();
      }
    });
  }

  Rect? _visibleMapRect() {
    final surface = _mapSurfaceKey.currentContext?.findRenderObject();
    final window = _mapWindowKey.currentContext?.findRenderObject();
    if (surface is! RenderBox || window is! RenderBox ||
        !surface.hasSize || !window.hasSize) {
      return null;
    }
    final origin = surface.globalToLocal(window.localToGlobal(Offset.zero));
    return origin & window.size;
  }

  void _focusPoints(List<LatLng> points) {
    if (!mounted || !_mapReady || points.isEmpty) return;
    _viewRevision++;
    _hasCentered = true;
    final rect = _visibleMapRect();
    final surface = _mapSurfaceKey.currentContext?.findRenderObject();
    final padding = rect != null && surface is RenderBox
        ? EdgeInsets.fromLTRB(
            rect.left + 24, rect.top + 16,
            (surface.size.width - rect.right) + 72,
            (surface.size.height - rect.bottom) + 16,
          )
        : const EdgeInsets.all(80);
    _mapController.fitCamera(CameraFit.coordinates(
      coordinates: points, maxZoom: 17, padding: padding,
    ));
  }

  void _fitMarkers() {
    if (!_mapReady) return;
    final markers = ref.read(mapTreesListProvider).valueOrNull ?? [];
    _mapController.rotate(0);
    _focusPoints(markers.map((m) => LatLng(m.latitude, m.longitude)).toList());
  }

  void _fitAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitMarkers();
    });
  }

  void _select(TreeMapModel marker) {
    ref.read(selectedTreeMapIdProvider.notifier).state = marker.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusPoints([LatLng(marker.latitude, marker.longitude)]);
    });
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(mapSearchQueryProvider.notifier).state = '';
    ref.read(selectedRayonFilterProvider.notifier).state = 'Semua Rayon';
    ref.read(selectedRiskFilterProvider.notifier).state = null;
    _fitAfterFrame();
  }

  void _startInspection() {
    FocusScope.of(context).unfocus();
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => const ScanScreen(),
    ));
  }

  void _openDetail(SavedInspection record) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SavedInspectionDetailScreen(record: record),
    ));
  }

  void _showWithoutLocation() {
    final records = ref.read(mapInspectionDataProvider).valueOrNull?.withoutLocation ?? [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inspeksi tanpa koordinat', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                    )),
                    SizedBox(height: 8),
                    Text('Data tetap tersimpan. Untuk inspeksi berikutnya, aktifkan GPS '
                        'atau mulai scan dari titik pilihan di peta.',
                      style: TextStyle(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
              Expanded(child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (_, index) {
                  final record = records[index];
                  return ListTile(
                    title: Text(record.data.treeSpecies),
                    subtitle: Text('${record.data.inspectionId} · '
                        '${formatInspectionDate(record.data.scanTimestamp)}'),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openDetail(record);
                    },
                  );
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showInspectionList() {
    final data = ref.read(mapInspectionDataProvider).valueOrNull;
    if (data == null) return;
    final records = [
      ...data.markers.map((marker) => marker.record),
      ...data.withoutLocation,
    ];
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      useSafeArea: true, showDragHandle: true, backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text('Daftar inspeksi', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                )),
              ),
              Expanded(child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: records.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 60),
                itemBuilder: (_, index) {
                  final record = records[index];
                  final located = validInspectionCoordinates(
                    record.data.latitude, record.data.longitude,
                  );
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(located ? LucideIcons.trees : LucideIcons.mapPinOff,
                        color: AppColors.primary, size: 20),
                    ),
                    title: Text(record.data.treeSpecies,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(located
                        ? '${mapRiskLabel(record.riskLevel)} · ${formatInspectionDate(record.data.scanTimestamp)}'
                        : 'Koordinat belum tersedia'),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      if (located) {
                        _select(TreeMapModel(record));
                      } else {
                        _openDetail(record);
                      }
                    },
                  );
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilters() {
    var rayon = ref.read(selectedRayonFilterProvider);
    var risk = ref.read(selectedRiskFilterProvider);
    final options = ['Semua Rayon', ...ref.read(mapRayonOptionsProvider)];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Text('Filter inspeksi', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700,
                  )),
                ),
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tingkat risiko', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [null, ...RiskLevel.values.reversed].map((level) =>
                          ChoiceChip(
                            label: Text(_riskLabel(level)),
                            selected: risk == level,
                            onSelected: (_) => update(() => risk = level),
                          ),
                        ).toList(),
                      ),
                      const SizedBox(height: 22),
                      const Text('Rayon pada data inspeksi', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...options.map((value) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(value.isEmpty ? 'Belum diisi' : value),
                        trailing: Icon(rayon == value ? LucideIcons.circleCheck : LucideIcons.circle,
                          color: rayon == value ? AppColors.primary : AppColors.textMuted, size: 21),
                        onTap: () => update(() => rayon = value),
                      )),
                    ],
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: () {
                      ref.read(selectedRayonFilterProvider.notifier).state = rayon;
                      ref.read(selectedRiskFilterProvider.notifier).state = risk;
                      Navigator.pop(sheetContext);
                      _fitAfterFrame();
                    },
                    child: const Text('Terapkan filter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(mapInspectionDataProvider);
    final markers = data.valueOrNull?.markers ?? <TreeMapModel>[];
    final feed = ref.watch(inspectionControllerProvider);
    final selected = ref.watch(selectedTreeMapItemProvider);
    final layer = ref.watch(selectedMapLayerProvider);
    final showMarkers = ref.watch(showTreeMarkersProvider);
    final highlightRisk = ref.watch(highlightHighRiskProvider);
    final risk = ref.watch(selectedRiskFilterProvider);
    final rayon = ref.watch(selectedRayonFilterProvider);
    final query = ref.watch(mapSearchQueryProvider);
    final guest = ref.watch(currentUserIdProvider) == null;
    final hasFilter = risk != null || rayon != 'Semua Rayon' || query.trim().isNotEmpty;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    ref.listen(currentUserIdProvider, (_, _) {
      _searchController.clear();
      _hasCentered = false;
      _scheduleInitialCenter();
    });
    ref.listen(mapTreesListProvider, (_, next) {
      if (!_hasCentered && next.valueOrNull?.isNotEmpty == true) {
        _scheduleInitialCenter();
      }
    });

    final index = selected == null ? -1 : markers.indexWhere((m) => m.id == selected.id);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            key: _mapSurfaceKey,
            mapController: _mapController,
            options: MapOptions(
              // A neutral overview while waiting, never a fabricated GPS fix.
              initialCenter: const LatLng(-2.5, 118),
              initialZoom: 4,
              minZoom: 3,
              maxZoom: 19,
              onMapReady: () {
                _mapReady = true;
                unawaited(_locateUser(initial: true));
              },
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) {
                  _hasCentered = true;
                  _viewRevision++;
                }
              },
              onTap: (_, _) {
                FocusScope.of(context).unfocus();
                ref.read(selectedTreeMapIdProvider.notifier).state = null;
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(layer),
                urlTemplate: layer.urlTemplate,
                tileProvider: widget.tileProvider,
                userAgentPackageName: 'com.pens.kiwit.kiwit_app',
              ),
              if (showMarkers)
                MarkerLayer(markers: markers.map((marker) {
                  final active = marker.id == selected?.id;
                  final color = _riskColor(marker.riskLevel);
                  final highlighted = highlightRisk &&
                      (marker.riskLevel == RiskLevel.tinggi || marker.riskLevel == RiskLevel.kritis);
                  return Marker(
                    point: LatLng(marker.latitude, marker.longitude),
                    width: 48, height: 48,
                    rotate: true,
                    child: Semantics(
                      button: true,
                      label: '${marker.speciesName}, ${_riskLabel(marker.riskLevel)}, '
                          'inspeksi ${marker.treeCode}',
                      child: GestureDetector(
                        onTap: () => _select(marker),
                        child: Center(child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: active ? 44 : 34, height: active ? 44 : 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: active ? 3 : 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 5),
                              if (highlighted)
                                BoxShadow(color: color.withValues(alpha: 0.3), spreadRadius: 7, blurRadius: 4),
                            ],
                          ),
                          child: Icon(
                            marker.riskLevel == RiskLevel.kritis
                                ? LucideIcons.alertTriangle : LucideIcons.trees,
                            color: Colors.white, size: active ? 22 : 17,
                          ),
                        )),
                      ),
                    ),
                  );
                }).toList()),
              if (_userLocation != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _userLocation!, width: 70, height: 70,
                    child: UserLocationPingMarker(position: _userLocation!),
                  ),
                ]),
            ],
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, _) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Center(child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: MapSearchPanel(
                            controller: _searchController,
                            hasFilter: hasFilter,
                            onChanged: (value) => ref.read(mapSearchQueryProvider.notifier).state = value,
                            onSubmitted: () {
                              FocusScope.of(context).unfocus();
                              _fitAfterFrame();
                            },
                            onClear: () {
                              _searchController.clear();
                              ref.read(mapSearchQueryProvider.notifier).state = '';
                            },
                            onFilter: _showFilters,
                          ),
                      )),
                    ),
                    Expanded(child: LayoutBuilder(
                      builder: (context, mapSpace) => Column(children: [
                    Expanded(
                      child: SizedBox(
                        key: _mapWindowKey,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 14, right: 16, bottom: 12,
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _mapControl(LucideIcons.layers, 'Tampilan peta', () {
                                      showModalBottomSheet<void>(
                                        context: context, isScrollControlled: true,
                                        useSafeArea: true, showDragHandle: true,
                                        backgroundColor: Colors.white,
                                        builder: (_) => const MapLayerSheet(),
                                      );
                                    }),
                                    const SizedBox(height: 10),
                                    _mapControl(LucideIcons.focus, 'Tampilkan semua hasil filter', _fitMarkers),
                                    const SizedBox(height: 10),
                                    _mapControl(
                                      _isLocating ? LucideIcons.loader2 : LucideIcons.locateFixed,
                                      'Lokasi saya', _locateUser, primary: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!showMarkers)
                              Positioned(
                                left: 16, top: 14, right: 80,
                                child: Material(
                                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                                  child: TextButton(
                                    onPressed: () => ref.read(showTreeMarkersProvider.notifier).state = true,
                                    child: const Text('Tampilkan penanda'),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!keyboardOpen)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Center(child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 600,
                            maxHeight: mapSpace.maxHeight * 0.62,
                          ),
                          child: selected != null
                                    ? MapInspectionCard(
                                        marker: selected,
                                        position: index + 1, total: markers.length,
                                        onClose: () {
                                          ref.read(selectedTreeMapIdProvider.notifier).state = null;
                                          _fitAfterFrame();
                                        },
                                        onDetail: () => _openDetail(selected.record),
                                        onPrevious: index > 0 ? () => _select(markers[index - 1]) : null,
                                        onNext: index >= 0 && index + 1 < markers.length
                                            ? () => _select(markers[index + 1]) : null,
                                      )
                                    : SingleChildScrollView(child: MapDataStatusCard(
                                        data: data, feed: feed, isGuest: guest,
                                        onRefresh: () => unawaited(_refresh()),
                                        onStartScan: _startInspection,
                                        onWithoutLocation: _showWithoutLocation,
                                        onShowList: _showInspectionList,
                                        onClearFilters: hasFilter ? _clearFilters : null,
                                      )),
                        )),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: Colors.white.withValues(alpha: 0.92),
                        child: Text(
                          layer == MapLayerType.satellite ? 'Tiles © Esri'
                              : layer == MapLayerType.terrain
                                      ? '© OpenStreetMap contributors · OpenTopoMap'
                                      : '© OpenStreetMap contributors',
                          style: const TextStyle(fontSize: 9, color: Colors.black87),
                        ),
                      ),
                    ),
                      ]),
                    )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapControl(IconData icon, String tooltip, VoidCallback action,
      {bool primary = false}) => Material(
    color: primary ? AppColors.primary : Colors.white,
    elevation: 2, shadowColor: const Color(0x22094228),
    borderRadius: BorderRadius.circular(16),
    child: IconButton(
      tooltip: tooltip, onPressed: action,
      icon: Icon(icon, color: primary ? Colors.white : AppColors.primary, size: 21),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    ),
  );

  String _riskLabel(RiskLevel? risk) => switch (risk) {
    null => 'Semua',
    RiskLevel.rendah => 'Rendah',
    RiskLevel.sedang => 'Sedang',
    RiskLevel.tinggi => 'Tinggi',
    RiskLevel.kritis => 'Kritis',
  };

  Color _riskColor(RiskLevel risk) => switch (risk) {
    RiskLevel.rendah => AppColors.primary,
    RiskLevel.sedang => const Color(0xFFD97706),
    RiskLevel.tinggi => const Color(0xFFEA580C),
    RiskLevel.kritis => const Color(0xFFE11D48),
  };
}

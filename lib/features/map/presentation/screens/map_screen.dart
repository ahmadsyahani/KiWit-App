import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../report/presentation/screens/tree_detail_screen.dart';
import '../../data/models/tree_map_model.dart';
import '../controllers/map_controller.dart';
import '../widgets/map_layer_sheet.dart';
import '../widgets/new_tree_ping_sheet.dart';
import '../widgets/user_location_marker.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class LatLngTween extends Tween<LatLng> {
  LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) {
    final lat = begin!.latitude + (end!.latitude - begin!.latitude) * t;
    final lng = begin!.longitude + (end!.longitude - begin!.longitude) * t;
    return LatLng(lat, lng);
  }
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _isLocating = false;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _initUserLocation();
  }

  void _animatedMapMove(
    LatLng destLocation,
    double destZoom, {
    double? destRotation,
  }) {
    final camera = _mapController.camera;
    final latTween = LatLngTween(begin: camera.center, end: destLocation);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);
    final targetRot = destRotation ?? camera.rotation;
    final rotTween = Tween<double>(begin: camera.rotation, end: targetRot);

    final controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );

    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      _mapController.move(
        latTween.evaluate(animation),
        zoomTween.evaluate(animation),
      );
      if (destRotation != null) {
        _mapController.rotate(rotTween.evaluate(animation));
      }
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _resetToInitialView(String userRayon) {
    final initialPoint =
        _rayonCoordinates[userRayon] ?? const LatLng(-7.2856, 112.7915);
    _animatedMapMove(initialPoint, 14.8, destRotation: 0.0);
    ref.read(selectedTreeMapItemProvider.notifier).state = null;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(LucideIcons.compass, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Peta dikembalikan ke posisi & orientasi awal (Utara)'),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _initUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
        if (mounted) {
          setState(() {
            _userLocation = LatLng(pos.latitude, pos.longitude);
          });
        }
      }
    } catch (_) {}
  }

  // Koordinat Titik Pusat Rayon di Surabaya
  final Map<String, LatLng> _rayonCoordinates = {
    'Rayon 1 — Genteng (Surabaya Pusat)': const LatLng(-7.2620, 112.7430),
    'Rayon 2 — Rungkut (Surabaya Timur)': const LatLng(-7.3200, 112.7720),
    'Rayon 3 — Sukolilo': const LatLng(-7.2856, 112.7915),
    'Rayon 3 — Sukolilo (Surabaya Timur II)': const LatLng(-7.2856, 112.7915),
    'Rayon 4 — Sawahan (Surabaya Selatan)': const LatLng(-7.2950, 112.7260),
    'Rayon 5 — Tandes (Surabaya Barat)': const LatLng(-7.2580, 112.6780),
    'Rayon 6 — Kenjeran (Surabaya Utara)': const LatLng(-7.2280, 112.7660),
  };

  final List<Map<String, String>> _rayonList = [
    {
      'title': 'Rayon 1 — Genteng (Surabaya Pusat)',
      'code': 'R1',
      'desc': 'Pusat',
    },
    {
      'title': 'Rayon 2 — Rungkut (Surabaya Timur)',
      'code': 'R2',
      'desc': 'Timur',
    },
    {'title': 'Rayon 3 — Sukolilo', 'code': 'R3', 'desc': 'Sukolilo'},
    {
      'title': 'Rayon 4 — Sawahan (Surabaya Selatan)',
      'code': 'R4',
      'desc': 'Selatan',
    },
    {
      'title': 'Rayon 5 — Tandes (Surabaya Barat)',
      'code': 'R5',
      'desc': 'Barat',
    },
    {
      'title': 'Rayon 6 — Kenjeran (Surabaya Utara)',
      'code': 'R6',
      'desc': 'Utara',
    },
    {'title': 'Semua Rayon', 'code': 'ALL', 'desc': 'Semua'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectAdjacentTree(int newIndex, List<TreeMapModel> list) {
    if (newIndex >= 0 && newIndex < list.length) {
      final nextTree = list[newIndex];
      ref.read(selectedTreeMapItemProvider.notifier).state = nextTree;
      _animatedMapMove(LatLng(nextTree.latitude, nextTree.longitude), 16.5);
    }
  }

  void _moveToRayon(String rayonKey) {
    if (rayonKey == 'Semua Rayon') {
      _animatedMapMove(const LatLng(-7.2800, 112.7400), 12.5);
      return;
    }

    final target = _rayonCoordinates.entries.firstWhere(
      (entry) => entry.key.contains(rayonKey.split(' — ')[0]),
      orElse: () => MapEntry('default', const LatLng(-7.2856, 112.7915)),
    );

    _animatedMapMove(target.value, 15.0);
  }

  Future<void> _locateUser() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Layanan GPS perangkat belum aktif'),
              backgroundColor: Colors.orange.shade800,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Izin akses lokasi GPS ditolak'),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Izin lokasi ditolak permanen di pengaturan'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final loc = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = loc;
      });

      _animatedMapMove(loc, 17.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Peta dipusatkan ke posisi GPS Anda'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mendapatkan lokasi GPS: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _openLayerSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MapLayerSheet(),
    );
  }

  void _openFilterModal(
    BuildContext context,
    String currentRayon,
    RiskLevel? currentRisk,
    String userRayon,
  ) {
    String tempRayon = currentRayon;
    RiskLevel? tempRisk = currentRisk;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          LucideIcons.slidersHorizontal,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Filter Peta & Rayon',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.x,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Section 1: Rayon Selection Grid
                const Text(
                  'Wilayah Penugasan (Rayon DLH)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _rayonList.map((rayon) {
                    final isSelected =
                        tempRayon == rayon['title'] ||
                        (tempRayon.contains(rayon['title']!.split(' — ')[0]) &&
                            rayon['title'] != 'Semua Rayon');
                    final isUserRayon =
                        userRayon.contains(rayon['title']!.split(' — ')[0]) &&
                        rayon['title'] != 'Semua Rayon';

                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rayon['code'] == 'ALL'
                                ? '🌐 Semua'
                                : '${rayon['code']} ${rayon['desc']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (isUserRayon) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.background,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() => tempRayon = rayon['title']!);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Section 2: Risk Level Selection
                const Text(
                  'Tingkat Risiko ISA-TRAQ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildRiskModalChoice(
                      'Semua',
                      null,
                      tempRisk == null,
                      setModalState,
                      (val) => tempRisk = val,
                    ),
                    const SizedBox(width: 6),
                    _buildRiskModalChoice(
                      '🔴 Kritis',
                      RiskLevel.kritis,
                      tempRisk == RiskLevel.kritis,
                      setModalState,
                      (val) => tempRisk = val,
                    ),
                    const SizedBox(width: 6),
                    _buildRiskModalChoice(
                      '🟠 Tinggi',
                      RiskLevel.tinggi,
                      tempRisk == RiskLevel.tinggi,
                      setModalState,
                      (val) => tempRisk = val,
                    ),
                    const SizedBox(width: 6),
                    _buildRiskModalChoice(
                      '🟡 Sedang',
                      RiskLevel.sedang,
                      tempRisk == RiskLevel.sedang,
                      setModalState,
                      (val) => tempRisk = val,
                    ),
                    const SizedBox(width: 6),
                    _buildRiskModalChoice(
                      '🟢 Rendah',
                      RiskLevel.rendah,
                      tempRisk == RiskLevel.rendah,
                      setModalState,
                      (val) => tempRisk = val,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          setModalState(() {
                            tempRayon = userRayon;
                            tempRisk = null;
                          });
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          ref.read(selectedRayonFilterProvider.notifier).state =
                              tempRayon;
                          ref.read(selectedRiskFilterProvider.notifier).state =
                              tempRisk;
                          Navigator.pop(ctx);
                          _moveToRayon(tempRayon);
                        },
                        child: const Text(
                          'Terapkan Filter',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRiskModalChoice(
    String label,
    RiskLevel? level,
    bool isSelected,
    StateSetter setModalState,
    Function(RiskLevel?) onSelect,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setModalState(() => onSelect(level)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryDark : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  void _openNewPingSheet(LatLng position, String activeRayon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          NewTreePingSheet(position: position, activeRayon: activeRayon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final userRayon = profile?.rayon ?? 'Rayon 3 — Sukolilo';

    final selectedRayon = ref.watch(selectedRayonFilterProvider);
    final selectedRisk = ref.watch(selectedRiskFilterProvider);
    final selectedLayer = ref.watch(selectedMapLayerProvider);
    final isPingMode = ref.watch(isMapPingModeProvider);
    final selectedTree = ref.watch(selectedTreeMapItemProvider);
    final treesAsync = ref.watch(mapTreesListProvider);

    final showDangerZones = ref.watch(showDangerZonesProvider);
    final showTreeMarkers = ref.watch(showTreeMarkersProvider);

    final List<TreeMapModel> trees = treesAsync.value ?? [];
    final bool hasActiveFilter =
        selectedRisk != null || selectedRayon != userRayon;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive Base Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _rayonCoordinates[userRayon] ??
                  const LatLng(-7.2856, 112.7915),
              initialZoom: 14.8,
              onTap: (tapPosition, point) {
                if (!isPingMode) {
                  ref.read(selectedTreeMapItemProvider.notifier).state = null;
                }
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(selectedLayer.urlTemplate),
                urlTemplate: selectedLayer.urlTemplate,
                userAgentPackageName: 'com.kiwit.app.surabaya',
              ),

              // Danger Buffer Circles for Critical/High Risk
              if (showDangerZones)
                CircleLayer(
                  circles: trees
                      .where(
                        (t) =>
                            t.riskLevel == RiskLevel.kritis ||
                            t.riskLevel == RiskLevel.tinggi,
                      )
                      .map((tree) {
                        final isCritical = tree.riskLevel == RiskLevel.kritis;
                        return CircleMarker(
                          point: LatLng(tree.latitude, tree.longitude),
                          radius: tree.dangerRadiusMeters * 1.8,
                          useRadiusInMeter: true,
                          color: isCritical
                              ? Colors.red.withValues(alpha: 0.22)
                              : Colors.orange.withValues(alpha: 0.18),
                          borderColor: isCritical
                              ? Colors.red.withValues(alpha: 0.7)
                              : Colors.orange.withValues(alpha: 0.6),
                          borderStrokeWidth: 1.5,
                        );
                      })
                      .toList(),
                ),

              // Tree Markers Layer
              if (showTreeMarkers)
                MarkerLayer(
                  markers: trees.map((tree) {
                    final isSelected = selectedTree?.id == tree.id;
                    Color pinColor;
                    switch (tree.riskLevel) {
                      case RiskLevel.kritis:
                        pinColor = Colors.red.shade700;
                        break;
                      case RiskLevel.tinggi:
                        pinColor = Colors.orange.shade800;
                        break;
                      case RiskLevel.sedang:
                        pinColor = Colors.amber.shade800;
                        break;
                      case RiskLevel.rendah:
                        pinColor = AppColors.primary;
                        break;
                    }

                    return Marker(
                      point: LatLng(tree.latitude, tree.longitude),
                      width: isSelected ? 48 : 36,
                      height: isSelected ? 48 : 36,
                      rotate: true,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () {
                          ref.read(selectedTreeMapItemProvider.notifier).state =
                              tree;
                          _animatedMapMove(
                            LatLng(tree.latitude, tree.longitude),
                            16.5,
                          );
                        },
                        child: AnimatedScale(
                          scale: isSelected ? 1.25 : 1.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: pinColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: isSelected ? 3.5 : 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: pinColor.withValues(
                                    alpha: isSelected ? 0.6 : 0.35,
                                  ),
                                  blurRadius: isSelected ? 12 : 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                tree.riskLevel == RiskLevel.kritis
                                    ? LucideIcons.alertTriangle
                                    : LucideIcons.trees,
                                color: Colors.white,
                                size: isSelected ? 22 : 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // User Live GPS Location Ping Marker
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 90,
                      height: 90,
                      rotate: true,
                      alignment: Alignment.center,
                      child: UserLocationPingMarker(
                        position: _userLocation!,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.radio,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Posisi Anda: ${_userLocation!.latitude.toStringAsFixed(5)}, ${_userLocation!.longitude.toStringAsFixed(5)}',
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF0369A1),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. Ping Mode Target Indicator (Center of Screen)
          if (isPingMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            LucideIcons.target,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Arahkan target ke posisi pohon',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.mapPin,
                          color: Colors.red,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Modern Floating Header (Search Bar + Layer Selector + Filter Chips)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main Elevated Search Bar (Search + Filter only)
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(
                          LucideIcons.search,
                          color: AppColors.primary,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) =>
                                ref
                                        .read(mapSearchQueryProvider.notifier)
                                        .state =
                                    val,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cari kode, spesies, atau jalan...',
                              hintStyle: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        LucideIcons.x,
                                        color: AppColors.textMuted,
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref
                                                .read(
                                                  mapSearchQueryProvider
                                                      .notifier,
                                                )
                                                .state =
                                            '';
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),

                        // Filter Trigger Button (Single clean button on right)
                        GestureDetector(
                          onTap: () => _openFilterModal(
                            context,
                            selectedRayon,
                            selectedRisk,
                            userRayon,
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: hasActiveFilter
                                  ? AppColors.primary
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: hasActiveFilter
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.slidersHorizontal,
                                  color: hasActiveFilter
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Filter',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: hasActiveFilter
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Refined Horizontal Quick Filter Chips (Clean & Slim)
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Quick Risk Filters
                        _buildQuickFilterChip(
                          label: 'Semua',
                          dotColor: null,
                          isSelected: selectedRisk == null,
                          onTap: () =>
                              ref
                                      .read(selectedRiskFilterProvider.notifier)
                                      .state =
                                  null,
                        ),
                        _buildQuickFilterChip(
                          label: 'Kritis',
                          dotColor: const Color(0xFFE11D48),
                          isSelected: selectedRisk == RiskLevel.kritis,
                          onTap: () =>
                              ref
                                  .read(selectedRiskFilterProvider.notifier)
                                  .state = selectedRisk == RiskLevel.kritis
                              ? null
                              : RiskLevel.kritis,
                        ),
                        _buildQuickFilterChip(
                          label: 'Tinggi',
                          dotColor: const Color(0xFFEA580C),
                          isSelected: selectedRisk == RiskLevel.tinggi,
                          onTap: () =>
                              ref
                                  .read(selectedRiskFilterProvider.notifier)
                                  .state = selectedRisk == RiskLevel.tinggi
                              ? null
                              : RiskLevel.tinggi,
                        ),
                        _buildQuickFilterChip(
                          label: 'Sedang',
                          dotColor: const Color(0xFFD97706),
                          isSelected: selectedRisk == RiskLevel.sedang,
                          onTap: () =>
                              ref
                                  .read(selectedRiskFilterProvider.notifier)
                                  .state = selectedRisk == RiskLevel.sedang
                              ? null
                              : RiskLevel.sedang,
                        ),
                        _buildQuickFilterChip(
                          label: 'Rendah',
                          dotColor: const Color(0xFF16A34A),
                          isSelected: selectedRisk == RiskLevel.rendah,
                          onTap: () =>
                              ref
                                  .read(selectedRiskFilterProvider.notifier)
                                  .state = selectedRisk == RiskLevel.rendah
                              ? null
                              : RiskLevel.rendah,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Floating Action Dock on Right Side
          Positioned(
            right: 16,
            top: 155,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Reset Map to Initial North View
                  _buildDockButton(
                    icon: LucideIcons.compass,
                    tooltip: 'Reset Tampilan Awal & Utara',
                    onTap: () => _resetToInitialView(userRayon),
                    iconColor: Colors.red.shade700,
                  ),
                  const SizedBox(height: 4),

                  // 2. Layer Switcher Dock Button
                  _buildDockButton(
                    icon: LucideIcons.layers,
                    tooltip: 'Ubah Tampilan Peta',
                    onTap: _openLayerSelector,
                  ),
                  const Divider(height: 12, indent: 6, endIndent: 6),

                  // 3. GPS My Location
                  _buildDockButton(
                    icon: _isLocating
                        ? LucideIcons.loader2
                        : LucideIcons.locateFixed,
                    tooltip: 'Lokasi Saya (GPS)',
                    onTap: _isLocating ? () {} : _locateUser,
                    iconColor: AppColors.primary,
                  ),
                  const SizedBox(height: 4),

                  // 4. Recenter to active Rayon
                  _buildDockButton(
                    icon: LucideIcons.focus,
                    tooltip: 'Pusatkan ke Rayon',
                    onTap: () => _moveToRayon(selectedRayon),
                  ),
                  const Divider(height: 12, indent: 6, endIndent: 6),

                  // Zoom In
                  _buildDockButton(
                    icon: LucideIcons.plus,
                    tooltip: 'Perbesar',
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      _animatedMapMove(
                        _mapController.camera.center,
                        (currentZoom + 1).clamp(3.0, 19.0),
                      );
                    },
                  ),
                  const SizedBox(height: 4),

                  // Zoom Out
                  _buildDockButton(
                    icon: LucideIcons.minus,
                    tooltip: 'Perkecil',
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      _animatedMapMove(
                        _mapController.camera.center,
                        (currentZoom - 1).clamp(3.0, 19.0),
                      );
                    },
                  ),
                  const Divider(height: 12, indent: 6, endIndent: 6),

                  // Toggle Ping / Add Mode Button
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isPingMode
                          ? Colors.red.shade700
                          : AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isPingMode ? LucideIcons.x : LucideIcons.mapPinPlus,
                        color: isPingMode
                            ? Colors.white
                            : AppColors.primaryDark,
                        size: 18,
                      ),
                      tooltip: isPingMode
                          ? 'Batal Tambah'
                          : 'Tambah Titik Pohon',
                      onPressed: () {
                        ref.read(isMapPingModeProvider.notifier).state =
                            !isPingMode;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Ping Confirm Floating CTA Button (When in Ping Mode)
          if (isPingMode)
            Positioned(
              left: 20,
              right: 20,
              bottom: 105,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(LucideIcons.check, size: 20),
                label: const Text(
                  'Pasang Laporan di Titik Target Ini',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  final centerPoint = _mapController.camera.center;
                  _openNewPingSheet(
                    centerPoint,
                    selectedRayon == 'Semua Rayon' ? userRayon : selectedRayon,
                  );
                },
              ),
            ),

          // 6. Selected Tree Info Card (Ultra UX-Friendly Bottom Dock with Prev/Next Navigation)
          if (selectedTree != null && !isPingMode) ...[
            Builder(
              builder: (context) {
                final currentIndex = trees.indexWhere(
                  (t) => t.id == selectedTree.id,
                );
                final hasPrev = currentIndex > 0;
                final hasNext =
                    currentIndex != -1 && currentIndex < trees.length - 1;

                return Positioned(
                  left: 16,
                  right: 16,
                  bottom: 116, // Raised above floating bottom navigation bar
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity != null) {
                        if (details.primaryVelocity! < -150 && hasNext) {
                          _selectAdjacentTree(currentIndex + 1, trees);
                        } else if (details.primaryVelocity! > 150 && hasPrev) {
                          _selectAdjacentTree(currentIndex - 1, trees);
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header: Tree Code + Rayon + Risk Badge + Close Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      selectedTree.treeCode,
                                      style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    selectedTree.rayon.split(' — ')[0],
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),

                              Row(
                                children: [
                                  RiskBadge(level: selectedTree.riskLevel),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      ref
                                              .read(
                                                selectedTreeMapItemProvider
                                                    .notifier,
                                              )
                                              .state =
                                          null;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: const Icon(
                                        LucideIcons.x,
                                        color: AppColors.textMuted,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Tree Name & Latin Name
                          Text(
                            selectedTree.speciesName,
                            style: const TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (selectedTree.latinName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                selectedTree.latinName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),

                          // Address
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.mapPin,
                                color: AppColors.textMuted,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  selectedTree.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Counter & Hint indicator
                          if (currentIndex != -1 && trees.length > 1) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Pohon ${currentIndex + 1} dari ${trees.length} di rayon ini',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.moveHorizontal,
                                      color: AppColors.textMuted,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Geser untuk ganti',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Ergonomic Bottom Navigation Row (Prev, Main CTA, Next)
                          Row(
                            children: [
                              // 1. Prev Button
                              if (trees.length > 1) ...[
                                Material(
                                  color: hasPrev
                                      ? AppColors.surface
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: hasPrev
                                        ? () => _selectAdjacentTree(
                                            currentIndex - 1,
                                            trees,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: hasPrev
                                              ? AppColors.border
                                              : AppColors.border.withValues(
                                                  alpha: 0.5,
                                                ),
                                        ),
                                      ),
                                      child: Icon(
                                        LucideIcons.chevronLeft,
                                        color: hasPrev
                                            ? AppColors.textPrimary
                                            : AppColors.textMuted.withValues(
                                                alpha: 0.5,
                                              ),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],

                              // 2. Main CTA Button: Lihat Detail Evaluasi
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryDark,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const TreeDetailScreen(),
                                        ),
                                      );
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Text(
                                          'Lihat Detail Evaluasi',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // 3. Next Button
                              if (trees.length > 1) ...[
                                const SizedBox(width: 10),
                                Material(
                                  color: hasNext
                                      ? AppColors.surface
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: hasNext
                                        ? () => _selectAdjacentTree(
                                            currentIndex + 1,
                                            trees,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: hasNext
                                              ? AppColors.border
                                              : AppColors.border.withValues(
                                                  alpha: 0.5,
                                                ),
                                        ),
                                      ),
                                      child: Icon(
                                        LucideIcons.chevronRight,
                                        color: hasNext
                                            ? AppColors.textPrimary
                                            : AppColors.textMuted.withValues(
                                                alpha: 0.5,
                                              ),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip({
    required String label,
    required Color? dotColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryDark : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : AppColors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.1 : 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: iconColor ?? AppColors.textPrimary, size: 18),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}

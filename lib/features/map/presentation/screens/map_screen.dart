import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../report/presentation/screens/tree_detail_screen.dart';
import '../../data/models/tree_map_model.dart';
import '../controllers/map_controller.dart';
import '../widgets/new_tree_ping_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

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
    {'title': 'Rayon 1 — Genteng (Surabaya Pusat)', 'code': 'R1', 'desc': 'Surabaya Pusat'},
    {'title': 'Rayon 2 — Rungkut (Surabaya Timur)', 'code': 'R2', 'desc': 'Surabaya Timur'},
    {'title': 'Rayon 3 — Sukolilo', 'code': 'R3', 'desc': 'Surabaya Timur II'},
    {'title': 'Rayon 4 — Sawahan (Surabaya Selatan)', 'code': 'R4', 'desc': 'Surabaya Selatan'},
    {'title': 'Rayon 5 — Tandes (Surabaya Barat)', 'code': 'R5', 'desc': 'Surabaya Barat'},
    {'title': 'Rayon 6 — Kenjeran (Surabaya Utara)', 'code': 'R6', 'desc': 'Surabaya Utara'},
    {'title': 'Semua Rayon', 'code': 'ALL', 'desc': 'Seluruh Kota Surabaya'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _moveToRayon(String rayonKey) {
    if (rayonKey == 'Semua Rayon') {
      _mapController.move(const LatLng(-7.2800, 112.7400), 12.5);
      return;
    }

    final target = _rayonCoordinates.entries.firstWhere(
      (entry) => entry.key.contains(rayonKey.split(' — ')[0]),
      orElse: () => MapEntry('default', const LatLng(-7.2856, 112.7915)),
    );

    _mapController.move(target.value, 15.0);
  }

  void _openFilterModal(BuildContext context, String currentRayon, RiskLevel? currentRisk, String userRayon) {
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
                        Icon(LucideIcons.slidersHorizontal, color: AppColors.primary, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Filter Peta & Rayon',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: AppColors.textMuted, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Section 1: Rayon Selection Grid
                const Text(
                  'Wilayah Penugasan (Rayon DLH)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _rayonList.map((rayon) {
                    final isSelected = tempRayon == rayon['title'] || (tempRayon.contains(rayon['title']!.split(' — ')[0]) && rayon['title'] != 'Semua Rayon');
                    final isUserRayon = userRayon.contains(rayon['title']!.split(' — ')[0]) && rayon['title'] != 'Semua Rayon';

                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rayon['code'] == 'ALL' ? '🌐 Semua' : '${rayon['code']} ${rayon['desc']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          if (isUserRayon) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.background,
                      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildRiskModalChoice('Semua', null, tempRisk == null, setModalState, (val) => tempRisk = val),
                    const SizedBox(width: 6),
                    _buildRiskModalChoice('🔴 Kritis', RiskLevel.kritis, tempRisk == RiskLevel.kritis, setModalState, (val) => tempRisk = val),
                    const SizedBox(width: 6),
                    _buildRiskModalChoice('🟠 Tinggi', RiskLevel.tinggi, tempRisk == RiskLevel.tinggi, setModalState, (val) => tempRisk = val),
                    const SizedBox(width: 6),
                    _buildRiskModalChoice('🟡 Sedang', RiskLevel.sedang, tempRisk == RiskLevel.sedang, setModalState, (val) => tempRisk = val),
                    const SizedBox(width: 6),
                    _buildRiskModalChoice('🟢 Rendah', RiskLevel.rendah, tempRisk == RiskLevel.rendah, setModalState, (val) => tempRisk = val),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          setModalState(() {
                            tempRayon = userRayon;
                            tempRisk = null;
                          });
                        },
                        child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          ref.read(selectedRayonFilterProvider.notifier).state = tempRayon;
                          ref.read(selectedRiskFilterProvider.notifier).state = tempRisk;
                          Navigator.pop(ctx);
                          _moveToRayon(tempRayon);
                        },
                        child: const Text('Terapkan Filter', style: TextStyle(fontWeight: FontWeight.bold)),
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
      builder: (_) => NewTreePingSheet(
        position: position,
        activeRayon: activeRayon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final userRayon = profile?.rayon ?? 'Rayon 3 — Sukolilo';

    final selectedRayon = ref.watch(selectedRayonFilterProvider);
    final selectedRisk = ref.watch(selectedRiskFilterProvider);
    final isPingMode = ref.watch(isMapPingModeProvider);
    final selectedTree = ref.watch(selectedTreeMapItemProvider);
    final treesAsync = ref.watch(mapTreesListProvider);

    final List<TreeMapModel> trees = treesAsync.value ?? [];

    // Is custom filter active?
    final bool hasActiveFilter = selectedRisk != null || selectedRayon != userRayon;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-Screen FlutterMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _rayonCoordinates[userRayon] ?? const LatLng(-7.2856, 112.7915),
              initialZoom: 14.8,
              onTap: (tapPosition, point) {
                if (!isPingMode) {
                  ref.read(selectedTreeMapItemProvider.notifier).state = null;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kiwit.app.surabaya',
              ),

              // Danger Buffer Circles for Critical/High Risk
              CircleLayer(
                circles: trees.where((t) => t.riskLevel == RiskLevel.kritis || t.riskLevel == RiskLevel.tinggi).map((tree) {
                  final isCritical = tree.riskLevel == RiskLevel.kritis;
                  return CircleMarker(
                    point: LatLng(tree.latitude, tree.longitude),
                    radius: tree.dangerRadiusMeters * 1.8,
                    useRadiusInMeter: true,
                    color: isCritical
                        ? Colors.red.withValues(alpha: 0.18)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderColor: isCritical
                        ? Colors.red.withValues(alpha: 0.6)
                        : Colors.orange.withValues(alpha: 0.5),
                    borderStrokeWidth: 1.5,
                  );
                }).toList(),
              ),

              // Tree Markers
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
                    width: isSelected ? 46 : 36,
                    height: isSelected ? 46 : 36,
                    child: GestureDetector(
                      onTap: () {
                        ref.read(selectedTreeMapItemProvider.notifier).state = tree;
                        _mapController.move(LatLng(tree.latitude, tree.longitude), 16.0);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: pinColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: isSelected ? 3.0 : 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: pinColor.withValues(alpha: 0.4),
                              blurRadius: isSelected ? 10 : 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            LucideIcons.trees,
                            color: Colors.white,
                            size: isSelected ? 22 : 16,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 2. Crosshair Indicator in Ping Mode
          if (isPingMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Geser peta ke titik lokasi pohon',
                        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Icon(
                      LucideIcons.mapPin,
                      color: Colors.red,
                      size: 42,
                    ),
                  ],
                ),
              ),
            ),

          // 3. Premium Floating Search & Filter Bar (Minimalist Single Island)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Unified Search Bar with Integrated Filter Trigger
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(LucideIcons.search, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => ref.read(mapSearchQueryProvider.notifier).state = val,
                            style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Cari pohon, kode, atau jalan...',
                              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
                              border: InputBorder.none,
                              isDense: true,
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(LucideIcons.x, color: AppColors.textMuted, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref.read(mapSearchQueryProvider.notifier).state = '';
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        // Filter Trigger Button
                        GestureDetector(
                          onTap: () => _openFilterModal(context, selectedRayon, selectedRisk, userRayon),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: hasActiveFilter ? AppColors.primary : AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: hasActiveFilter ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.slidersHorizontal,
                                  color: hasActiveFilter ? Colors.white : AppColors.textPrimary,
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Filter',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: hasActiveFilter ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Mini Discrete Active Filter Tags (Only shown when filtered)
                  if (hasActiveFilter)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Wrap(
                        spacing: 6,
                        children: [
                          if (selectedRayon != userRayon)
                            _buildActiveTag(
                              '📍 ${selectedRayon.split(' — ')[0]}',
                              () => ref.read(selectedRayonFilterProvider.notifier).state = userRayon,
                            ),
                          if (selectedRisk != null)
                            _buildActiveTag(
                              'Risiko: ${selectedRisk.name.toUpperCase()}',
                              () => ref.read(selectedRiskFilterProvider.notifier).state = null,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. Floating Tools on Right Side (Safely below the search & filter bar)
          Positioned(
            right: 16,
            top: 155,
            child: Column(
              children: [
                // Recenter My Rayon Tool Button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(LucideIcons.crosshair, color: AppColors.primary, size: 20),
                    tooltip: 'Pusatkan ke Rayon Saya',
                    onPressed: () => _moveToRayon(userRayon),
                  ),
                ),
                const SizedBox(height: 12),

                // Toggle Ping Mode Tool Button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPingMode ? Colors.red.shade700 : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: isPingMode ? Colors.red.shade700 : AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: (isPingMode ? Colors.red : Colors.black).withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      isPingMode ? LucideIcons.x : LucideIcons.mapPinPlus,
                      color: isPingMode ? Colors.white : AppColors.primary,
                      size: 20,
                    ),
                    tooltip: isPingMode ? 'Batal Ping' : 'Ping Lokasi Pohon',
                    onPressed: () {
                      ref.read(isMapPingModeProvider.notifier).state = !isPingMode;
                    },
                  ),
                ),
              ],
            ),
          ),


          // 5. Ping Confirm CTA Button (Bottom Center in Ping Mode)
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(LucideIcons.check, size: 20),
                label: const Text(
                  'Pasang Laporan di Titik Ini',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  final centerPoint = _mapController.camera.center;
                  _openNewPingSheet(centerPoint, selectedRayon == 'Semua Rayon' ? userRayon : selectedRayon);
                },
              ),
            ),

          // 6. Selected Tree Card (Bottom View with clean margin)
          if (selectedTree != null && !isPingMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: 95,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                selectedTree.treeCode,
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedTree.rayon.split(' — ')[0],
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        RiskBadge(level: selectedTree.riskLevel),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedTree.speciesName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (selectedTree.latinName.isNotEmpty)
                      Text(
                        selectedTree.latinName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textMuted,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin, color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            selectedTree.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              ref.read(selectedTreeMapItemProvider.notifier).state = null;
                            },
                            child: const Text('Tutup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TreeDetailScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Lihat Detail Evaluasi',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveTag(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(LucideIcons.x, color: Colors.white, size: 12),
          ),
        ],
      ),
    );
  }
}
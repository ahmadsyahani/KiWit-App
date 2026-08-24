import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../controllers/map_controller.dart';

class MapLayerSheet extends ConsumerWidget {
  const MapLayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLayer = ref.watch(selectedMapLayerProvider);
    final showDangerZones = ref.watch(showDangerZonesProvider);
    final showTreeMarkers = ref.watch(showTreeMarkersProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF202124), // Google Maps Dark Sheet background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "Jenis peta" + Close Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Jenis peta',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(LucideIcons.x, color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Section 1: Jenis peta (Row of 3 main map types)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMapTypeItem(
                label: 'Default',
                isSelected: currentLayer == MapLayerType.voyager || currentLayer == MapLayerType.osm,
                thumbnailWidget: CustomPaint(
                  size: const Size(66, 66),
                  painter: DefaultMapThumbnailPainter(),
                ),
                onTap: () => ref.read(selectedMapLayerProvider.notifier).state = MapLayerType.voyager,
              ),
              _buildMapTypeItem(
                label: 'Satelit',
                isSelected: currentLayer == MapLayerType.satellite,
                thumbnailWidget: CustomPaint(
                  size: const Size(66, 66),
                  painter: SatelliteMapThumbnailPainter(),
                ),
                onTap: () => ref.read(selectedMapLayerProvider.notifier).state = MapLayerType.satellite,
              ),
              _buildMapTypeItem(
                label: 'Medan',
                isSelected: currentLayer == MapLayerType.terrain,
                thumbnailWidget: CustomPaint(
                  size: const Size(66, 66),
                  painter: TerrainMapThumbnailPainter(),
                ),
                onTap: () => ref.read(selectedMapLayerProvider.notifier).state = MapLayerType.terrain,
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white12, height: 1, thickness: 1),
          const SizedBox(height: 20),

          // Section 2: Detail peta (Grid of overlay toggles)
          const Text(
            'Detail peta',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem(
                label: 'Zona Bahaya',
                isSelected: showDangerZones,
                iconWidget: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4C1D24), Color(0xFF2A1217)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.shieldAlert, color: Color(0xFFFB7185), size: 26),
                  ),
                ),
                onTap: () => ref.read(showDangerZonesProvider.notifier).state = !showDangerZones,
              ),
              _buildDetailItem(
                label: 'Penanda Pohon',
                isSelected: showTreeMarkers,
                iconWidget: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A2B), Color(0xFF112218)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.trees, color: Color(0xFF4ADE80), size: 26),
                  ),
                ),
                onTap: () => ref.read(showTreeMarkersProvider.notifier).state = !showTreeMarkers,
              ),
              _buildDetailItem(
                label: 'Mode Gelap',
                isSelected: currentLayer == MapLayerType.dark,
                iconWidget: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.moon, color: Color(0xFF38BDF8), size: 26),
                  ),
                ),
                onTap: () {
                  ref.read(selectedMapLayerProvider.notifier).state =
                      currentLayer == MapLayerType.dark ? MapLayerType.voyager : MapLayerType.dark;
                },
              ),
              _buildDetailItem(
                label: 'Minimalis',
                isSelected: currentLayer == MapLayerType.positron,
                iconWidget: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF334155), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.sun, color: Color(0xFFFBBF24), size: 26),
                  ),
                ),
                onTap: () {
                  ref.read(selectedMapLayerProvider.notifier).state =
                      currentLayer == MapLayerType.positron ? MapLayerType.voyager : MapLayerType.positron;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapTypeItem({
    required String label,
    required bool isSelected,
    required Widget thumbnailWidget,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFF38BDF8); // Cyan / Blue highlight

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? activeColor : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: thumbnailWidget,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? activeColor : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required String label,
    required bool isSelected,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFF38BDF8);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? activeColor : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ]
                  : [],
            ),
            padding: const EdgeInsets.all(2.5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: iconWidget,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : Colors.white70,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HIGH-FIDELITY VECTOR MAP THUMBNAIL PAINTERS
// ---------------------------------------------------------------------------

/// Painter for Google Maps-style Default / Street Map Thumbnail
class DefaultMapThumbnailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Urban Background (Light Gray/Beige)
    final bgPaint = Paint()..color = const Color(0xFFF1F3F4);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Water body (Blue bay on the right)
    final waterPaint = Paint()
      ..color = const Color(0xFFA5C8F8)
      ..style = PaintingStyle.fill;
    final waterPath = Path()
      ..moveTo(size.width * 0.45, 0)
      ..cubicTo(
        size.width * 0.4,
        size.height * 0.4,
        size.width * 0.65,
        size.height * 0.6,
        size.width * 0.6,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(waterPath, waterPaint);

    // 3. Green Park areas
    final parkPaint = Paint()
      ..color = const Color(0xFFCEEAD6)
      ..style = PaintingStyle.fill;
    final parkPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.12, size.width * 0.35, size.height * 0.35),
        const Radius.circular(8),
      ));
    canvas.drawPath(parkPath, parkPaint);

    final parkPath2 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.15, size.height * 0.62, size.width * 0.38, size.height * 0.32),
        const Radius.circular(8),
      ));
    canvas.drawPath(parkPath2, parkPaint);

    // 4. Minor Street Grid Lines
    final minorRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width * 0.45, size.height * 0.35), minorRoadPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height * 0.65), minorRoadPaint);

    // 5. Main Highway (Orange Freeway with Bridge / Drop Shadow)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final orangeRoadPaint = Paint()
      ..color = const Color(0xFFFDBA74) // Warm orange highway
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final whiteCenterPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final highwayPath = Path()
      ..moveTo(-5, size.height * 0.75)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.65,
        size.width * 0.5,
        size.height * 0.25,
        size.width + 5,
        size.height * 0.15,
      );

    // Draw shadow first
    canvas.drawPath(highwayPath.shift(const Offset(0, 1.5)), shadowPaint);
    // Draw highway body
    canvas.drawPath(highwayPath, orangeRoadPaint);
    // Draw highway white stripe
    canvas.drawPath(highwayPath, whiteCenterPaint);

    // 6. Crossing Arterial White Road
    final crossingRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke;
    final crossingPath = Path()
      ..moveTo(size.width * 0.1, size.height + 5)
      ..lineTo(size.width * 0.85, -5);

    canvas.drawPath(crossingPath.shift(const Offset(0, 1)), shadowPaint);
    canvas.drawPath(crossingPath, crossingRoadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for Google Maps-style Satellite Aerial Thumbnail
class SatelliteMapThumbnailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark Satellite Landscape Texture (Canopy & Parcels)
    final bgPaint = Paint()..color = const Color(0xFF1F2F20);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Forest / Crop Parcels (varied green/olive patches)
    final patch1 = Paint()..color = const Color(0xFF2E4528);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.45, size.height * 0.5), patch1);

    final patch2 = Paint()..color = const Color(0xFF162519);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.1, size.height * 0.5, size.width * 0.4, size.height * 0.5), patch2);

    final patch3 = Paint()..color = const Color(0xFF384B30);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.55, size.height * 0.45, size.width * 0.45, size.height * 0.55), patch3);

    // 2. Coastal / River Water Inlet
    final waterPaint = Paint()
      ..color = const Color(0xFF12222E)
      ..style = PaintingStyle.fill;
    final waterPath = Path()
      ..moveTo(size.width * 0.6, 0)
      ..cubicTo(
        size.width * 0.5,
        size.height * 0.35,
        size.width * 0.8,
        size.height * 0.6,
        size.width * 0.75,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(waterPath, waterPaint);

    // 3. Realistic Dual Asphalt Highway
    final asphaltPaint = Paint()
      ..color = const Color(0xFF4B5563) // Real dark asphalt
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final roadPath = Path()
      ..moveTo(-5, size.height * 0.8)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.65,
        size.width * 0.65,
        size.height * 0.35,
        size.width + 5,
        size.height * 0.15,
      );

    canvas.drawPath(roadPath, asphaltPaint);
    canvas.drawPath(roadPath, dashPaint);

    // Secondary connector ramp
    final rampPaint = Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke;
    final rampPath = Path()
      ..moveTo(size.width * 0.15, -5)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.4, size.width * 0.85, size.height + 5);
    canvas.drawPath(rampPath, rampPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for Google Maps-style Terrain / Topography Thumbnail
class TerrainMapThumbnailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Lowland Valley Base (Soft Light Green)
    final basePaint = Paint()..color = const Color(0xFFDFE9CF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // 2. Mid Elevation Tier (Olive Green)
    final tier1Paint = Paint()
      ..color = const Color(0xFFCBDCAE)
      ..style = PaintingStyle.fill;
    final tier1Path = Path()
      ..moveTo(0, size.height * 0.3)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.1,
        size.width * 0.7,
        size.height * 0.45,
        size.width,
        size.height * 0.25,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(tier1Path, tier1Paint);

    // 3. High Ridge Tier (Warm Sand / Contour)
    final tier2Paint = Paint()
      ..color = const Color(0xFFBECCA0)
      ..style = PaintingStyle.fill;
    final tier2Path = Path()
      ..moveTo(0, size.height * 0.6)
      ..cubicTo(
        size.width * 0.4,
        size.height * 0.4,
        size.width * 0.65,
        size.height * 0.75,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(tier2Path, tier2Paint);

    // 4. Mountain Peak Relief Shading
    final peakPaint = Paint()
      ..color = const Color(0xFFAFBDA0)
      ..style = PaintingStyle.fill;
    final peakPath = Path()
      ..moveTo(size.width * 0.2, size.height)
      ..cubicTo(
        size.width * 0.45,
        size.height * 0.65,
        size.width * 0.75,
        size.height * 0.85,
        size.width * 0.9,
        size.height,
      )
      ..close();
    canvas.drawPath(peakPath, peakPaint);

    // 5. Fine Topographic Contour Lines
    final contourPaint = Paint()
      ..color = const Color(0xFF7D8C69).withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final c1 = Path()
      ..moveTo(0, size.height * 0.25)
      ..cubicTo(size.width * 0.35, size.height * 0.05, size.width * 0.7, size.height * 0.4, size.width, size.height * 0.2);
    canvas.drawPath(c1, contourPaint);

    final c2 = Path()
      ..moveTo(0, size.height * 0.45)
      ..cubicTo(size.width * 0.35, size.height * 0.25, size.width * 0.7, size.height * 0.6, size.width, size.height * 0.4);
    canvas.drawPath(c2, contourPaint);

    final c3 = Path()
      ..moveTo(0, size.height * 0.7)
      ..cubicTo(size.width * 0.4, size.height * 0.5, size.width * 0.65, size.height * 0.85, size.width, size.height * 0.65);
    canvas.drawPath(c3, contourPaint);

    // Trail Line
    final trailPaint = Paint()
      ..color = const Color(0xFF991B1B).withValues(alpha: 0.6)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final trailPath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.1)
      ..lineTo(size.width * 0.45, size.height * 0.45)
      ..lineTo(size.width * 0.65, size.height * 0.9);
    canvas.drawPath(trailPath, trailPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../controllers/map_controller.dart';

class MapLayerSheet extends ConsumerWidget {
  const MapLayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMapLayerProvider);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Tampilan peta', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                ))),
                IconButton(
                  tooltip: 'Tutup tampilan peta',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < MapLayerType.values.length; index++) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(child: _LayerChoice(
                    layer: MapLayerType.values[index],
                    selected: selected == MapLayerType.values[index],
                    onTap: () => ref.read(selectedMapLayerProvider.notifier).state =
                        MapLayerType.values[index],
                  )),
                ],
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, color: Color(0xFFE3EAE4)),
            const SizedBox(height: 20),
            const Text('Detail peta', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Penanda inspeksi', style: TextStyle(fontSize: 14)),
              value: ref.watch(showTreeMarkersProvider),
              onChanged: (value) => ref.read(showTreeMarkersProvider.notifier).state = value,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sorot risiko tinggi & kritis', style: TextStyle(fontSize: 14)),
              value: ref.watch(highlightHighRiskProvider),
              onChanged: (value) => ref.read(highlightHighRiskProvider.notifier).state = value,
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerChoice extends StatelessWidget {
  const _LayerChoice({
    required this.layer,
    required this.selected,
    required this.onTap,
  });

  final MapLayerType layer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: layer.name,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: selected ? AppColors.primary : const Color(0xFFE1E7E2),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(painter: _MapPreviewPainter(layer)),
                        if (selected)
                          const Positioned(
                            right: 5, bottom: 5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.primary, shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.check, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(layer.name, textAlign: TextAlign.center, style: TextStyle(
                fontSize: 12, height: 1.4, fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : const Color(0xFF5C7064),
              )),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Small illustrations for the layer selector; the main map uses live tiles.
class _MapPreviewPainter extends CustomPainter {
  const _MapPreviewPainter(this.layer);

  final MapLayerType layer;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final satellite = layer == MapLayerType.satellite;
    final terrain = layer == MapLayerType.terrain;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint()
      ..color = satellite ? const Color(0xFF304333)
          : terrain ? const Color(0xFFDFE8CD) : const Color(0xFFECEFE9));

    if (terrain) {
      for (var index = 0; index < 6; index++) {
        final path = Path()
          ..moveTo(-10, 20 + index * 15.0)
          ..cubicTo(20, -15 + index * 16.0, 65, 85 + index * 10.0, 115, index * 17.0);
        canvas.drawPath(path, Paint()
          ..color = const Color(0xFF91A578).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7);
      }
    } else {
      final blocks = [
        const Rect.fromLTWH(4, 5, 26, 32),
        const Rect.fromLTWH(40, 4, 27, 26),
        const Rect.fromLTWH(5, 48, 22, 42),
        const Rect.fromLTWH(42, 43, 30, 31),
        const Rect.fromLTWH(79, 10, 20, 30),
        const Rect.fromLTWH(78, 63, 23, 32),
      ];
      for (var index = 0; index < blocks.length; index++) {
        canvas.drawRRect(RRect.fromRectAndRadius(blocks[index], const Radius.circular(3)),
          Paint()..color = satellite
              ? [const Color(0xFF52664A), const Color(0xFF777766), const Color(0xFF233D2D)][index % 3]
              : index == 0 ? const Color(0xFFBCDAB2) : const Color(0xFFD9DDD6));
      }
    }

    final river = Path()
      ..moveTo(86, -5)
      ..cubicTo(52, 30, 104, 55, 82, 105);
    canvas.drawPath(river, Paint()
      ..color = satellite ? const Color(0xFF244959) : const Color(0xFFA8CDDE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = terrain ? 8 : 12);

    final road = Path()
      ..moveTo(-5, 88)
      ..cubicTo(38, 74, 27, 25, 68, -6);
    canvas.drawPath(road, Paint()
      ..color = satellite ? const Color(0xFFABAAA0) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = satellite ? 5 : 8);
    canvas.drawPath(road, Paint()
      ..color = satellite ? const Color(0xFF5C6059) : const Color(0xFFE8C67F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = satellite ? 2 : 3);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MapPreviewPainter oldDelegate) =>
      oldDelegate.layer != layer;
}

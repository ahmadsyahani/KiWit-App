import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class UserLocationPingMarker extends StatefulWidget {
  final LatLng position;
  final VoidCallback? onTap;

  const UserLocationPingMarker({
    super.key,
    required this.position,
    this.onTap,
  });

  @override
  State<UserLocationPingMarker> createState() => _UserLocationPingMarkerState();
}

class _UserLocationPingMarkerState extends State<UserLocationPingMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final progress = _animController.value;

        // Ripple 1
        final wave1Scale = 1.0 + (progress * 1.8);
        final wave1Opacity = (1.0 - progress).clamp(0.0, 1.0);

        // Ripple 2 (phase offset)
        final wave2Progress = (progress + 0.5) % 1.0;
        final wave2Scale = 1.0 + (wave2Progress * 1.8);
        final wave2Opacity = (1.0 - wave2Progress).clamp(0.0, 1.0);

        return GestureDetector(
          onTap: widget.onTap,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Outer Ripple Wave 1 (Radar Pulse)
              Transform.scale(
                scale: wave1Scale,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0284C7).withValues(alpha: wave1Opacity * 0.28),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: wave1Opacity * 0.65),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Outer Ripple Wave 2 (Sub-pulse)
              Transform.scale(
                scale: wave2Scale,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0284C7).withValues(alpha: wave2Opacity * 0.2),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: wave2Opacity * 0.45),
                      width: 1.0,
                    ),
                  ),
                ),
              ),

              // Glowing Soft White Halo Base
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),

              // Core Pin Gradient Circle
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF38BDF8),
                      Color(0xFF0284C7),
                      Color(0xFF0369A1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.navigation,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),

              // Center Bright Pulse Dot
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),

              // Floating Label Badge
              Positioned(
                bottom: 34,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0369A1),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.white38, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.radio, color: Colors.white, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'Posisi Anda',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

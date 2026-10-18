import 'package:flutter/material.dart';

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    required this.title,
    required this.subtitle,
    this.onBack,
    this.compact = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final bool compact;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF104C3B),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        compact ? 12 : 20,
        24,
        compact ? 22 : 36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              tooltip: 'Kembali ke halaman masuk',
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                minimumSize: const Size(48, 48),
              ),
            ),
            SizedBox(height: compact ? 12 : 20),
          ],
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 14 : 19),
                child: Image.asset(
                  'assets/branding/kiwit-launcher-preview.png',
                  width: compact ? 52 : 72,
                  height: compact ? 52 : 72,
                  semanticLabel: 'KiWit',
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Inspeksi pohon\nDLH Kota Surabaya',
                  style: TextStyle(
                    color: Color(0xFFD2E7DC),
                    fontSize: 12,
                    height: 1.65,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 28),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                height: 1.18,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFD2E7DC),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

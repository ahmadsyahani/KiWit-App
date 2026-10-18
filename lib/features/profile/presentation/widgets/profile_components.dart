import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';

const profileCanvas = Color(0xFFEEF4EF);
const profileSecondary = Color(0xFF5C7064);

class ProfileCard extends StatelessWidget {
  const ProfileCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFDCE6DE)),
    ),
    child: child,
  );
}

class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(
        color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700,
      )),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(
        color: profileSecondary, fontSize: 13, height: 1.5,
      )),
    ],
  );
}

class ProfileDetail extends StatelessWidget {
  const ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 16, bottom: last ? 0 : 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(icon, size: 19, color: profileSecondary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(
                color: profileSecondary, fontSize: 12,
              )),
              const SizedBox(height: 5),
              Text(
                value.trim().isEmpty || value == '-' ? 'Belum diisi' : value,
                style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14,
                  fontWeight: FontWeight.w600, height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.name,
    this.avatarUrl,
    this.dark = false,
    super.key,
  });

  final String name;
  final String? avatarUrl;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty).toList();
    final initials = words.take(2).map((word) =>
        word.characters.first).join().toUpperCase();
    final background = dark ? Colors.white.withValues(alpha: 0.14)
        : AppColors.primaryLight;
    final foreground = dark ? Colors.white : AppColors.primary;
    final fallback = Center(
      child: initials.isEmpty
          ? Icon(LucideIcons.user, color: foreground, size: 28)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(initials, style: TextStyle(
                color: foreground, fontSize: 24, fontWeight: FontWeight.w700,
              )),
            ),
    );
    return ExcludeSemantics(
      child: Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: dark
              ? Colors.white.withValues(alpha: 0.25)
              : const Color(0xFFDCE6DE)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: avatarUrl != null && avatarUrl!.trim().isNotEmpty
              ? Image.network(avatarUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback)
              : fallback,
        ),
      ),
    );
  }
}

InputDecoration profileInputDecoration(String hint, IconData icon) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: profileSecondary, fontSize: 14),
    prefixIcon: Icon(icon, color: profileSecondary, size: 20),
    filled: true,
    fillColor: const Color(0xFFF7FAF7),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    errorMaxLines: 3,
    border: border(const Color(0xFFDCE5DE)),
    enabledBorder: border(const Color(0xFFDCE5DE)),
    focusedBorder: border(AppColors.primary, 1.5),
    errorBorder: border(const Color(0xFFB33D3D)),
    focusedErrorBorder: border(const Color(0xFFB33D3D), 1.5),
  );
}

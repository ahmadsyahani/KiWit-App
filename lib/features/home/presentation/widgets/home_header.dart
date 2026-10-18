import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notifications/presentation/notification_bell.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    
    final String displayName = profileAsync.value?.fullName ?? 
        (user?.userMetadata?['full_name'] as String?) ?? 
        (user != null ? (user.email?.split('@').first ?? 'Pengguna') : 'Pengguna');
        
    final String rayon = profileAsync.value?.rayon ?? 
        (user?.userMetadata?['rayon'] as String?) ?? 
        '';

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.user,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              if (rayon.isNotEmpty)
                Text(
                  rayon,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        const NotificationBell(),
      ],
    );
  }
}

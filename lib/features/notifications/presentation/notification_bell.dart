import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import 'notification_controller.dart';
import 'notification_screen.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationControllerProvider.select((state) => state.unreadCount));
    return Badge(
      isLabelVisible: unread > 0,
      label: Text(unread > 99 ? '99+' : '$unread'),
      offset: const Offset(-2, 2),
      child: IconButton(
        tooltip: unread == 0 ? 'Notifikasi' : 'Notifikasi, $unread belum dibaca',
        onPressed: () => Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => const NotificationScreen())),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 48),
        ),
        icon: const Icon(Icons.notifications_none_rounded, size: 23),
      ),
    );
  }
}

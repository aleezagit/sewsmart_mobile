import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/notification_list.dart';

class TailorNotificationsScreen extends StatefulWidget {
  const TailorNotificationsScreen({super.key});

  @override
  State<TailorNotificationsScreen> createState() =>
      _TailorNotificationsScreenState();
}

class _TailorNotificationsScreenState
    extends State<TailorNotificationsScreen> with NotificationListState {



  Color _notifColor(String type) {
    switch (type) {
      case 'new_order':
        return AppColors.warning;
      case 'payment':
        return AppColors.success;
      case 'message':
        return AppColors.info;
      case 'verified':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'new_order':
        return Icons.inbox_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'verified':
        return Icons.verified_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }


  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        orb1: AppColors.tealOrb,
        orb2: AppColors.purpleOrb,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(unread),
              if (loading)
                Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.tealLight,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (loadError != null)
                Expanded(child: LoadError(error: loadError!, onRetry: retryLoad))
              else if (notifications.isEmpty)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications',
                    subtitle: 'You are all caught up!',
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    itemCount: notifications.length,
                    itemBuilder: (_, i) {
                      final n = notifications[i];
                      return _NotificationCard(
                        notification: n,
                        color: _notifColor(n.type),
                        icon: _notifIcon(n.type),
                        timeStr: _timeAgo(n.createdAt),
                        onTap: () => markRead(n),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(int unread) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 0),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                if (unread > 0)
                  Text(
                    '$unread unread',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (unread > 0)
            GestureDetector(
              onTap: markAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.tealLight.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Mark all read',
                  style: GoogleFonts.poppins(color: AppColors.tealLight, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final Color color;
  final IconData icon;
  final String timeStr;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.color,
    required this.icon,
    required this.timeStr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? AppColors.card
              : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead
                ? AppColors.divider
                : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    timeStr,
                    style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

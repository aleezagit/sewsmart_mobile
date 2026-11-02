import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/utils/notification_list.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with NotificationListState {
  IconData _iconForType(String type) {
    switch (type) {
      case 'order': return Icons.receipt_long_rounded;
      case 'payment': return Icons.check_circle_rounded;
      case 'chat': return Icons.chat_bubble_rounded;
      case 'delivery': return Icons.local_shipping_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'order': return AppColors.primary;
      case 'payment': return AppColors.success;
      case 'chat': return AppColors.teal;
      case 'delivery': return AppColors.warning;
      default: return AppColors.info;
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
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notifications', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 17)),
                          if (unreadCount > 0)
                            Text('$unreadCount unread', style: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (unreadCount > 0)
                      GestureDetector(
                        onTap: markAllRead,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text('Mark all read', style: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w500)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: loading
                    ? Center(child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2))
                    : loadError != null
                    ? LoadError(error: loadError!, onRetry: retryLoad)
                    : notifications.isEmpty
                        ? const EmptyState(
                            icon: Icons.notifications_off_outlined,
                            title: 'No notifications yet',
                            subtitle: 'You will be notified about orders, payments and more',
                          )
                        : RefreshIndicator(
                            color: AppColors.primaryLight,
                            backgroundColor: AppColors.card,
                            onRefresh: loadNotifications,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              itemCount: notifications.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final n = notifications[i];
                                final color = _colorForType(n.type);
                                return GestureDetector(
                                  onTap: () => markRead(n),
                                  child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: n.isRead ? AppColors.card : AppColors.primary.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: n.isRead ? AppColors.divider : AppColors.primary.withValues(alpha: 0.35),
                                      width: n.isRead ? 1 : 1.5,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: color.withValues(alpha: 0.12),
                                          ),
                                          child: Icon(_iconForType(n.type), color: color, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      n.title,
                                                      style: GoogleFonts.poppins(
                                                        color: AppColors.textPrimary,
                                                        fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w600,
                                                        fontSize: 13,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (!n.isRead)
                                                        Container(
                                                          width: 7,
                                                          height: 7,
                                                          margin: const EdgeInsets.only(right: 6),
                                                          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                                        ),
                                                      Text(_timeAgo(n.createdAt), style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 10)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(n.body, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  n.type[0].toUpperCase() + n.type.substring(1),
                                                  style: GoogleFonts.poppins(color: color, fontSize: 9, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ));
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

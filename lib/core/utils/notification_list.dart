import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/notification_service.dart';
import '../widgets/shared_widgets.dart';

// The state of a notification list, shared by the customer and tailor
// notification screens. Reading a notification marks it read on the server.
mixin NotificationListState<T extends StatefulWidget> on State<T> {
  List<NotificationModel> notifications = [];
  bool loading = true;
  Object? loadError;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      final list = await NotificationService().getNotifications();
      if (mounted) setState(() { notifications = list; loading = false; loadError = null; });
    } catch (e) {
      if (mounted) setState(() { loading = false; loadError = e; });
    }
  }

  void retryLoad() {
    setState(() => loading = true);
    loadNotifications();
  }

  Future<void> markRead(NotificationModel n) async {
    if (n.isRead) return;
    try {
      await NotificationService().markRead(n.id);
      if (mounted) setState(() => notifications = [for (final m in notifications) m.id == n.id ? m.asRead() : m]);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await NotificationService().markAllRead();
      if (mounted) setState(() => notifications = notifications.map((n) => n.asRead()).toList());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }
}

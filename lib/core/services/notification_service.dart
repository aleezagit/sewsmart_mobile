// ─── Notification Service ─────────────────────────────────────────────────────
// Shared by the customer and tailor apps. The API reads the user from
// the token, so no user id is passed. Throws [ApiException] on failure.

import '../api/api_client.dart';
import '../models/app_models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final ApiClient _api = ApiClient();

  // GET /api/notifications
  Future<List<NotificationModel>> getNotifications() async =>
      listOf(await _api.get('/notifications'), NotificationModel.fromJson);

  // PUT /api/notifications/:id/read
  Future<void> markRead(String id) => _api.put('/notifications/$id/read');

  // PUT /api/notifications/read-all
  Future<void> markAllRead() => _api.put('/notifications/read-all');
}

// ─── Support Service ──────────────────────────────────────────────────────────
// Disputes about an order and reports about content. Customers and tailors both
// use it, and the admin panel works through what it creates (Disputes screen,
// Reports tab of the Content screen). Throws [ApiException] on failure.

import '../api/api_client.dart';
import '../models/app_models.dart';

class SupportService {
  static final SupportService _instance = SupportService._();
  factory SupportService() => _instance;
  SupportService._();

  final ApiClient _api = ApiClient();

  // ── Disputes ────────────────────────────────────────────────────────────────
  // POST /api/disputes. The customer or the tailor of the order raises it, and
  // an order has at most one open dispute.
  Future<DisputeModel> raiseDispute({
    required String orderId, required String reason, required String details,
  }) async =>
      DisputeModel.fromJson(objectOf(await _api.post('/disputes', {
        'order_id': orderId, 'reason': reason, 'details': details.trim(),
      })));

  // GET /api/disputes. Disputes on the signed-in user's orders, whoever raised them.
  Future<List<DisputeModel>> getMyDisputes() async =>
      listOf(await _api.get('/disputes'), DisputeModel.fromJson);

  // ── Content reports ─────────────────────────────────────────────────────────
  // POST /api/content-reports. targetType is design, review or profile.
  Future<void> reportContent({
    required String targetType, required String targetId,
    required String reason, String? details,
  }) =>
      _api.post('/content-reports', {
        'target_type': targetType, 'target_id': targetId,
        'reason': reason.trim(), 'details': details?.trim() ?? '',
      });
}

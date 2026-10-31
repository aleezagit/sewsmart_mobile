// ─── Admin Service ────────────────────────────────────────────────────────────
// Every admin panel call to the backend (docs/API.md, section 4). Screens call
// this service only. Loads throw AdminApiException when they fail, and
// actions return false; either way AdminApi has already shown the message.

import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../models/admin_models.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final AdminApi _api = AdminApi();

  // Runs an action and says whether it worked.
  Future<bool> _act(Future<dynamic> Function() request) async {
    try {
      await request();
      return true;
    } on AdminApiException {
      return false;
    }
  }

  // ── Session ───────────────────────────────────────────────
  String _name = 'Admin';
  String _email = '';
  String get adminName => _name;
  String get adminEmail => _email;

  // Signs back in with the session saved by the last login. False when there
  // is none. An expired one is caught by the first request.
  Future<bool> restoreSession() async {
    final session = await _api.restoreSession();
    if (session == null) return false;
    _name = session.name;
    _email = session.email;
    return true;
  }

  // ── Auth ──────────────────────────────────────────────────
  // POST /api/admin/auth/login
  Future<AdminAuthResult> login(String email, String password) async {
    try {
      final json = objectOf(await _api.post('/auth/login', {'email': email.trim(), 'password': password}, true));
      final admin = objectOf(json['admin']);
      _name = admin['name'] ?? 'Admin';
      _email = admin['email'] ?? '';
      await _api.saveSession(json['token'] as String, _name, _email);
      return AdminAuthResult(success: true, name: _name, email: _email);
    } on AdminApiException catch (e) {
      return AdminAuthResult(success: false, error: e.message);
    }
  }

  // POST /api/admin/auth/logout. The local session ends even when it fails.
  Future<void> logout() async {
    await _act(() => _api.post('/auth/logout'));
    await _api.clearSession();
  }

  // PUT /api/admin/auth/password
  Future<bool> changePassword(String currentPassword, String newPassword) =>
      _act(() => _api.put('/auth/password', {'current_password': currentPassword, 'new_password': newPassword}));

  // ── Dashboard ─────────────────────────────────────────────
  // GET /api/admin/stats
  Future<PlatformStats> getStats() async => PlatformStats.fromJson(objectOf(await _api.get('/stats')));

  // GET /api/admin/revenue/monthly?months=
  Future<List<MonthlyRevenue>> getMonthlyRevenue({int months = 6}) async =>
      listOf(await _api.get('/revenue/monthly', query: {'months': months}), MonthlyRevenue.fromJson);

  // GET /api/admin/tailors/top?limit=
  Future<List<TopTailor>> getTopTailors({int limit = 5}) async =>
      listOf(await _api.get('/tailors/top', query: {'limit': limit}), TopTailor.fromJson);

  // GET /api/admin/orders?limit=
  Future<List<AdminOrder>> getRecentOrders({int limit = 5}) async =>
      listOf(await _api.get('/orders', query: {'limit': limit}), AdminOrder.fromJson);

  // ── Customers ─────────────────────────────────────────────
  // GET /api/admin/users
  Future<List<AdminUser>> getUsers() async => listOf(await _api.get('/users'), AdminUser.fromJson);

  // PUT /api/admin/users/:id/status
  Future<bool> suspendUser(String id, {required bool suspend}) =>
      _act(() => _api.put('/users/$id/status', {'status': suspend ? 'suspended' : 'active'}));

  // DELETE /api/admin/users/:id
  Future<bool> deleteUser(String id) => _act(() => _api.delete('/users/$id'));

  // ── Tailors ───────────────────────────────────────────────
  // GET /api/admin/tailors
  Future<List<AdminTailor>> getTailors() async => listOf(await _api.get('/tailors'), AdminTailor.fromJson);

  // PUT /api/admin/tailors/:id/status
  Future<bool> suspendTailor(String id, {required bool suspend}) =>
      _act(() => _api.put('/tailors/$id/status', {'status': suspend ? 'suspended' : 'active'}));

  // DELETE /api/admin/tailors/:id
  Future<bool> removeTailor(String id) => _act(() => _api.delete('/tailors/$id'));

  // ── Verifications ─────────────────────────────────────────
  // GET /api/admin/verifications?status=pending
  Future<List<PendingVerification>> getPendingVerifications() async =>
      listOf(await _api.get('/verifications', query: {'status': 'pending'}), PendingVerification.fromJson);

  // GET /api/admin/verifications
  Future<List<PendingVerification>> getAllVerifications() async =>
      listOf(await _api.get('/verifications'), PendingVerification.fromJson);

  // PUT /api/admin/verifications/:id/approve
  Future<bool> approveVerification(String id) => _act(() => _api.put('/verifications/$id/approve'));

  // PUT /api/admin/verifications/:id/reject
  Future<bool> rejectVerification(String id, String reason) =>
      _act(() => _api.put('/verifications/$id/reject', {'reason': reason}));

  // POST /api/admin/verifications/:id/request-documents
  Future<bool> requestMoreDocuments(String id) => _act(() => _api.post('/verifications/$id/request-documents'));

  // ── Orders ────────────────────────────────────────────────
  // GET /api/admin/orders. The screen filters its tabs locally.
  Future<List<AdminOrder>> getAllOrders() async => listOf(await _api.get('/orders'), AdminOrder.fromJson);

  // PUT /api/admin/orders/:id/cancel
  Future<bool> cancelOrder(String id) => _act(() => _api.put('/orders/$id/cancel'));

  // ── Payments ──────────────────────────────────────────────
  // GET /api/admin/payments
  Future<List<AdminPayment>> getAllPayments() async => listOf(await _api.get('/payments'), AdminPayment.fromJson);

  // GET /api/admin/payments/summary
  Future<PaymentSummary> getPaymentSummary() async =>
      PaymentSummary.fromJson(objectOf(await _api.get('/payments/summary')));

  // ── Disputes ──────────────────────────────────────────────
  // GET /api/admin/disputes
  Future<List<AdminDispute>> getDisputes() async => listOf(await _api.get('/disputes'), AdminDispute.fromJson);

  // PUT /api/admin/disputes/:id/resolve. resolution is the label the screen
  // shows: Refund, Warning or Dismiss.
  Future<bool> resolveDispute(String id, String resolution, String notes) =>
      _act(() => _api.put('/disputes/$id/resolve', {'resolution': resolution.toLowerCase(), 'notes': notes}));

  // ── Reports ───────────────────────────────────────────────
  static const _ranges = {'Today': 'today', 'This Week': 'thisWeek', 'This Month': 'thisMonth', 'Custom': 'custom'};

  // GET /api/admin/reports?range=&from=&to=. range is the chip label, and
  // Custom needs [dates].
  Future<AdminReport> getReports({String range = 'This Month', DateTimeRange? dates}) async {
    String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final json = await _api.get('/reports', query: {
      'range': _ranges[range] ?? 'thisMonth',
      if (dates != null) 'from': day(dates.start),
      if (dates != null) 'to': day(dates.end),
    });
    return AdminReport.fromJson(objectOf(json), range);
  }

  // ── Content moderation ────────────────────────────────────
  // GET /api/admin/content/designs
  Future<List<ContentItem>> getDesigns() async => listOf(await _api.get('/content/designs'), ContentItem.fromJson);

  // DELETE /api/admin/content/designs/:id
  Future<bool> removeDesign(String id) => _act(() => _api.delete('/content/designs/$id'));

  // GET /api/admin/content/reviews
  Future<List<ReviewItem>> getReviews() async => listOf(await _api.get('/content/reviews'), ReviewItem.fromJson);

  // DELETE /api/admin/content/reviews/:id
  Future<bool> removeReview(String id) => _act(() => _api.delete('/content/reviews/$id'));

  // GET /api/admin/content/reports
  Future<List<FlaggedItem>> getFlaggedContent() async =>
      listOf(await _api.get('/content/reports'), FlaggedItem.fromJson);

  static const _actions = {'Remove Content': 'remove', 'Issue Warning': 'warn', 'Dismiss Report': 'dismiss'};

  // PUT /api/admin/content/reports/:id/resolve. action is "Remove Content",
  // "Issue Warning" or "Dismiss Report".
  Future<bool> resolveFlaggedContent(String id, String action) =>
      _act(() => _api.put('/content/reports/$id/resolve', {'action': _actions[action] ?? 'dismiss'}));

  // ── Settings ──────────────────────────────────────────────
  // GET /api/admin/settings
  Future<AdminSettings> getSettings() async => AdminSettings.fromJson(objectOf(await _api.get('/settings')));

  // PUT /api/admin/settings
  Future<bool> updateSettings(AdminSettings settings) => _act(() => _api.put('/settings', settings.toJson()));

  // POST /api/admin/settings/categories
  Future<bool> addCategory(String name) => _act(() => _api.post('/settings/categories', {'name': name.trim()}));

  // DELETE /api/admin/settings/categories/:name
  Future<bool> removeCategory(String name) =>
      _act(() => _api.delete('/settings/categories/${Uri.encodeComponent(name)}'));
}

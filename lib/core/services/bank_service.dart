// ─── Bank Service ─────────────────────────────────────────────────────────────
// The banks a customer or tailor can pick when adding an account. The list
// comes from the server, so every app shows the same banks. Throws
// [ApiException] on failure.

import '../api/api_client.dart';

class BankService {
  static final BankService _instance = BankService._();
  factory BankService() => _instance;
  BankService._();

  final ApiClient _api = ApiClient();

  // GET /api/banks
  Future<List<String>> getBanks() async => List<String>.from(await _api.get('/banks') as List);
}

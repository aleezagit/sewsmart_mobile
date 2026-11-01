// ─── Payout Service ───────────────────────────────────────────────────────────
// Payout accounts and withdrawals for tailors. The API reads the
// user from the token, so no user id is passed. Throws [ApiException] on failure.

import '../api/api_client.dart';
import '../models/app_models.dart';
import '../utils/validators.dart';

class PayoutService {
  static final PayoutService _instance = PayoutService._();
  factory PayoutService() => _instance;
  PayoutService._();

  final ApiClient _api = ApiClient();

  // The backend's minimum payout.
  static const double minimumWithdrawal = 500;

  // ── Payout accounts ─────────────────────────────────────────────────────────
  // GET /api/payout-accounts
  Future<List<PayoutAccount>> getPayoutAccounts() async =>
      listOf(await _api.get('/payout-accounts'), PayoutAccount.fromJson);

  // POST /api/payout-accounts
  // type is jazzCash, easyPaisa or bank. bankName (from BankService) and iban
  // apply to bank only.
  Future<PayoutAccount> addPayoutAccount({
    required String type, required String accountNumber,
    required String accountName, String? bankName, String? iban,
  }) async =>
      PayoutAccount.fromJson(objectOf(await _api.post('/payout-accounts', {
        'type': type,
        'account_number': type == 'bank' ? accountNumber.trim() : Validators.normalizeMobile(accountNumber),
        'account_name': accountName,
        'bank_name': ?bankName, 'iban': ?iban,
      })));

  // PUT /api/payout-accounts/:id/default
  Future<void> setDefaultPayoutAccount(String id) => _api.put('/payout-accounts/$id/default');

  // DELETE /api/payout-accounts/:id. The default account cannot be removed.
  Future<void> removePayoutAccount(String id) => _api.delete('/payout-accounts/$id');

  // ── Withdrawals ─────────────────────────────────────────────────────────────
  // GET /api/withdrawals
  Future<List<WithdrawalModel>> getWithdrawals() async =>
      listOf(await _api.get('/withdrawals'), WithdrawalModel.fromJson);

  // POST /api/withdrawals. Leave amount out to withdraw the whole available balance.
  Future<WithdrawalModel> requestWithdrawal({double? amount}) async =>
      WithdrawalModel.fromJson(objectOf(await _api.post('/withdrawals', {'amount': ?amount})));
}

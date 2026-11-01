import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/app_models.dart';
import '../../../core/services/bank_service.dart';
import '../../../core/services/payout_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/shared_widgets.dart';

// The tailor's payout accounts: the saved list with set-default and remove,
// and the button that adds one (docs/API.md, 3.12).
class PayoutAccountsSection extends StatefulWidget {
  const PayoutAccountsSection({super.key});

  @override
  State<PayoutAccountsSection> createState() => _PayoutAccountsSectionState();
}

class _PayoutAccountsSectionState extends State<PayoutAccountsSection> {
  List<PayoutAccount> _accounts = [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final accounts = await PayoutService().getPayoutAccounts();
      if (mounted) setState(() { _accounts = accounts; _loading = false; _loadError = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
    }
  }

  // Runs a change, then loads the list again so it shows what the server kept.
  Future<void> _change(Future<void> Function() action, String done) async {
    try {
      await action();
      await _load();
      if (mounted) showMessage(context, done);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _remove(PayoutAccount account) {
    if (account.isDefault) {
      showMessage(context, 'Choose another default account before removing this one', success: false);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Account?',
            style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'Remove "${_kindOf(account.type).name}" from your payout accounts?',
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _change(() => PayoutService().removePayoutAccount(account.id), 'Account removed');
            },
            child: Text('Remove', style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => _AddPayoutSheet(
        onAdded: (account) async {
          await _load();
          if (mounted) showMessage(context, '${_kindOf(account.type).name} added!');
        },
      ),
    );
  }

  // "HBL — 0123-4567890 · Shahid" for a bank, the number for a wallet.
  String _detailOf(PayoutAccount a) {
    final number = a.type == 'bank' ? '${a.bankName ?? 'Bank'} — ${a.accountNumber}' : a.accountNumber;
    return a.accountName.isEmpty ? number : '$number  ·  ${a.accountName}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.account_balance_outlined, color: AppColors.textMuted, size: 14),
          const SizedBox(width: 6),
          Text('PAYOUT ACCOUNTS',
              style: GoogleFonts.poppins(
                  color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 10),
        if (_loading)
          Center(child: Padding(
            padding: const EdgeInsets.all(20),
            child: CircularProgressIndicator(color: AppColors.tealLight, strokeWidth: 2),
          ))
        else if (_loadError != null)
          LoadError(error: _loadError!, onRetry: () {
            setState(() => _loading = true);
            _load();
          })
        else if (_accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Add an account to receive your payouts.',
                style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12)),
          ),
        ..._accounts.map(_tile),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _openAddSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.teal, AppColors.tealLight]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: AppColors.teal.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Add Payout Account',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(PayoutAccount a) {
    final kind = _kindOf(a.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: a.isDefault ? AppColors.tealLight.withValues(alpha: 0.55) : AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: kind.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(kind.icon, color: kind.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(kind.name,
                      style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  if (a.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Default',
                          style: GoogleFonts.poppins(color: AppColors.tealLight, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                Text(_detailOf(a), style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.cardAlt,
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'default') {
                _change(() => PayoutService().setDefaultPayoutAccount(a.id), '${kind.name} set as default payout');
              }
              if (v == 'remove') _remove(a);
            },
            itemBuilder: (_) => [
              if (!a.isDefault)
                PopupMenuItem(
                  value: 'default',
                  child: Row(children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    Text('Set as Default', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 13)),
                  ]),
                ),
              PopupMenuItem(
                value: 'remove',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Text('Remove', style: GoogleFonts.poppins(color: AppColors.error, fontSize: 13)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add payout sheet ───────────────────────────────────────────────────────────
class _AddPayoutSheet extends StatefulWidget {
  final Future<void> Function(PayoutAccount account) onAdded;
  const _AddPayoutSheet({required this.onAdded});

  @override
  State<_AddPayoutSheet> createState() => _AddPayoutSheetState();
}

class _AddPayoutSheetState extends State<_AddPayoutSheet> {
  static const _types = ['jazzCash', 'easyPaisa', 'bank'];

  String _type = 'jazzCash';
  final _numCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  // The bank is chosen from the server's list.
  List<String> _banks = [];
  String? _bank;
  final _ibanCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  bool get _isBank => _type == 'bank';

  @override
  void dispose() {
    _numCtrl.dispose();
    _nameCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await BankService().getBanks();
      if (mounted) setState(() => _banks = banks);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _save() async {
    final problem = Validators.payoutAccountProblem(
      isBank: _isBank,
      number: _numCtrl.text,
      holderName: _nameCtrl.text,
      bankName: _bank ?? '',
      iban: _ibanCtrl.text,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final account = await PayoutService().addPayoutAccount(
        type: _type,
        accountNumber: _numCtrl.text.trim(),
        accountName: _nameCtrl.text.trim(),
        bankName: _isBank ? _bank : null,
        iban: _isBank && _ibanCtrl.text.trim().isNotEmpty ? _ibanCtrl.text.replaceAll(' ', '').toUpperCase() : null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onAdded(account);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                width: 4, height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [AppColors.teal, AppColors.tealLight]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text('Add Payout Account',
                  style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
            ]),
            const SizedBox(height: 20),
            Text('ACCOUNT TYPE',
                style: GoogleFonts.poppins(
                    color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            const SizedBox(height: 10),
            Row(
              children: _types.map(_kindOf).map((t) {
                final selected = _type == t.type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { _type = t.type; _error = null; }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? t.color.withValues(alpha: 0.18) : AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? t.color : AppColors.divider),
                      ),
                      child: Column(children: [
                        Icon(t.icon, color: t.color, size: 20),
                        const SizedBox(height: 4),
                        Text(t.name,
                            style: GoogleFonts.poppins(
                                color: selected ? t.color : AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
                            textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            if (_isBank) ...[
              DropdownButtonFormField<String>(
                initialValue: _bank,
                isExpanded: true,
                dropdownColor: AppColors.cardAlt,
                decoration: InputDecoration(
                  hintText: _banks.isEmpty ? 'Loading banks...' : 'Select your bank',
                  prefixIcon: Icon(Icons.account_balance_rounded, color: AppColors.textMuted, size: 20),
                ),
                style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14),
                items: [for (final bank in _banks) DropdownMenuItem(value: bank, child: Text(bank))],
                onChanged: (bank) => setState(() { _bank = bank; _error = null; }),
              ),
              const SizedBox(height: 10),
              AppTextField(hint: 'Account Number', icon: Icons.tag_rounded, ctrl: _numCtrl, keyboard: TextInputType.number),
              const SizedBox(height: 10),
              AppTextField(hint: 'IBAN (Optional)', icon: Icons.credit_score_rounded, ctrl: _ibanCtrl),
            ] else
              AppTextField(
                hint: 'Mobile Number (e.g. 0300-1234567)',
                icon: Icons.phone_android_rounded,
                ctrl: _numCtrl,
                keyboard: TextInputType.phone,
              ),
            const SizedBox(height: 10),
            AppTextField(hint: 'Account Holder Name', icon: Icons.person_rounded, ctrl: _nameCtrl),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12)),
            ],
            const SizedBox(height: 22),
            GradientButton(
              text: 'Add Account',
              colors: [AppColors.teal, AppColors.tealLight],
              loading: _saving,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// The label, icon and colour of a payout account type from the API.
({String type, String name, IconData icon, Color color}) _kindOf(String type) => switch (type) {
  'jazzCash' => (type: type, name: 'JazzCash', icon: Icons.account_balance_wallet_rounded, color: AppColors.warning),
  'easyPaisa' => (type: type, name: 'EasyPaisa', icon: Icons.mobile_friendly_rounded, color: AppColors.success),
  _ => (type: type, name: 'Bank Account', icon: Icons.account_balance_rounded, color: AppColors.info),
};

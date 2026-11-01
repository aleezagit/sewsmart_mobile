import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../services/customer_service.dart';
import 'payment_methods_screen.dart';

// The customer's wallet, which orders and gifts are paid from. Money is added
// from a saved bank account, mobile wallet or card, for an amount the customer
// chooses, and every change is listed below.
class WalletScreen extends StatefulWidget {
  // An amount to fill in, such as what an order still needs.
  final int? suggestedAmount;
  const WalletScreen({super.key, this.suggestedAmount});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  WalletModel? _wallet;
  List<SavedPaymentMethod> _accounts = [];
  String? _accountId;
  late final TextEditingController _amountCtrl = TextEditingController(text: widget.suggestedAmount?.toString() ?? '');
  bool _loading = true;
  bool _adding = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final service = CustomerService();
      final results = await Future.wait([service.getWallet(), service.getPaymentMethods()]);
      if (!mounted) return;
      final accounts = results[1] as List<SavedPaymentMethod>;
      setState(() {
        _wallet = results[0] as WalletModel;
        _accounts = accounts;
        // Keep the choice if it still exists, else the default account.
        if (!accounts.any((a) => a.id == _accountId)) {
          _accountId = (accounts.where((a) => a.isDefault).firstOrNull ?? accounts.firstOrNull)?.id;
        }
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
    }
  }

  Future<void> _addMoney() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (_accountId == null) {
      showMessage(context, 'Add a bank account first', success: false);
      return;
    }
    if (amount == null || amount < 100) {
      showMessage(context, 'Enter a whole amount of at least Rs 100', success: false);
      return;
    }
    setState(() => _adding = true);
    try {
      final wallet = await CustomerService().topUpWallet(methodId: _accountId!, amount: amount);
      if (!mounted) return;
      setState(() { _wallet = wallet; _amountCtrl.clear(); });
      showMessage(context, 'Rs ${_money(amount.toDouble())} added to your wallet');
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _adding = false);
  }

  Future<void> _manageAccounts() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        orb1: AppColors.purpleOrb,
        orb2: AppColors.tealOrb,
        child: SafeArea(
          child: Column(
            children: [
              const SewAppBar(title: 'My Wallet', subtitle: 'Orders and gifts are paid from here'),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2))
                    : _loadError != null
                        ? LoadError(error: _loadError!, onRetry: () {
                            setState(() => _loading = true);
                            _load();
                          })
                        : RefreshIndicator(
                            color: AppColors.primaryLight,
                            backgroundColor: AppColors.card,
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                              children: [
                                _balanceCard(_wallet!.balance),
                                const SizedBox(height: 24),
                                _addMoneySection(),
                                const SizedBox(height: 28),
                                _history(_wallet!.transactions),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _balanceCard(double balance) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, const Color(0xFF6D28D9)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wallet balance', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Rs ${_money(balance)}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30)),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _addMoneySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add money', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Choose the account the money comes from.', style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        if (_accounts.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            onTap: _manageAccounts,
            child: Row(
              children: [
                Icon(Icons.account_balance_rounded, color: AppColors.primaryLight, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Add a bank account, mobile wallet or card to add money.',
                      style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
              ],
            ),
          )
        else ...[
          for (final account in _accounts) _accountTile(account),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _manageAccounts,
              icon: Icon(Icons.add_rounded, color: AppColors.primaryLight, size: 18),
              label: Text('Add or remove accounts', style: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 4),
          AppTextField(
            hint: 'Amount in Rs (at least 100)',
            icon: Icons.payments_outlined,
            ctrl: _amountCtrl,
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 14),
          GradientButton(text: 'Add Money', loading: _adding, onTap: _addMoney),
        ],
      ],
    );
  }

  Widget _accountTile(SavedPaymentMethod account) {
    final selected = account.id == _accountId;
    return GestureDetector(
      onTap: () => setState(() => _accountId = account.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(_iconFor(account.type), color: selected ? AppColors.primaryLight : AppColors.textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_nameFor(account.type), style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(account.type == 'card' ? '•••• ${account.detail}' : account.detail,
                      style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _history(List<WalletTransaction> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent activity', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          Text('Nothing yet. Add money to get started.', style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12)),
        for (final t in transactions)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(t.amount >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
                    color: t.amount >= 0 ? AppColors.success : AppColors.warning, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                      Text('${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}  ·  Balance Rs ${_money(t.balanceAfter)}',
                          style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
                Text('${t.amount >= 0 ? '+' : '-'} Rs ${_money(t.amount.abs())}',
                    style: GoogleFonts.poppins(
                        color: t.amount >= 0 ? AppColors.success : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  static IconData _iconFor(String type) => switch (type) {
    'bank' => Icons.account_balance_rounded,
    'card' => Icons.credit_card_rounded,
    _ => Icons.phone_android_rounded,
  };

  static String _nameFor(String type) => switch (type) {
    'jazzCash' => 'JazzCash',
    'easyPaisa' => 'EasyPaisa',
    'bank' => 'Bank account',
    _ => 'Card',
  };
}

// 12500 as "12,500".
String _money(double value) =>
    value.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../services/customer_service.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<SavedPaymentMethod> _methods = [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final methods = await CustomerService().getPaymentMethods();
      if (mounted) setState(() { _methods = methods; _loading = false; _loadError = null; });
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

  void _setDefault(SavedPaymentMethod m) => _change(
        () => CustomerService().setDefaultPaymentMethod(m.id),
        '${_kindOf(m.type).name} set as default',
      );

  void _removeMethod(SavedPaymentMethod m) {
    if (m.isDefault) {
      showMessage(context, 'Choose another default method before removing this one', success: false);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Method?',
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'Remove "${_kindOf(m.type).name}" from your saved methods?',
          style: GoogleFonts.poppins(
              color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _change(() => CustomerService().removePaymentMethod(m.id), 'Payment method removed');
            },
            child: Text('Remove',
                style: GoogleFonts.poppins(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => _AddMethodSheet(
        onAdd: (type, number, name) async {
          await CustomerService().addPaymentMethod(
            type: type,
            accountNumber: type == 'cashOnDelivery' ? null : number,
            accountName: type == 'cashOnDelivery' ? null : name,
          );
          await _load();
          if (mounted) showMessage(context, '${_kindOf(type).name} added!');
        },
      ),
    );
  }

  // The text under a saved method.
  String _detailOf(SavedPaymentMethod m) {
    if (m.type == 'cashOnDelivery') return 'Pay when received';
    if (m.type == 'card') return '•••• ${m.detail}';
    return m.accountName.isEmpty ? m.detail : '${m.detail} · ${m.accountName}';
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
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      if (_loading)
                        Center(child: Padding(padding: const EdgeInsets.all(30), child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2)))
                      else if (_loadError != null)
                        LoadError(error: _loadError!, onRetry: () {
                          setState(() => _loading = true);
                          _load();
                        })
                      else
                        _buildMethodsList(),
                      const SizedBox(height: 14),
                      _buildAddButton(),
                      const SizedBox(height: 24),
                      _buildAcceptedMethods(),
                      const SizedBox(height: 24),
                      _buildSecurityNote(),
                      const SizedBox(height: 30),
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

  // ── App Bar ──────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.textPrimary, size: 20),
          ),
          Icon(Icons.credit_card_rounded,
              color: AppColors.primaryLight, size: 22),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Payment Methods',
                style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            Text('Manage your payment options',
                style: GoogleFonts.poppins(
                    color: AppColors.textMuted, fontSize: 11)),
          ]),
        ],
      ),
    );
  }

  // ── Methods List ─────────────────────────────────────────────────────────────
  Widget _buildMethodsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.textMuted, size: 14),
          const SizedBox(width: 6),
          Text('SAVED METHODS',
              style: GoogleFonts.poppins(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 10),
        if (_methods.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No saved methods yet', style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12)),
          ),
        ..._methods.map((m) {
          final kind = _kindOf(m.type);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: m.isDefault
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: kind.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(kind.icon, color: kind.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(kind.name,
                            style: GoogleFonts.poppins(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        if (m.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Default',
                                style: GoogleFonts.poppins(
                                    color: AppColors.primaryLight,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                      Text(_detailOf(m),
                          style: GoogleFonts.poppins(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: AppColors.cardAlt,
                  icon: Icon(Icons.more_vert_rounded,
                      color: AppColors.textMuted, size: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'default') _setDefault(m);
                    if (v == 'remove') _removeMethod(m);
                  },
                  itemBuilder: (_) => [
                    if (!m.isDefault)
                      PopupMenuItem(
                        value: 'default',
                        child: Row(children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: AppColors.success, size: 16),
                          const SizedBox(width: 8),
                          Text('Set as Default',
                              style: GoogleFonts.poppins(
                                  color: AppColors.textPrimary,
                                  fontSize: 13)),
                        ]),
                      ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded,
                            color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Text('Remove',
                            style: GoogleFonts.poppins(
                                color: AppColors.error, fontSize: 13)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Add Button ───────────────────────────────────────────────────────────────
  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _openAddSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Add Payment Method',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── Accepted Methods ─────────────────────────────────────────────────────────
  Widget _buildAcceptedMethods() {
    final methods = ['jazzCash', 'easyPaisa', 'bank', 'card'].map(_kindOf).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.textMuted, size: 14),
          const SizedBox(width: 6),
          Text('ACCEPTED PAYMENTS',
              style: GoogleFonts.poppins(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 12),
        Row(
          children: methods.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < methods.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: m.color.withValues(alpha: 0.2)),
                ),
                child: Column(children: [
                  Icon(m.icon, color: m.color, size: 20),
                  const SizedBox(height: 4),
                  Text(m.name,
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center),
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Security Note ────────────────────────────────────────────────────────────
  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(Icons.lock_outline_rounded,
            color: AppColors.success, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Your payment information is encrypted and securely stored.',
            style: GoogleFonts.poppins(
                color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
      ]),
    );
  }
}

// ── Add Method Bottom Sheet ────────────────────────────────────────────────────
class _AddMethodSheet extends StatefulWidget {
  // Saves the method. type is the API value, such as jazzCash. Throws with a
  // message to show when the server refuses it.
  final Future<void> Function(String type, String number, String name) onAdd;
  const _AddMethodSheet({required this.onAdd});

  @override
  State<_AddMethodSheet> createState() => _AddMethodSheetState();
}

class _AddMethodSheetState extends State<_AddMethodSheet> {
  String _selectedType = 'jazzCash';
  final _numberCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  // Returns what to fix before the method can be added, or null.
  String? _check() {
    if (!_needsDetail) return null;
    final number = _numberCtrl.text.trim();
    switch (_selectedType) {
      case 'jazzCash':
      case 'easyPaisa':
        if (!Validators.isMobile(number)) return 'Enter the wallet mobile number, e.g. 0300-1234567';
      case 'bank':
        if (Validators.digitsOnly(number).length < 8) return 'Enter the full account number or IBAN';
      case 'card':
        if (Validators.digitsOnly(number).length != 16) return 'Enter the 16-digit card number';
    }
    if (_nameCtrl.text.trim().isEmpty) return 'Enter the account holder name';
    return null;
  }

  static const _types = ['jazzCash', 'easyPaisa', 'bank', 'cashOnDelivery', 'card'];

  bool get _needsDetail => _selectedType != 'cashOnDelivery';

  // The server keeps only the last four digits of a card.
  Future<void> _save() async {
    final problem = _check();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onAdd(_selectedType, _numberCtrl.text.trim(), _nameCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = '$e'; });
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primary, AppColors.teal]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text('Add Payment Method',
                  style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17)),
            ]),
            const SizedBox(height: 20),
            Text('PAYMENT TYPE',
                style: GoogleFonts.poppins(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types
                  .map(_kindOf)
                  .map((t) => GestureDetector(
                        onTap: () => setState(() {
                          _selectedType = t.type;
                          _error = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedType == t.type
                                ? t.color.withValues(alpha: 0.18)
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _selectedType == t.type
                                  ? t.color
                                  : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(t.icon, color: t.color, size: 14),
                              const SizedBox(width: 6),
                              Text(t.name,
                                  style: GoogleFonts.poppins(
                                      color: _selectedType == t.type
                                          ? t.color
                                          : AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: _selectedType == t.type
                                          ? FontWeight.w600
                                          : FontWeight.normal)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
            if (_needsDetail) ...[
              const SizedBox(height: 18),
              AppTextField(
                hint: 'Account Number / Mobile Number',
                icon: Icons.tag_rounded,
                ctrl: _numberCtrl,
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              AppTextField(
                hint: 'Account Holder Name',
                icon: Icons.person_rounded,
                ctrl: _nameCtrl,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12)),
            ],
            const SizedBox(height: 22),
            GradientButton(
              text: 'Add Method',
              loading: _saving,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payment kinds ──────────────────────────────────────────────────────────────

class _AcceptedMethod {
  final String type, name;
  final IconData icon;
  final Color color;
  const _AcceptedMethod(this.type, this.name, this.icon, this.color);
}

// The label, icon and colour of a payment type from the API.
_AcceptedMethod _kindOf(String type) => switch (type) {
  'jazzCash' => _AcceptedMethod(type, 'JazzCash', Icons.account_balance_wallet_rounded, AppColors.warning),
  'easyPaisa' => _AcceptedMethod(type, 'EasyPaisa', Icons.mobile_friendly_rounded, AppColors.success),
  'bank' => _AcceptedMethod(type, 'Bank Transfer', Icons.account_balance_rounded, AppColors.info),
  'card' => _AcceptedMethod(type, 'Debit / Credit Card', Icons.credit_card_rounded, AppColors.primary),
  _ => _AcceptedMethod(type, 'Cash on Delivery', Icons.payments_rounded, AppColors.teal),
};

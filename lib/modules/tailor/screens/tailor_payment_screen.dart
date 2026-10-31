import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/payout_service.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../services/tailor_service.dart';
import '../widgets/payout_accounts.dart';

class TailorPaymentScreen extends StatefulWidget {
  const TailorPaymentScreen({super.key});
  @override
  State<TailorPaymentScreen> createState() => _TailorPaymentScreenState();
}

class _TailorPaymentScreenState extends State<TailorPaymentScreen> {
  TailorEarnings? _earnings;
  List<WithdrawalModel> _withdrawals = [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        TailorService().getEarnings(AuthService().currentUser?.id ?? ''),
        PayoutService().getWithdrawals(),
      ]);
      if (!mounted) return;
      setState(() {
        _earnings = results[0] as TailorEarnings;
        _withdrawals = results[1] as List<WithdrawalModel>;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
    }
  }

  List<WithdrawalModel> get _paid => _withdrawals.where((w) => w.status == 'paid').toList();

  static String _rs(double value) => 'Rs ${value.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        orb1: AppColors.tealOrb,
        orb2: AppColors.purpleOrb,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      if (_loading)
                        Center(child: Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.tealLight, strokeWidth: 2)))
                      else if (_loadError != null)
                        LoadError(error: _loadError!, onRetry: () {
                          setState(() => _loading = true);
                          _load();
                        })
                      else
                        _buildEarningsSummary(),
                      const SizedBox(height: 22),
                      const PayoutAccountsSection(),
                      const SizedBox(height: 26),
                      _buildSupportedMethods(),
                      const SizedBox(height: 26),
                      _buildPayoutHistory(),
                      const SizedBox(height: 26),
                      _buildScheduleNote(),
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

  // ── App bar ───────────────────────────────────────────────────────────────
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
          Icon(Icons.account_balance_wallet_rounded,
              color: AppColors.tealLight, size: 22),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Payment Methods',
                style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            Text('Manage your payout accounts',
                style: GoogleFonts.poppins(
                    color: AppColors.textMuted, fontSize: 11)),
          ]),
        ],
      ),
    );
  }

  // ── Earnings summary ──────────────────────────────────────────────────────
  Widget _buildEarningsSummary() {
    final cards = [
      _EarnCard('Total Earned', _rs(_earnings?.total ?? 0), AppColors.success,
          Icons.payments_rounded),
      _EarnCard('Available', _rs(_earnings?.available ?? 0), AppColors.warning,
          Icons.hourglass_top_rounded),
      _EarnCard('Last Payout', _paid.isEmpty ? '-' : _rs(_paid.first.amount), AppColors.info,
          Icons.check_circle_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded,
              color: AppColors.tealLight, size: 15),
          const SizedBox(width: 6),
          Text('EARNINGS OVERVIEW',
              style: GoogleFonts.poppins(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 12),
        Row(
          children: cards.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < cards.length - 1 ? 10 : 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(c.icon, color: c.color, size: 18),
                    const SizedBox(height: 8),
                    Text(c.amount,
                        style: GoogleFonts.poppins(
                            color: c.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text(c.label,
                        style: GoogleFonts.poppins(
                            color: AppColors.textMuted,
                            fontSize: 9,
                            height: 1.4)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Supported methods ─────────────────────────────────────────────────────
  Widget _buildSupportedMethods() {
    final supported = [
      _SupportItem('JazzCash',     Icons.account_balance_wallet_rounded, AppColors.warning),
      _SupportItem('EasyPaisa',    Icons.mobile_friendly_rounded,        AppColors.success),
      _SupportItem('Bank Account', Icons.account_balance_rounded,        AppColors.info),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.textMuted, size: 14),
          const SizedBox(width: 6),
          Text('SUPPORTED METHODS',
              style: GoogleFonts.poppins(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 12),
        Row(
          children: supported.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < supported.length - 1 ? 10 : 0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: s.color.withValues(alpha: 0.2)),
                ),
                child: Column(children: [
                  Icon(s.icon, color: s.color, size: 22),
                  const SizedBox(height: 6),
                  Text(s.name,
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 10,
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

  // ── Payout history ────────────────────────────────────────────────────────
  Widget _buildPayoutHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.history_rounded,
              color: AppColors.textMuted, size: 14),
          const SizedBox(width: 6),
          Text('PAYOUT HISTORY',
              style: GoogleFonts.poppins(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 12),
        if (_paid.isEmpty)
          Text('No payouts yet.', style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12)),
        ..._paid.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_monthYear(p.paidAt ?? p.requestedAt),
                      style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text('Paid out to default account',
                      style: GoogleFonts.poppins(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Text(_rs(p.amount),
                style: GoogleFonts.poppins(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
        )),
      ],
    );
  }

  // ── Schedule note ─────────────────────────────────────────────────────────
  Widget _buildScheduleNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.schedule_rounded,
                color: AppColors.tealLight, size: 15),
            const SizedBox(width: 8),
            Text('Payout Schedule',
                style: GoogleFonts.poppins(
                    color: AppColors.tealLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              '• Payouts are processed every Monday\n'
              '• Minimum payout amount: Rs 500\n'
              '• Platform fee: ${_earnings?.commissionRate ?? '-'}% per completed order\n'
              '• Transfers take 1–2 business days',
              style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _SupportItem {
  final String name;
  final IconData icon;
  final Color color;
  const _SupportItem(this.name, this.icon, this.color);
}

class _EarnCard {
  final String label, amount;
  final Color color;
  final IconData icon;
  const _EarnCard(this.label, this.amount, this.color, this.icon);
}

// "May 2026".
String _monthYear(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.year}';
}

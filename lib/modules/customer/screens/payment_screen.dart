import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/app_refresh.dart';
import '../../../navigation/app_router.dart';
import '../services/customer_service.dart';
import 'wallet_screen.dart';

// Pays an order from the customer's wallet. The amount is the order's price,
// which the customer confirms. A wallet with too little money offers to add
// what is missing.
class PaymentScreen extends StatefulWidget {
  final double amount;
  final String orderId;
  const PaymentScreen({super.key, required this.amount, required this.orderId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  double? _balance;
  Object? _loadError;
  bool _loading = false;
  bool _success = false;
  PaymentModel? _paymentResult;
  late AnimationController _successCtrl;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _successScale = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
    _loadBalance();
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final wallet = await CustomerService().getWallet();
      if (mounted) setState(() { _balance = wallet.balance; _loadError = null; });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  double get _missing => widget.amount - (_balance ?? 0);

  Future<void> _addMoney() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WalletScreen(suggestedAmount: _missing.ceil())),
    );
    if (mounted) _loadBalance();
  }

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      final payment = await CustomerService().makePayment(orderId: widget.orderId);
      if (!mounted) return;
      setState(() { _loading = false; _success = true; _paymentResult = payment; });
      AppRefresh.ordersChanged();
      _successCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
      _loadBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: _success ? _buildSuccessView() : _buildPaymentView(),
        ),
      ),
    );
  }

  Widget _buildPaymentView() {
    final balance = _balance;
    return Column(
      children: [
        const SewAppBar(title: 'Payment'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAmountCard(),
                const SizedBox(height: 24),
                Text('Pay from wallet', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                if (_loadError != null)
                  LoadError(error: _loadError!, onRetry: () {
                    setState(() => _loadError = null);
                    _loadBalance();
                  })
                else if (balance == null)
                  Center(child: Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2)))
                else ...[
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _receiptRow('Wallet balance', 'Rs ${balance.toInt()}'),
                        _receiptRow('Order amount', 'Rs ${widget.amount.toInt()}'),
                        Divider(color: AppColors.divider),
                        _receiptRow(
                          balance >= widget.amount ? 'Left after paying' : 'You need to add',
                          'Rs ${(balance >= widget.amount ? balance - widget.amount : _missing).ceil()}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (balance >= widget.amount)
                    GradientButton(
                      text: 'Pay Rs ${widget.amount.toInt()}',
                      onTap: _pay,
                      loading: _loading,
                      colors: [AppColors.success, const Color(0xFF16A34A)],
                    )
                  else
                    GradientButton(text: 'Add Rs ${_missing.ceil()} to Wallet', onTap: _addMoney),
                ],
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, color: AppColors.textMuted, size: 14),
                      const SizedBox(width: 4),
                      Text('The amount is your order price', style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount Due', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text('Rs ${widget.amount.toInt()}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28)),
              const SizedBox(height: 4),
              Text('Order #${widget.orderId}', style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
            ],
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.payments_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),
            ScaleTransition(
              scale: _successScale,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.success, AppColors.teal]),
                  boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.45), blurRadius: 30)],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 54),
              ),
            ),
            const SizedBox(height: 28),
            Text('Payment Successful!', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Rs ${widget.amount.toInt()} paid successfully', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 30),
            GlassCard(
              padding: const EdgeInsets.all(18),
              borderColor: AppColors.success.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Receipt', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      Icon(Icons.receipt_long_rounded, color: AppColors.success, size: 18),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(color: AppColors.divider),
                  const SizedBox(height: 8),
                  _receiptRow('Order ID', widget.orderId),
                  if (_paymentResult != null) _receiptRow('Transaction ID', _paymentResult!.transactionId ?? 'N/A'),
                  _receiptRow('Amount', 'Rs ${widget.amount.toInt()}'),
                  _receiptRow('Paid from', 'Wallet'),
                  _receiptRow('Status', 'Completed'),
                  _receiptRow('Date', _formattedDate()),
                ],
              ),
            ),
            const SizedBox(height: 28),
            GradientButton(
              text: 'Back to Orders',
              // Open the Orders tab, where the paid order now shows.
              onTap: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainNavigationCustomer(initialIndex: 2)),
                (route) => false,
              ),
              colors: [AppColors.success, Color(0xFF16A34A)],
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Text('Go Back', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12)),
        Text(value, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 12)),
      ],
    ),
  );

  String _formattedDate() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }
}

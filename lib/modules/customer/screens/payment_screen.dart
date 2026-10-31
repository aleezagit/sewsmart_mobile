import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/app_refresh.dart';
import '../../../core/utils/validators.dart';
import '../../../navigation/app_router.dart';
import '../services/customer_service.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String orderId;
  const PaymentScreen({super.key, required this.amount, required this.orderId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  PaymentMethod _selectedMethod = PaymentMethod.jazzCash;
  // Loaded the first time Bank Transfer is picked.
  Future<Map<String, String>>? _bankAccount;
  final _mobileCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _cardNameCtrl = TextEditingController();
  final _cardNumCtrl = TextEditingController();
  final _cardExpCtrl = TextEditingController();
  final _cardCvcCtrl = TextEditingController();
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
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _accountCtrl.dispose();
    _otpCtrl.dispose();
    _cardNameCtrl.dispose();
    _cardNumCtrl.dispose();
    _cardExpCtrl.dispose();
    _cardCvcCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  // Checks the boxes of the chosen method. Returns what to fix, or null.
  String? _checkFields() {
    switch (_selectedMethod) {
      case PaymentMethod.jazzCash:
      case PaymentMethod.easyPaisa:
        if (!Validators.isMobile(_mobileCtrl.text)) {
          return 'Enter your wallet mobile number, e.g. 0300-1234567';
        }
        if (!RegExp(r'^\d{4,6}$').hasMatch(_otpCtrl.text.trim())) {
          return 'Enter the 4 to 6 digit PIN or OTP';
        }
        return null;
      case PaymentMethod.bank:
        if (_accountCtrl.text.trim().length < 4) {
          return 'Enter the transaction reference from your bank transfer';
        }
        return null;
      case PaymentMethod.card:
        if (_cardNameCtrl.text.trim().isEmpty) return "Enter the cardholder's name";
        if (Validators.digitsOnly(_cardNumCtrl.text).length != 16) {
          return 'Enter the 16-digit card number';
        }
        if (!_isValidExpiry(_cardExpCtrl.text)) return 'Enter a valid expiry date as MM/YY';
        if (!RegExp(r'^\d{3,4}$').hasMatch(_cardCvcCtrl.text.trim())) return 'Enter the CVC from the back of the card';
        return null;
    }
  }

  // MM/YY that has not passed. A card works until the end of its expiry month.
  bool _isValidExpiry(String value) {
    final match = RegExp(r'^(\d{2})\s*/\s*(\d{2})$').firstMatch(value.trim());
    if (match == null) return false;
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return false;
    final now = DateTime.now();
    return year > now.year || (year == now.year && month >= now.month);
  }

  Future<void> _pay() async {
    final problem = _checkFields();
    if (problem != null) {
      showMessage(context, problem, success: false);
      return;
    }
    // Clear an earlier "fix this field" message once the details are fine.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() { _loading = true; });
    try {
      final payment = await CustomerService().makePayment(orderId: widget.orderId, method: _selectedMethod);
      if (!mounted) return;
      setState(() { _loading = false; _success = true; _paymentResult = payment; });
      AppRefresh.ordersChanged();
      _successCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
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
                Text('Payment Method', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                _buildMethodSelector(),
                const SizedBox(height: 20),
                _buildMethodFields(),
                const SizedBox(height: 28),
                GradientButton(
                  text: 'Pay Rs ${widget.amount.toInt()}',
                  onTap: _pay,
                  loading: _loading,
                  colors: [AppColors.success, Color(0xFF16A34A)],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, color: AppColors.textMuted, size: 14),
                      const SizedBox(width: 4),
                      Text('Payments are secured and encrypted', style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
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

  Widget _buildMethodSelector() {
    final methods = [
      {'method': PaymentMethod.jazzCash, 'label': 'JazzCash', 'icon': Icons.phone_android_rounded, 'color': AppColors.error},
      {'method': PaymentMethod.easyPaisa, 'label': 'EasyPaisa', 'icon': Icons.account_balance_wallet_rounded, 'color': AppColors.success},
      {'method': PaymentMethod.bank, 'label': 'Bank Transfer', 'icon': Icons.account_balance_rounded, 'color': AppColors.info},
      {'method': PaymentMethod.card, 'label': 'Card', 'icon': Icons.credit_card_rounded, 'color': AppColors.primary},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: methods.map((m) {
        final method = m['method'] as PaymentMethod;
        final selected = _selectedMethod == method;
        final color = m['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedMethod = method;
            if (method == PaymentMethod.bank) _bankAccount ??= CustomerService().getBankAccount();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.12) : AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? color : AppColors.divider, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(m['icon'] as IconData, color: selected ? color : AppColors.textMuted, size: 20),
                const SizedBox(width: 8),
                Text(m['label'] as String, style: GoogleFonts.poppins(color: selected ? color : AppColors.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, fontSize: 11)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMethodFields() {
    switch (_selectedMethod) {
      case PaymentMethod.jazzCash:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('JazzCash Details', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            AppTextField(ctrl: _mobileCtrl, hint: 'JazzCash mobile number', icon: Icons.phone_android_rounded, keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            AppTextField(ctrl: _otpCtrl, hint: 'JazzCash PIN / OTP', icon: Icons.pin_outlined, keyboard: TextInputType.number),
          ],
        );
      case PaymentMethod.easyPaisa:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EasyPaisa Details', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            AppTextField(ctrl: _mobileCtrl, hint: 'EasyPaisa mobile number', icon: Icons.phone_android_rounded, keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            AppTextField(ctrl: _otpCtrl, hint: 'EasyPaisa MPIN', icon: Icons.pin_outlined, keyboard: TextInputType.number),
          ],
        );
      case PaymentMethod.bank:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bank Transfer Details', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(14),
              borderColor: AppColors.info.withValues(alpha: 0.3),
              child: FutureBuilder<Map<String, String>>(
                future: _bankAccount,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('${snapshot.error}', style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12));
                  }
                  final bank = snapshot.data;
                  if (bank == null) {
                    return Center(child: CircularProgressIndicator(color: AppColors.info, strokeWidth: 2));
                  }
                  return Column(
                    children: [
                      _bankRow('Bank', bank['bank_name'] ?? ''),
                      _bankRow('Account Title', bank['account_title'] ?? ''),
                      _bankRow('Account #', bank['account_number'] ?? ''),
                      if ((bank['iban'] ?? '').isNotEmpty) _bankRow('IBAN', bank['iban']!),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(ctrl: _accountCtrl, hint: 'Your transaction reference / screenshot no.', icon: Icons.receipt_long_outlined),
          ],
        );
      case PaymentMethod.card:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Card Details', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            AppTextField(ctrl: _cardNameCtrl, hint: 'Cardholder Name', icon: Icons.person_outline),
            const SizedBox(height: 12),
            AppTextField(ctrl: _cardNumCtrl, hint: 'Card Number (16 digits)', icon: Icons.credit_card_rounded, keyboard: TextInputType.number),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: AppTextField(ctrl: _cardExpCtrl, hint: 'MM/YY', icon: Icons.calendar_today_outlined)),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(ctrl: _cardCvcCtrl, hint: 'CVC', icon: Icons.lock_outline_rounded, keyboard: TextInputType.number)),
              ],
            ),
          ],
        );
    }
  }

  Widget _bankRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
        Text(value, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 11)),
      ],
    ),
  );

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
                  _receiptRow('Method', _methodLabel()),
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

  String _methodLabel() {
    switch (_selectedMethod) {
      case PaymentMethod.jazzCash: return 'JazzCash';
      case PaymentMethod.easyPaisa: return 'EasyPaisa';
      case PaymentMethod.bank: return 'Bank Transfer';
      case PaymentMethod.card: return 'Card';
    }
  }

  String _formattedDate() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }
}

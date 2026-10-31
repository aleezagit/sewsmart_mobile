import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/app_refresh.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/utils/validators.dart';
import '../services/customer_service.dart';
import 'payment_screen.dart';

class PlaceOrderScreen extends StatefulWidget {
  final TailorModel tailor;
  // A garment to select when the screen opens, such as the one a tailor
  // pinned in a live stream.
  final String? initialGarment;
  const PlaceOrderScreen({super.key, required this.tailor, this.initialGarment});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  int _currentStep = 1;
  GarmentPricing? _selectedGarment;
  // The tailor's own price list.
  List<GarmentPricing> _garments = [];
  bool _loadingGarments = true;
  Object? _garmentsError;

  // Step 2 – measurements
  final _chestCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _hipCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _shoulderCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  // A picture of the design, sent once the order is placed.
  XFile? _designRef;

  // Step 3 – summary
  final _couponCtrl = TextEditingController();
  // The coupon the server accepted. The server works out the discount again
  // when the order is placed.
  CouponResult? _coupon;
  bool _checkingCoupon = false;

  bool get _couponApplied => _coupon != null;
  // Kept as a share of the price, so the discount follows the garment when the
  // customer goes back and picks another one after applying the coupon.
  double get _discountRate => (_coupon?.discountPercent ?? 0) / 100;

  bool _loading = false;
  String? _errorMsg;

  double get _discount => (_selectedGarment?.price ?? 0) * _discountRate;
  double get _total => (_selectedGarment?.price ?? 0) - _discount;

  @override
  void initState() {
    super.initState();
    _loadGarments();
  }

  Future<void> _loadGarments() async {
    setState(() { _loadingGarments = true; _garmentsError = null; });
    try {
      final garments = await CustomerService().getTailorGarments(widget.tailor.id);
      if (!mounted) return;
      setState(() {
        _garments = garments;
        _selectedGarment ??= garments.where((g) => g.garment == widget.initialGarment).firstOrNull;
        _loadingGarments = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loadingGarments = false; _garmentsError = e; });
    }
  }

  @override
  void dispose() {
    _chestCtrl.dispose();
    _waistCtrl.dispose();
    _hipCtrl.dispose();
    _lengthCtrl.dispose();
    _shoulderCtrl.dispose();
    _notesCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  void _next() {
    setState(() => _errorMsg = null);
    if (_currentStep == 1) {
      if (_selectedGarment == null) {
        setState(() => _errorMsg = 'Please select a garment type');
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      final fields = [_chestCtrl, _waistCtrl, _hipCtrl, _lengthCtrl, _shoulderCtrl];
      if (fields.any((c) => c.text.trim().isEmpty)) {
        setState(() => _errorMsg = 'Please fill in all measurements');
        return;
      }
      if (fields.any((c) => Validators.positiveNumber(c.text) == null)) {
        setState(() => _errorMsg = 'Enter each measurement as a number of inches, e.g. 36');
        return;
      }
      setState(() => _currentStep = 3);
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty || _checkingCoupon) return;
    setState(() => _checkingCoupon = true);
    try {
      final result = await CustomerService().validateCoupon(
        code: code, amount: _selectedGarment?.price ?? 0, tailorId: widget.tailor.id,
      );
      if (!mounted) return;
      setState(() => _coupon = result.valid ? result : null);
      showMessage(context, result.message, success: result.valid);
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _checkingCoupon = false);
  }

  Future<void> _pickDesignRef() async {
    if (_designRef != null) {
      setState(() => _designRef = null);
      return;
    }
    final image = await pickImage(context, title: 'Design reference');
    if (image != null && mounted) setState(() => _designRef = image);
  }

  Future<void> _proceedToPayment() async {
    setState(() { _loading = true; _errorMsg = null; });
    final service = CustomerService();
    OrderModel order;
    try {
      order = await service.placeOrder(
        tailorId: widget.tailor.id,
        garmentType: _selectedGarment!.garment,
        measurements: 'Chest ${_chestCtrl.text.trim()}, Waist ${_waistCtrl.text.trim()}, '
            'Hips ${_hipCtrl.text.trim()}, Length ${_lengthCtrl.text.trim()}, '
            'Shoulder ${_shoulderCtrl.text.trim()} (in)',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        couponCode: _coupon?.code,
      );
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = '$e'; });
      return;
    }
    // The new order shows on the Orders tab and in the chat list.
    AppRefresh.ordersChanged();
    final designRef = _designRef;
    if (designRef != null) {
      try {
        order = await service.uploadDesignReference(order.id, designRef);
      } catch (e) {
        // The order stands without the picture, so say so and carry on.
        if (mounted) showMessage(context, 'Order placed, but the design picture was not sent: $e', success: false);
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(amount: order.amount, orderId: order.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              SewAppBar(title: 'Place Order', subtitle: widget.tailor.name),
              _buildProgressBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentStep == 1) _buildStep1(),
                      if (_currentStep == 2) _buildStep2(),
                      if (_currentStep == 3) _buildStep3(),
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: AppColors.error, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_errorMsg!, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12))),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_currentStep < 3)
                        GradientButton(text: 'Continue', onTap: _next)
                      else
                        GradientButton(text: 'Proceed to Payment', onTap: _proceedToPayment, loading: _loading),
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

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: List.generate(3, (i) {
          final step = i + 1;
          final isActive = step == _currentStep;
          final isDone = step < _currentStep;
          return Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: isDone ? () => setState(() => _currentStep = step) : null,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isActive || isDone
                          ? LinearGradient(colors: [AppColors.primary, AppColors.primaryLight])
                          : null,
                      color: isActive || isDone ? null : AppColors.card,
                      border: Border.all(color: isActive || isDone ? AppColors.primary : AppColors.divider, width: 1.5),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                          : Text('$step', style: GoogleFonts.poppins(color: isActive ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ),
                ),
                if (i < 2) Expanded(child: Container(height: 2, color: isDone ? AppColors.primary : AppColors.divider)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Garment', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        Text('Choose the garment type to stitch', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        if (_loadingGarments)
          Center(child: Padding(padding: const EdgeInsets.all(30), child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2)))
        else if (_garmentsError != null)
          LoadError(error: _garmentsError!, onRetry: _loadGarments)
        else if (_garments.isEmpty)
          const EmptyState(icon: Icons.checkroom_outlined, title: 'This tailor has no prices listed yet'),
        ..._garments.map((g) {
          final selected = _selectedGarment?.garment == g.garment;
          return GestureDetector(
            onTap: () => setState(() => _selectedGarment = g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.cardAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.checkroom_outlined, color: selected ? AppColors.primaryLight : AppColors.textMuted, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.garment, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                        Row(
                          children: [
                            Icon(Icons.schedule_outlined, color: AppColors.textMuted, size: 12),
                            const SizedBox(width: 4),
                            Text(g.estimatedTime, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Rs ${g.price.toInt()}', style: GoogleFonts.poppins(color: selected ? AppColors.primaryLight : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      if (selected) Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Measurements', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        Text('Enter your measurements in inches', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _measureField(_chestCtrl, 'Chest', Icons.straighten_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _measureField(_waistCtrl, 'Waist', Icons.straighten_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _measureField(_hipCtrl, 'Hip', Icons.straighten_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _measureField(_lengthCtrl, 'Length', Icons.height_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        _measureField(_shoulderCtrl, 'Shoulder', Icons.straighten_rounded),
        const SizedBox(height: 16),
        AppTextField(ctrl: _notesCtrl, hint: 'Fabric notes (optional)', icon: Icons.notes_rounded, maxLines: 3),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickDesignRef,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _designRef != null ? AppColors.primary.withValues(alpha: 0.1) : AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _designRef != null ? AppColors.primary : AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(
                  _designRef != null ? Icons.add_photo_alternate_rounded : Icons.add_photo_alternate_outlined,
                  color: _designRef != null ? AppColors.primaryLight : AppColors.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upload Design Reference', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                      Text(_designRef != null ? '${_designRef!.name} · tap to remove' : 'Image or sketch of your design (optional)',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                if (_designRef != null) Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _measureField(TextEditingController ctrl, String label, IconData icon) {
    return AppTextField(
      ctrl: ctrl, hint: label, label: label, icon: icon,
      keyboard: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order Summary', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _summaryRow('Tailor', widget.tailor.name),
              _summaryRow('Garment', _selectedGarment!.garment),
              _summaryRow('Est. Time', _selectedGarment!.estimatedTime),
              _summaryRow('Chest', '${_chestCtrl.text}"'),
              _summaryRow('Waist', '${_waistCtrl.text}"'),
              _summaryRow('Hip', '${_hipCtrl.text}"'),
              _summaryRow('Length', '${_lengthCtrl.text}"'),
              _summaryRow('Shoulder', '${_shoulderCtrl.text}"'),
              if (_notesCtrl.text.isNotEmpty) _summaryRow('Notes', _notesCtrl.text),
              if (_designRef != null) _summaryRow('Design Ref', 'Attached'),
              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: AppColors.divider)),
              _summaryRow('Subtotal', 'Rs ${_selectedGarment!.price.toInt()}'),
              if (_couponApplied) _summaryRow('Discount', '- Rs ${_discount.toInt()}', color: AppColors.success),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Rs ${_total.toInt()}', style: GoogleFonts.poppins(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Have a coupon?', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppTextField(ctrl: _couponCtrl, hint: 'Coupon code', icon: Icons.local_offer_outlined),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _applyCoupon,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _checkingCoupon
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Apply', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
          Text(value, style: GoogleFonts.poppins(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 12)),
        ],
      ),
    );
  }
}

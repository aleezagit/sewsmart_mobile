import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/support_service.dart';

// A customer or a tailor reports a problem with one order. The admin panel
// lists it on the Disputes screen and resolves it. Pops with the new dispute.
class RaiseDisputeScreen extends StatefulWidget {
  final OrderModel order;
  // True when the tailor raises it from the tailor app.
  final bool byTailor;
  const RaiseDisputeScreen({super.key, required this.order, this.byTailor = false});

  @override
  State<RaiseDisputeScreen> createState() => _RaiseDisputeScreenState();
}

class _RaiseDisputeScreenState extends State<RaiseDisputeScreen> {
  static const _customerReasons = [
    'Wrong measurements',
    'Poor stitching quality',
    'Late delivery',
    'Damaged or stained',
    'Not as described',
    'Payment or refund',
    'Other',
  ];
  static const _tailorReasons = [
    'Customer not responding',
    'Delivery refused',
    'Wrong measurements given',
    'Payment problem',
    'Abusive behaviour',
    'Other',
  ];

  final _detailsCtrl = TextEditingController();
  String? _reason;
  bool _submitting = false;
  DisputeModel? _submitted;

  List<String> get _reasons => widget.byTailor ? _tailorReasons : _customerReasons;
  Color get _accent => widget.byTailor ? AppColors.teal : AppColors.primary;
  Color get _accentLight => widget.byTailor ? AppColors.tealLight : AppColors.primaryLight;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String text, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text, style: GoogleFonts.poppins()), backgroundColor: color));
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) {
      _showMessage('Choose what went wrong', AppColors.warning);
      return;
    }
    final details = _detailsCtrl.text.trim();
    if (details.length < 20) {
      _showMessage('Describe the problem in at least 20 characters', AppColors.warning);
      return;
    }
    setState(() => _submitting = true);
    try {
      final dispute = await SupportService().raiseDispute(
        orderId: widget.order.id,
        reason: reason,
        details: details,
      );
      if (mounted) setState(() { _submitting = false; _submitted = dispute; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage('$e', AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitted = _submitted;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        orb1: widget.byTailor ? AppColors.tealOrb : AppColors.purpleOrb,
        orb2: widget.byTailor ? AppColors.purpleOrb : AppColors.pinkOrb,
        child: SafeArea(
          child: Column(
            children: [
              SewAppBar(title: 'Report a Problem', subtitle: widget.order.id),
              Expanded(child: submitted == null ? _buildForm() : _buildSubmitted(submitted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String text) => Text(
        text,
        style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
      );

  Widget _buildForm() {
    final order = widget.order;
    final otherParty = widget.byTailor ? 'Customer: ${order.customerName}' : 'Tailor: ${order.tailorName}';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_long_rounded, color: _accentLight, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.garmentType,
                        style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        '$otherParty · Rs ${order.amount.toInt()}',
                        style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: order.statusLabel, color: _accentLight),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _title('What went wrong?'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons
                .map((reason) => ChoicePill(
                      label: reason,
                      selected: _reason == reason,
                      color: _accentLight,
                      onTap: () => setState(() => _reason = reason),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          _title('Describe the problem'),
          const SizedBox(height: 10),
          AppTextField(
            ctrl: _detailsCtrl,
            hint: widget.byTailor
                ? 'What happened, and what should support do about it?'
                : 'What happened, and what would you like: a fix, a refund or something else?',
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.support_agent_rounded, color: AppColors.info, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.byTailor
                        ? 'SewSmart support reviews every dispute within 48 hours and hears both sides. You will get a notification with the decision.'
                        : 'SewSmart support reviews every dispute within 48 hours and hears both sides. An approved refund goes back to the payment method you used.',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          GradientButton(
            text: 'Submit',
            onTap: _submit,
            loading: _submitting,
            colors: [_accent, _accentLight],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitted(DisputeModel dispute) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_accent, AppColors.success]),
              ),
              child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'Dispute ${dispute.id} Submitted',
              style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Support will look into "${dispute.reason}" on order ${widget.order.id} within 48 hours. '
              'You will get a notification when it is resolved.',
              style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GradientButton(
              text: 'Done',
              colors: [_accent, _accentLight],
              onTap: () => Navigator.pop(context, dispute),
            ),
          ],
        ),
      ),
    );
  }
}

// The state of a dispute already raised on an order, shown on the order screen
// in place of the "Report a problem" link. Both the customer and the tailor
// see it, whoever raised it.
class DisputeStatusCard extends StatelessWidget {
  final DisputeModel dispute;
  const DisputeStatusCard({super.key, required this.dispute});

  static String _resolutionLabel(String? resolution) {
    switch (resolution) {
      case 'refund':
        return 'refund issued';
      case 'warning':
        return 'warning issued';
      default:
        return 'closed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = dispute.isOpen;
    final color = open ? AppColors.warning : AppColors.success;
    final title = open
        ? 'Dispute ${dispute.id} is open'
        : 'Dispute ${dispute.id} resolved: ${_resolutionLabel(dispute.resolution)}';
    final body = open
        ? '${dispute.reason}. Support will reply within 48 hours.'
        : (dispute.resolutionNotes ?? dispute.reason);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(open ? Icons.support_agent_rounded : Icons.task_alt_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(body, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

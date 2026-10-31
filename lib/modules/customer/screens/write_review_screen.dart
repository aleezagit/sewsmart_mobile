import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/app_refresh.dart';
import '../services/customer_service.dart';

// The customer rates the tailor of a delivered or completed order, once per
// order. Pops with true when the review was sent.
class WriteReviewScreen extends StatefulWidget {
  final OrderModel order;
  const WriteReviewScreen({super.key, required this.order});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  static const _ratingLabels = ['Tap a star to rate', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];
  static const _tagOptions = [
    'Perfect fitting',
    'Neat stitching',
    'On-time delivery',
    'Good communication',
    'Worth the price',
  ];

  final _commentCtrl = TextEditingController();
  final Set<String> _tags = {};
  int _rating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  // The written text, then the picked tags on their own line.
  String get _comment {
    final text = _commentCtrl.text.trim();
    final tags = _tagOptions.where(_tags.contains).join(' · ');
    if (tags.isEmpty) return text;
    return text.isEmpty ? tags : '$text\n$tags';
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      showMessage(context, 'Tap the stars to rate your tailor', success: false);
      return;
    }
    setState(() => _submitting = true);
    try {
      await CustomerService().submitReview(orderId: widget.order.id, rating: _rating, comment: _comment);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showError(context, e);
      return;
    }
    if (!mounted) return;
    AppRefresh.ordersChanged();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              SewAppBar(title: 'Rate Your Tailor', subtitle: order.id),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderCard(order),
                      const SizedBox(height: 26),
                      _buildStars(),
                      const SizedBox(height: 26),
                      _sectionTitle('What went well?'),
                      const SizedBox(height: 10),
                      _buildTags(),
                      const SizedBox(height: 24),
                      _sectionTitle('Write a review (optional)'),
                      const SizedBox(height: 10),
                      AppTextField(
                        ctrl: _commentCtrl,
                        hint: 'Tell other customers about the fitting, stitching and delivery',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.public_rounded, color: AppColors.textMuted, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Your review appears on ${order.tailorName}'s profile with your first name.",
                              style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      GradientButton(text: 'Submit Review', onTap: _submit, loading: _submitting),
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

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
      );

  Widget _buildOrderCard(OrderModel order) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.teal]),
            ),
            child: Center(
              child: Text(
                initialsOf(order.tailorName, max: 1),
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.tailorName,
                  style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  '${order.garmentType} · Rs ${order.amount.toInt()}',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          StatusBadge(label: order.statusLabel, color: AppColors.success),
        ],
      ),
    );
  }

  Widget _buildStars() {
    return Center(
      child: Column(
        children: [
          Text(
            'How was your order?',
            style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedScale(
                    scale: filled ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled ? AppColors.gold : AppColors.textMuted,
                      size: 44,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _ratingLabels[_rating],
            style: GoogleFonts.poppins(
              color: _rating == 0 ? AppColors.textMuted : AppColors.gold,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tagOptions.map((tag) {
        final selected = _tags.contains(tag);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _tags.remove(tag);
            } else {
              _tags.add(tag);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? AppColors.primaryLight : AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check_rounded, color: AppColors.primaryLight, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  tag,
                  style: GoogleFonts.poppins(
                    color: selected ? AppColors.primaryLight : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

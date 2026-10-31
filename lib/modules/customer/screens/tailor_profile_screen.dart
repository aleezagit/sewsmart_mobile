import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/auth_service.dart';
import '../../support/screens/report_content_sheet.dart';
import '../../tailor/screens/tailor_chat_screen.dart';
import '../services/customer_service.dart';
import 'place_order_screen.dart';

class TailorProfileScreen extends StatefulWidget {
  final TailorModel tailor;
  const TailorProfileScreen({super.key, required this.tailor});

  @override
  State<TailorProfileScreen> createState() => _TailorProfileScreenState();
}

class _TailorProfileScreenState extends State<TailorProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<PortfolioItem> _portfolio = [];
  List<GarmentPricing> _pricing = [];
  List<ReviewModel> _reviews = [];
  bool _loading = true;
  Object? _loadError;

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    final id = widget.tailor.id;
    try {
      final service = CustomerService();
      final results = await Future.wait([
        service.getTailorPortfolio(id),
        service.getTailorGarments(id),
        service.getTailorReviews(id),
      ]);
      if (!mounted) return;
      setState(() {
        _portfolio = results[0] as List<PortfolioItem>;
        _pricing = results[1] as List<GarmentPricing>;
        _reviews = results[2] as List<ReviewModel>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
    }
  }

  // Shown in a tab while it loads or when loading failed, otherwise null.
  Widget? _tabPlaceholder() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2));
    if (_loadError != null) return LoadError(error: _loadError!, onRetry: _load);
    return null;
  }

  // Chats belong to an order, so open the chat of the customer's latest order
  // with this tailor. Without an order there is nobody to chat with yet.
  Future<void> _openChat() async {
    final List<OrderModel> orders;
    try {
      orders = await CustomerService().getMyOrders();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    final withTailor = orders.where((o) => o.tailorId == widget.tailor.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (withTailor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Place an order to chat with ${widget.tailor.name}', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TailorChatScreen(contactName: widget.tailor.name, orderId: withTailor.first.id),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tailor;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(t),
              _buildStatRow(t),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPortfolio(),
                    _buildPricingTab(),
                    _buildReviewsTab(),
                  ],
                ),
              ),
              _buildBottomBar(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(TailorModel t) {
    return Stack(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.teal.withValues(alpha: 0.2)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.share_outlined, color: AppColors.textPrimary, size: 20),
                    onPressed: () => showComingSoon(context, 'Sharing tailor profiles'),
                  ),
                  IconButton(
                    icon: Icon(Icons.bookmark_border_rounded, color: AppColors.textPrimary, size: 20),
                    onPressed: () => showComingSoon(context, 'Saving tailors'),
                  ),
                  PopupMenuButton<String>(
                    color: AppColors.cardAlt,
                    icon: Icon(Icons.more_vert_rounded, color: AppColors.textPrimary, size: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (_) => showReportContentSheet(
                      context,
                      targetType: 'profile',
                      targetId: t.id,
                      itemLabel: t.name,
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined, color: AppColors.error, size: 16),
                            const SizedBox(width: 8),
                            Text('Report profile', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.teal],
                      ),
                      border: Border.all(color: AppColors.bg, width: 3),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 16)],
                    ),
                    child: Center(
                      child: Text(t.userAvatar, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(t.name, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17), overflow: TextOverflow.ellipsis),
                            ),
                            if (t.isVerified) ...[
                              const SizedBox(width: 5),
                              Icon(Icons.verified_rounded, color: AppColors.info, size: 16),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, color: AppColors.textMuted, size: 13),
                            const SizedBox(width: 2),
                            Text(t.city, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        StarRating(rating: t.rating, size: 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(t.bio, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: t.specialties.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                  ),
                  child: Text(s, style: GoogleFonts.poppins(color: AppColors.tealLight, fontSize: 10)),
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(TailorModel t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          _StatBox(label: 'Orders', value: '${t.totalOrders}', icon: Icons.receipt_long_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          _StatBox(label: 'Rating', value: '${t.rating}', icon: Icons.star_rounded, color: AppColors.gold),
          const SizedBox(width: 10),
          _StatBox(label: 'From', value: 'Rs ${t.priceFrom.toInt()}', icon: Icons.payments_outlined, color: AppColors.teal),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
        tabs: const [
          Tab(text: 'Portfolio'),
          Tab(text: 'Pricing'),
          Tab(text: 'Reviews'),
        ],
      ),
    );
  }

  Widget _buildPortfolio() {
    final placeholder = _tabPlaceholder();
    if (placeholder != null) return placeholder;
    if (_portfolio.isEmpty) {
      return const EmptyState(icon: Icons.photo_library_outlined, title: 'No portfolio samples yet');
    }
    final colors = [
      [AppColors.primary, AppColors.primaryLight],
      [AppColors.teal, AppColors.tealLight],
      [AppColors.secondary, const Color(0xFFEC4899)],
      [AppColors.warning, AppColors.gold],
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      [AppColors.info, const Color(0xFF60A5FA)],
    ];
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0,
      ),
      itemCount: _portfolio.length,
      itemBuilder: (context, i) {
        final item = _portfolio[i];
        final label = item.title.isEmpty ? 'Design ${i + 1}' : item.title;
        final fallback = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_outlined, color: Colors.white.withValues(alpha: 0.7), size: 32),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        );
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors[i % colors.length],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.imageUrl.isEmpty)
                  fallback
                else
                  Image.network(item.imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
                // A sample can be reported to the admin.
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.flag_outlined, color: Colors.white.withValues(alpha: 0.9), size: 18),
                    onPressed: () => showReportContentSheet(
                      context,
                      targetType: 'design',
                      targetId: item.id,
                      itemLabel: 'Design by ${widget.tailor.name}: $label',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPricingTab() {
    final placeholder = _tabPlaceholder();
    if (placeholder != null) return placeholder;
    if (_pricing.isEmpty) {
      return const EmptyState(icon: Icons.checkroom_outlined, title: 'No prices listed yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _pricing.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = _pricing[i];
        return GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.checkroom_outlined, color: AppColors.primaryLight, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.garment, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    Row(
                      children: [
                        Icon(Icons.schedule_outlined, color: AppColors.textMuted, size: 12),
                        const SizedBox(width: 4),
                        Text(p.estimatedTime, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              Text('Rs ${p.price.toInt()}', style: GoogleFonts.poppins(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    final placeholder = _tabPlaceholder();
    if (placeholder != null) return placeholder;
    if (_reviews.isEmpty) {
      return const EmptyState(icon: Icons.rate_review_outlined, title: 'No reviews yet', subtitle: 'Be the first to review!');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _reviews.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = _reviews[i];
        return GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                    child: Center(child: Text(initialsOf(r.customerName, max: 1), style: GoogleFonts.poppins(color: AppColors.primaryLight, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.customerName, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                          style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  StarRating(rating: r.rating),
                  // Other customers' reviews can be reported to the admin.
                  if (r.customerId != AuthService().currentUser?.id)
                    GestureDetector(
                      onTap: () => showReportContentSheet(
                        context,
                        targetType: 'review',
                        targetId: r.id,
                        itemLabel: 'Review by ${r.customerName}: "${r.comment}"',
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: 8, top: 4, bottom: 4),
                        child: Icon(Icons.flag_outlined, color: AppColors.textMuted, size: 16),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(r.comment, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(TailorModel t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: _openChat,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryLight, size: 18),
                    const SizedBox(width: 6),
                    Text('Chat', style: GoogleFonts.poppins(color: AppColors.primaryLight, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GradientButton(
              text: 'Place Order',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceOrderScreen(tailor: t))),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(label, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    ),
  );
}

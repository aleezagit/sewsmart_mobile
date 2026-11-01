import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/app_refresh.dart';
import '../services/customer_service.dart';
import 'browse_tailors_screen.dart';
import 'customer_ai_recommendations_screen.dart';

// Designs the customer saved from AI Recommendations. The heart removes one,
// with an undo, and Find Tailors opens the tailors for its category.
class SavedDesignsScreen extends StatefulWidget {
  const SavedDesignsScreen({super.key});

  @override
  State<SavedDesignsScreen> createState() => _SavedDesignsScreenState();
}

class _SavedDesignsScreenState extends State<SavedDesignsScreen> {
  List<DesignModel> _designs = [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final designs = await CustomerService().getWishlist();
      if (mounted) setState(() { _designs = designs; _loading = false; _loadError = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
    }
  }

  Future<void> _remove(DesignModel design) async {
    final index = _designs.indexOf(design);
    if (index == -1) return;
    setState(() => _designs.removeAt(index));
    try {
      await CustomerService().removeFromWishlist(design.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _designs.insert(index, design));
      showError(context, e);
      return;
    }
    AppRefresh.wishlistChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
      content: Text('${design.name} removed', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
      backgroundColor: AppColors.cardAlt,
      // A snack bar with an action stays until it is tapped unless told
      // otherwise. The undo is offered for the usual few seconds.
      persist: false,
      action: SnackBarAction(
        label: 'UNDO',
        textColor: AppColors.primaryLight,
        onPressed: () => _undo(design, index),
      ),
    ));
  }

  Future<void> _undo(DesignModel design, int index) async {
    try {
      await CustomerService().addToWishlist(design.id);
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    AppRefresh.wishlistChanged();
    if (!mounted || _designs.contains(design)) return;
    setState(() => _designs.insert(index > _designs.length ? _designs.length : index, design));
  }

  Future<void> _exploreDesigns() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerAiRecommendationsScreen()),
    );
    if (mounted) _load();
  }

  // Browse Tailors filters by tailor category. General designs have none.
  void _findTailors(DesignModel design) {
    final category = design.category == 'General' ? 'All' : design.category;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BrowseTailorsScreen(initialCategory: category)),
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
              SewAppBar(
                title: 'Saved Designs',
                subtitle: _loading ? null : '${_designs.length} saved',
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2));
    }
    if (_loadError != null) {
      return LoadError(error: _loadError!, onRetry: () {
        setState(() => _loading = true);
        _load();
      });
    }
    if (_designs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No saved designs yet',
                subtitle: 'Save designs from AI Recommendations to see them here',
              ),
              const SizedBox(height: 20),
              GradientButton(text: 'Explore Designs', width: 200, onTap: _exploreDesigns),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryLight,
      backgroundColor: AppColors.card,
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: _designs.length,
        itemBuilder: (_, i) {
          final design = _designs[i];
          return _SavedDesignCard(
            design: design,
            onRemove: () => _remove(design),
            onFindTailors: () => _findTailors(design),
          );
        },
      ),
    );
  }
}

class _SavedDesignCard extends StatelessWidget {
  final DesignModel design;
  final VoidCallback onRemove, onFindTailors;
  const _SavedDesignCard({required this.design, required this.onRemove, required this.onFindTailors});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(design.category);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.08)],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: NetworkPicture(
                      url: design.imageUrl,
                      fallback: Center(child: Icon(_categoryIcon(design.category), color: color, size: 44)),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.bg.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.favorite_rounded, color: AppColors.error, size: 17),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  design.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  design.category,
                  style: GoogleFonts.poppins(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs ${_money(design.priceMin)} – ${_money(design.priceMax)}',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onFindTailors,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Find Tailors',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// The same colours the AI Recommendations screen gives each category.
Color _categoryColor(String category) {
  switch (category) {
    case 'Bridal':
      return AppColors.secondary;
    case 'Formal':
      return AppColors.info;
    case 'Eastern':
      return AppColors.teal;
    case 'Western':
      return AppColors.primary;
    case 'Casual':
      return AppColors.warning;
    default:
      return AppColors.primaryLight;
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Bridal':
      return Icons.diamond_rounded;
    case 'Formal':
      return Icons.business_center_rounded;
    case 'Eastern':
      return Icons.layers_rounded;
    case 'Western':
      return Icons.nightlife_rounded;
    case 'Casual':
      return Icons.wb_sunny_rounded;
    default:
      return Icons.checkroom_rounded;
  }
}

// 4500 as "4,500".
String _money(double value) {
  final digits = value.round().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

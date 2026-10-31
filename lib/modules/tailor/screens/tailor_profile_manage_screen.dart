import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/utils/validators.dart';
import '../services/tailor_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/verification_screen.dart';

class TailorProfileManageScreen extends StatefulWidget {
  const TailorProfileManageScreen({super.key});

  @override
  State<TailorProfileManageScreen> createState() =>
      _TailorProfileManageScreenState();
}

class _TailorProfileManageScreenState extends State<TailorProfileManageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _saving = false;
  bool _loading = true;
  bool _uploading = false;
  Object? _loadError;

  TailorModel? _tailor;
  List<PortfolioItem> _portfolio = [];
  List<GarmentPricing> _pricing = [];

  String get _tailorId => AuthService().currentUser?.id ?? '';

  // A getter, so the colours follow the theme when it changes on this screen.
  List<Color> get _portfolioColors => [
    AppColors.primary,
    AppColors.teal,
    AppColors.secondary,
    AppColors.warning,
    AppColors.info,
    AppColors.success,
    AppColors.orange,
    AppColors.gold,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final service = TailorService();
    try {
      final results = await Future.wait([
        service.getProfile(_tailorId),
        service.getPortfolio(_tailorId),
        service.getGarments(_tailorId),
      ]);
      if (!mounted) return;
      final tailor = results[0] as TailorModel;
      setState(() {
        _tailor = tailor;
        _portfolio = results[1] as List<PortfolioItem>;
        _pricing = results[2] as List<GarmentPricing>;
        _loading = false;
        _loadError = null;
      });
      _nameCtrl.text = tailor.name;
      _phoneCtrl.text = AuthService().currentUser?.phone ?? '';
      _cityCtrl.text = tailor.city;
      _expCtrl.text = tailor.experienceYears == 0 ? '' : '${tailor.experienceYears}';
      _bioCtrl.text = tailor.bio;
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _expCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final years = _expCtrl.text.trim().isEmpty ? 0 : int.tryParse(Validators.digitsOnly(_expCtrl.text));
    if (years == null) {
      showMessage(context, 'Enter your experience as a number of years, e.g. 8', success: false);
      return;
    }
    if (!Validators.isMobile(_phoneCtrl.text)) {
      showMessage(context, 'Enter a valid mobile number, e.g. 03001234567', success: false);
      return;
    }
    setState(() => _saving = true);
    try {
      final tailor = await TailorService().updateProfile(
        tailorId: _tailorId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        experienceYears: years,
        bio: _bioCtrl.text.trim(),
      );
      // The phone number lives on the account, so read the account again.
      await AuthService().getProfile();
      if (!mounted) return;
      setState(() => _tailor = tailor);
      showMessage(context, 'Profile updated!');
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _addSample() async {
    final image = await pickImage(context, title: 'Portfolio sample');
    if (image == null || !mounted) return;
    final title = await _askTitle();
    if (title == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final item = await TailorService().addPortfolioSample(tailorId: _tailorId, image: image, title: title);
      if (mounted) setState(() => _portfolio.insert(0, item));
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _uploading = false);
  }

  // The name shown under a new sample. Empty is allowed; null means cancel.
  Future<String?> _askTitle() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Name this sample', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: AppTextField(hint: 'e.g. Royal Bridal Lehenga (optional)', ctrl: ctrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Upload', style: GoogleFonts.poppins(color: AppColors.tealLight, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveSample(PortfolioItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Sample?', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'Remove ${item.title.isEmpty ? 'this sample' : item.title} from your portfolio?',
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await TailorService().removePortfolioSample(_tailorId, item.id);
                if (mounted) setState(() => _portfolio.remove(item));
              } catch (e) {
                if (mounted) showError(context, e);
              }
            },
            child: Text('Remove', style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Adds a garment, or edits the one at [index]. A name and a price above zero
  // are required; the dialog stays open and says what is missing.
  void _showGarmentDialog({int? index}) {
    final item = index == null ? null : _pricing[index];
    final garmentCtrl = TextEditingController(text: item?.garment ?? '');
    final priceCtrl = TextEditingController(text: item == null ? '' : item.price.toInt().toString());
    final timeCtrl = TextEditingController(text: item?.estimatedTime ?? '');
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            item == null ? 'Add Garment' : 'Edit Garment',
            style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(hint: 'Garment name', ctrl: garmentCtrl),
              const SizedBox(height: 10),
              AppTextField(hint: 'Price (Rs)', ctrl: priceCtrl, keyboard: TextInputType.number),
              const SizedBox(height: 10),
              AppTextField(hint: 'Estimated time (e.g. 3-4 days)', ctrl: timeCtrl),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            if (index != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmDeleteGarment(index);
                },
                child: Text('Delete',
                    style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
            ),
            GestureDetector(
              onTap: () async {
                final name = garmentCtrl.text.trim();
                final price = Validators.positiveNumber(priceCtrl.text);
                if (name.isEmpty || price == null) {
                  setDialogState(() => error = name.isEmpty ? 'Enter the garment name' : 'Enter a price above zero');
                  return;
                }
                final time = timeCtrl.text.trim();
                final service = TailorService();
                try {
                  final garment = item == null
                      ? await service.addGarment(tailorId: _tailorId, garment: name, price: price, estimatedTime: time)
                      : await service.updateGarment(
                          tailorId: _tailorId, garmentId: item.id, garment: name, price: price,
                          estimatedTime: time.isEmpty ? item.estimatedTime : time,
                        );
                  if (!mounted) return;
                  setState(() {
                    if (index == null) {
                      _pricing.add(garment);
                    } else {
                      _pricing[index] = garment;
                    }
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setDialogState(() => error = '$e');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.teal, AppColors.tealLight]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(item == null ? 'Add' : 'Save',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Deleting a garment removes it from the price list customers see, so ask first.
  void _confirmDeleteGarment(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Garment?',
            style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'Remove ${_pricing[index].garment} from your price list?',
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final item = _pricing[index];
              try {
                await TailorService().removeGarment(_tailorId, item.id);
                if (mounted) setState(() => _pricing.remove(item));
              } catch (e) {
                if (mounted) showError(context, e);
              }
            },
            child: Text('Delete',
                style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

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
              const SewAppBar(title: 'My Profile'),
              _buildProfileHeader(),
              _buildTabBar(),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: AppColors.tealLight, strokeWidth: 2))
                    : _loadError != null
                    ? LoadError(error: _loadError!, onRetry: () {
                        setState(() => _loading = true);
                        _load();
                      })
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProfileTab(),
                    _buildPortfolioTab(),
                    _buildPricingTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.teal, AppColors.tealLight]),
                ),
                child: Center(
                  child: Text(
                    initialsOf(_tailor?.name ?? AuthService().currentUser?.name ?? '', max: 1),
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 34),
                  ),
                ),
              ),
              if (_tailor?.isVerified == true)
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _tailor?.name ?? AuthService().currentUser?.name ?? '',
                style: GoogleFonts.poppins(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (_tailor?.isVerified == true) ...[
                const SizedBox(width: 6),
                Icon(Icons.verified_rounded, color: AppColors.info, size: 18),
              ],
            ],
          ),
          const SizedBox(height: 4),
          StarRating(rating: _tailor?.rating ?? 0),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: TabBar(
        controller: _tabController,
        // Fill the whole tab, like the tab bars on the customer screens.
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.teal, AppColors.tealLight]),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Profile'),
          Tab(text: 'Portfolio'),
          Tab(text: 'Pricing'),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          AppTextField(hint: 'Business Name', icon: Icons.storefront_rounded, ctrl: _nameCtrl, label: 'Business Name'),
          const SizedBox(height: 14),
          AppTextField(hint: 'Phone Number', icon: Icons.phone_rounded, ctrl: _phoneCtrl, keyboard: TextInputType.phone, label: 'Phone'),
          const SizedBox(height: 14),
          AppTextField(hint: 'City', icon: Icons.location_on_rounded, ctrl: _cityCtrl, label: 'City'),
          const SizedBox(height: 14),
          AppTextField(hint: 'Years of experience', icon: Icons.work_history_rounded, ctrl: _expCtrl, label: 'Experience (years)', keyboard: TextInputType.number),
          const SizedBox(height: 14),
          AppTextField(hint: 'Bio / Description', icon: Icons.info_outline_rounded, ctrl: _bioCtrl, maxLines: 3, label: 'Bio'),
          const SizedBox(height: 24),
          GradientButton(
            text: 'Save Changes',
            colors: [AppColors.teal, AppColors.tealLight],
            loading: _saving,
            onTap: _handleSave,
          ),
          const SizedBox(height: 20),
          _LinkTile(
            icon: Icons.verified_user_rounded,
            label: 'Verification',
            subtitle: 'CNIC and business proof',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerificationScreen()),
            ),
          ),
          const SizedBox(height: 10),
          // Off switches the whole app to the light theme. The choice is saved.
          _LinkTile(
            icon: AppColors.isLight ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            label: 'Dark Mode',
            subtitle: AppColors.isLight ? 'The light theme is on' : 'The dark theme is on',
            onTap: ThemeController.toggle,
            trailing: Switch(
              value: !AppColors.isLight,
              onChanged: (dark) => ThemeController.setLight(!dark),
              activeThumbColor: AppColors.tealLight,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.card,
                  title: Text('Sign Out?', style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  content: Text('Are you sure you want to sign out?', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted))),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Sign Out', style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600))),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await AuthService().logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPortfolioTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploading ? null : _addSample,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.tealLight.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.teal.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded, color: AppColors.tealLight, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _uploading ? 'Uploading...' : 'Add Sample',
                      style: GoogleFonts.poppins(color: AppColors.tealLight, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _portfolio.length,
            itemBuilder: (_, i) {
              final item = _portfolio[i];
              const placeholder = Icon(Icons.checkroom_rounded, color: Colors.white54, size: 32);
              return GestureDetector(
                // A long press removes the sample.
                onLongPress: () => _confirmRemoveSample(item),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: item.status == 'flagged' ? Border.all(color: AppColors.warning, width: 2) : null,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _portfolioColors[i % _portfolioColors.length].withValues(alpha: 0.6),
                        _portfolioColors[(i + 1) % _portfolioColors.length].withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                  child: item.imageUrl.isEmpty
                      ? placeholder
                      : Image.network(item.imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
                ),
              );
            },
          ),
          if (_portfolio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Press and hold a sample to remove it.',
                style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPricingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          ..._pricing.asMap().entries.map((entry) => _PricingItem(
            pricing: entry.value,
            onEdit: () => _showGarmentDialog(index: entry.key),
          )),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _showGarmentDialog(),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.tealLight.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.teal.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: AppColors.tealLight, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add New Garment',
                      style: GoogleFonts.poppins(color: AppColors.tealLight, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// A row that opens another screen, such as Verification, or holds
// a switch.
class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  // Shown in place of the arrow, such as a switch.
  final Widget? trailing;
  const _LinkTile({required this.icon, required this.label, required this.subtitle, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: AppColors.tealLight, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(subtitle, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          trailing ?? Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
        ],
      ),
    );
  }
}

class _PricingItem extends StatelessWidget {
  final GarmentPricing pricing;
  final VoidCallback onEdit;
  const _PricingItem({required this.pricing, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.checkroom_rounded, color: AppColors.tealLight, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pricing.garment,
                  style: GoogleFonts.poppins(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  pricing.estimatedTime,
                  style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            'Rs ${pricing.price.toInt()}',
            style: GoogleFonts.poppins(
                color: AppColors.tealLight, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.edit_rounded, color: AppColors.primaryLight, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

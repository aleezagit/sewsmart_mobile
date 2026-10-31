import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/app_refresh.dart';
import '../../../core/utils/validators.dart';
import '../../auth/screens/login_screen.dart';
import '../services/customer_service.dart';
import 'addresses_screen.dart';
import 'payment_methods_screen.dart';
import 'saved_designs_screen.dart';
// ignore_for_file: use_build_context_synchronously

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _notifications = true;
  bool _signingOut = false;
  int _savedCount = 0;
  int _totalOrders = 0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedCount();
    _loadOrderStats();
    // The order and review counts change when an order is placed or reviewed.
    AppRefresh.orders.addListener(_loadOrderStats);
    // The saved count changes when a design is saved or removed anywhere.
    AppRefresh.wishlist.addListener(_loadSavedCount);
  }

  // The counts are extras on this screen, so a failed load leaves the old ones.
  Future<void> _loadSavedCount() async {
    try {
      final saved = await CustomerService().getWishlist();
      if (mounted) setState(() => _savedCount = saved.length);
    } catch (_) {}
  }

  // Reviews are listed per tailor, so count this customer's reviews at the
  // tailors they have ordered from.
  Future<void> _loadOrderStats() async {
    try {
      final service = CustomerService();
      final orders = await service.getMyOrders();
      final tailorIds = orders.map((o) => o.tailorId).toSet();
      final reviews = await Future.wait(tailorIds.map(service.getTailorReviews));
      final me = _user?.id;
      if (!mounted) return;
      setState(() {
        _totalOrders = orders.length;
        _reviewCount = reviews.expand((list) => list).where((r) => r.customerId == me).length;
      });
    } catch (_) {}
  }

  void _openSavedDesigns() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedDesignsScreen()));
  }

  @override
  void dispose() {
    AppRefresh.orders.removeListener(_loadOrderStats);
    AppRefresh.wishlist.removeListener(_loadSavedCount);
    super.dispose();
  }

  UserModel? get _user => AuthService().currentUser;


  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(user),
                _buildStatRow(),
                const SizedBox(height: 8),
                _buildAccountSection(user),
                _buildAppSection(),
                _buildSupportSection(),
                const SizedBox(height: 20),
                _buildSignOutButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryLight, AppColors.teal],
                  ),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20)],
                ),
                child: Center(
                  child: Text(user.initials, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30)),
                ),
              ),
              GestureDetector(
                onTap: () => _showEditProfileDialog(user),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(user.name, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(user.email, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(user.phone, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.customerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.customerColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_rounded, color: AppColors.customerColor, size: 14),
                const SizedBox(width: 5),
                Text('Customer', style: GoogleFonts.poppins(color: AppColors.customerColor, fontSize: 11, fontWeight: FontWeight.w600)),
                if (user.isVerified) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified_rounded, color: AppColors.info, size: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          _StatBox(label: 'Orders', value: '$_totalOrders', icon: Icons.receipt_long_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          _StatBox(label: 'Reviews', value: '$_reviewCount', icon: Icons.star_rounded, color: AppColors.gold),
          const SizedBox(width: 10),
          _StatBox(
            label: 'Saved',
            value: '$_savedCount',
            icon: Icons.bookmark_rounded,
            color: AppColors.teal,
            onTap: _openSavedDesigns,
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(message,
            style: GoogleFonts.poppins(
                color: AppColors.textSecondary, fontSize: 13, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: GoogleFonts.poppins(color: AppColors.primaryLight)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Profile',
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(hint: 'Full Name', icon: Icons.person_rounded, ctrl: nameCtrl),
            const SizedBox(height: 10),
            AppTextField(
                hint: 'Phone',
                icon: Icons.phone_rounded,
                ctrl: phoneCtrl,
                keyboard: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          GestureDetector(
            onTap: () async {
              if (!Validators.isMobile(phoneCtrl.text)) {
                showMessage(ctx, 'Enter a valid mobile number, e.g. 03001234567', success: false);
                return;
              }
              final result = await AuthService().updateProfile(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              if (!mounted) return;
              if (!result.success) {
                showMessage(context, result.error ?? 'Could not save your profile', success: false);
                return;
              }
              Navigator.pop(ctx);
              setState(() {});
              showMessage(context, 'Profile updated!');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Save',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(UserModel user) {
    return _SettingsSection(
      title: 'Account',
      icon: Icons.person_outline_rounded,
      children: [
        _SettingsTile(
          icon: Icons.edit_outlined,
          label: 'Edit Profile',
          onTap: () => _showEditProfileDialog(user),
        ),
        _SettingsTile(
          icon: Icons.location_on_outlined,
          label: 'Addresses',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddressesScreen()),
          ),
        ),
        _SettingsTile(
          icon: Icons.bookmark_border_rounded,
          label: 'Saved Designs',
          onTap: _openSavedDesigns,
        ),
        _SettingsTile(
          icon: Icons.credit_card_outlined,
          label: 'Payment Methods',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const PaymentMethodsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildAppSection() {
    return _SettingsSection(
      title: 'App Settings',
      icon: Icons.settings_outlined,
      children: [
        _SettingsTile(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          trailing: Switch(
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
            activeThumbColor: AppColors.primaryLight,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onTap: null,
        ),
        _SettingsTile(
          icon: Icons.language_outlined,
          label: 'Language',
          trailing: 'English',
          onTap: () => _showInfoDialog(
              'Language', 'SewSmart is available in English for now. Urdu is planned for a later version.'),
        ),
        // Off switches the whole app to the light theme. The choice is saved.
        _SettingsTile(
          icon: AppColors.isLight ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          label: 'Dark Mode',
          trailing: Switch(
            value: !AppColors.isLight,
            onChanged: (dark) => ThemeController.setLight(!dark),
            activeThumbColor: AppColors.primaryLight,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onTap: ThemeController.toggle,
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return _SettingsSection(
      title: 'Support',
      icon: Icons.help_outline_rounded,
      children: [
        _SettingsTile(
          icon: Icons.help_center_outlined,
          label: 'Help Center',
          onTap: () => _showInfoDialog('Help Center',
              'Frequently Asked Questions:\n\n• How to place an order?\n  Tap a tailor → Book → Fill details\n\n• How to track my order?\n  Go to Orders tab → Track Order\n\n• Contact: support@sewsmart.com\n• Call: 0300-SEWSMART (9AM–9PM)'),
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          onTap: () => _showInfoDialog('Privacy Policy',
              'SewSmart collects only the data needed to provide tailoring services. Your personal information is never shared with third parties without consent.\n\nFor the full policy visit: sewsmart.com/privacy'),
        ),
        _SettingsTile(
          icon: Icons.info_outline_rounded,
          label: 'About SewSmart',
          trailing: 'v1.0.0',
          onTap: () => _showInfoDialog('About SewSmart',
              'SewSmart v1.0.0\n\nAI-powered digital tailoring marketplace connecting customers with skilled tailors across Pakistan.\n\nDeveloped as Final Year Project\nUniversity of Central Punjab\n\n© 2025 SewSmart'),
        ),
      ],
    );
  }

  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _signOut,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_signingOut)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.error, strokeWidth: 2))
              else ...[
                Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                Text('Sign Out', style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatBox({required this.label, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
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
            Text(value, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(label, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    ),
  );
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 14),
            const SizedBox(width: 6),
            Text(title, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(children: children),
        ),
      ],
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic trailing;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget? trailingWidget;
    if (trailing is Widget) {
      trailingWidget = trailing as Widget;
    } else if (trailing is String) {
      trailingWidget = Text(trailing as String, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12));
    } else {
      trailingWidget = Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppColors.cardAlt, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: AppColors.textSecondary, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 13))),
            trailingWidget,
          ],
        ),
      ),
    );
  }
}

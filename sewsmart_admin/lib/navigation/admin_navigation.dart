import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/admin_theme.dart';
import '../core/widgets/admin_widgets.dart';
import '../core/models/admin_models.dart';
import '../core/api/admin_api.dart';
import '../core/services/admin_service.dart';
import '../modules/dashboard/dashboard_screen.dart';
import '../modules/users/customers_screen.dart';
import '../modules/users/tailors_screen.dart';
import '../modules/orders/orders_screen.dart';
import '../modules/payments/payments_screen.dart';
import '../modules/verifications/verifications_screen.dart';
import '../modules/reports/reports_screen.dart';
import '../modules/disputes/disputes_screen.dart';
import '../modules/content/content_screen.dart';
import '../modules/settings/settings_screen.dart';
import '../modules/auth/admin_login_screen.dart';

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.people_rounded, label: 'Customers'),
    _NavItem(icon: Icons.design_services_rounded, label: 'Tailors'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Orders'),
    _NavItem(icon: Icons.payments_rounded, label: 'Payments'),
    _NavItem(icon: Icons.verified_user_rounded, label: 'Verifications'),
    _NavItem(icon: Icons.bar_chart_rounded, label: 'Reports'),
    _NavItem(icon: Icons.gavel_rounded, label: 'Disputes'),
    _NavItem(icon: Icons.article_rounded, label: 'Content'),
    _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  // Sidebar badges use the same counts as the dashboard.
  PlatformStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  // The badges are extras, so a failed load leaves them off.
  Future<void> _loadBadges() async {
    try {
      final stats = await AdminService().getStats();
      if (mounted) setState(() => _stats = stats);
    } on AdminApiException {
      // AdminApi already showed the message.
    }
  }

  int? _badgeFor(String label) {
    switch (label) {
      case 'Verifications':
        return _stats?.pendingVerifications;
      case 'Disputes':
        return _stats?.openDisputes;
      default:
        return null;
    }
  }

  bool get _isNarrow {
    final w = MediaQuery.sizeOf(context).width;
    return w < 1100;
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = _isNarrow;
    final sidebarWidth = collapsed ? 64.0 : 240.0;

    return Scaffold(
      backgroundColor: AdminColors.bg,
      body: Row(
        children: [
          // ── Sidebar ────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: sidebarWidth,
            decoration: const BoxDecoration(
              color: AdminColors.sidebar,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo area
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF2E3353)),
                    ),
                  ),
                  child: collapsed
                      ? Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AdminColors.sidebarActive,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.content_cut_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AdminColors.sidebarActive,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.content_cut_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'SewSmart',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Admin Panel',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AdminColors.sidebarText,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),

                // Nav items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: List.generate(_navItems.length, (i) {
                      final item = _navItems[i];
                      return SidebarItem(
                        icon: item.icon,
                        label: item.label,
                        isActive: _selectedIndex == i,
                        isCollapsed: collapsed,
                        badgeCount: _badgeFor(item.label),
                        onTap: () {
                          setState(() => _selectedIndex = i);
                          // The counts change while the admin works, so they reload on every move.
                          _loadBadges();
                        },
                      );
                    }),
                  ),
                ),

                // Logout
                const Divider(color: Color(0xFF2E3353), height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SidebarItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    isActive: false,
                    isCollapsed: collapsed,
                    onTap: () => _confirmLogout(context),
                  ),
                ),
              ],
            ),
          ),

          // ── Content area ───────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                _TopBar(
                  title: _navItems[_selectedIndex].label,
                  onMenuTap: () {},
                ),
                // Screen content — only the selected screen is in the tree
                Expanded(child: _screen(_selectedIndex)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _screen(int index) {
    switch (index) {
      case 0:  return const DashboardScreen();
      case 1:  return const CustomersScreen();
      case 2:  return const TailorsScreen();
      case 3:  return const OrdersScreen();
      case 4:  return const PaymentsScreen();
      case 5:  return const VerificationsScreen();
      case 6:  return const ReportsScreen();
      case 7:  return const DisputesScreen();
      case 8:  return const ContentScreen();
      case 9:  return const SettingsScreen();
      default: return const DashboardScreen();
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to logout from the admin panel?',
          style: GoogleFonts.poppins(fontSize: 14, color: AdminColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AdminColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // The session is cleared at once. The server call finishes on its own.
              AdminService().logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Logout', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;

  const _TopBar({required this.title, this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AdminColors.text,
            ),
          ),
          const Spacer(),
          // Search icon
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AdminColors.textSecondary),
            onPressed: () {},
            tooltip: 'Search',
          ),
          // Notifications
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AdminColors.textSecondary),
                onPressed: () {},
                tooltip: 'Notifications',
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AdminColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Admin avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AdminColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.person, color: AdminColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AdminService().adminName,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.text,
                ),
              ),
              Text(
                AdminService().adminEmail,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AdminColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

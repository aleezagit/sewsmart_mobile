import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/models/app_models.dart';
import '../core/services/chat_service.dart';
import '../core/utils/app_refresh.dart';
import '../core/widgets/shared_widgets.dart';
import '../modules/customer/screens/customer_home_screen.dart';
import '../modules/customer/screens/browse_tailors_screen.dart';
import '../modules/customer/screens/order_history_screen.dart';
import '../modules/customer/screens/customer_profile_screen.dart';
import '../modules/tailor/screens/tailor_dashboard_screen.dart';
import '../modules/tailor/screens/incoming_orders_screen.dart';
import '../modules/tailor/screens/tailor_earnings_screen.dart';
import '../modules/tailor/screens/tailor_profile_manage_screen.dart';
import '../modules/tailor/screens/tailor_chat_screen.dart';

// The home screen of each role, opened after sign-in.
Widget homeFor(UserRole role) => switch (role) {
  UserRole.customer => const MainNavigationCustomer(),
  UserRole.tailor => const MainNavigationTailor(),
};

// ─── Customer Navigation ───────────────────────────────────────────────────────
class MainNavigationCustomer extends StatefulWidget {
  // The tab to open first, e.g. 2 for Orders after a payment.
  final int initialIndex;
  const MainNavigationCustomer({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationCustomer> createState() => _MainNavigationCustomerState();
}

class _MainNavigationCustomerState extends State<MainNavigationCustomer> {
  late int _currentIndex = widget.initialIndex;

  final List<Widget> _screens = const [
    CustomerHomeScreen(),
    BrowseTailorsScreen(),
    OrderHistoryScreen(),
    _ChatListScreen(),
    CustomerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: Colors.transparent,
            selectedItemColor: AppColors.primaryLight,
            unselectedItemColor: AppColors.textMuted,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Explore'),
              BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tailor Navigation ─────────────────────────────────────────────────────────
class MainNavigationTailor extends StatefulWidget {
  const MainNavigationTailor({super.key});

  @override
  State<MainNavigationTailor> createState() => _MainNavigationTailorState();
}

class _MainNavigationTailorState extends State<MainNavigationTailor> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TailorDashboardScreen(),
    IncomingOrdersScreen(),
    _ChatListScreen(forTailor: true),
    TailorEarningsScreen(),
    TailorProfileManageScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: Colors.transparent,
            selectedItemColor: AppColors.tealLight,
            unselectedItemColor: AppColors.textMuted,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
              BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
              BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Earnings'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Chat List ─────────────────────────────────────────────────────────────────
// One conversation per order, for customers and tailors (GET /api/conversations).
class _ChatListScreen extends StatefulWidget {
  final bool forTailor;
  const _ChatListScreen({this.forTailor = false});

  @override
  State<_ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<_ChatListScreen> {
  late Future<List<ConversationModel>> _conversations = ChatService().getConversations();

  // Reload when an order is placed or changes, so its conversation appears.
  @override
  void initState() {
    super.initState();
    AppRefresh.orders.addListener(_reload);
  }

  @override
  void dispose() {
    AppRefresh.orders.removeListener(_reload);
    super.dispose();
  }

  void _reload() => setState(() => _conversations = ChatService().getConversations());

  Future<void> _open(ConversationModel c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TailorChatScreen(contactName: c.otherUserName, orderId: c.orderId)),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.forTailor
        ? [AppColors.teal, AppColors.tealLight]
        : [AppColors.primary, AppColors.teal];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        orb1: widget.forTailor ? AppColors.tealOrb : null,
        orb2: widget.forTailor ? AppColors.purpleOrb : null,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text('Messages',
                    style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ),
              Expanded(
                child: FutureBuilder<List<ConversationModel>>(
                  future: _conversations,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return LoadError(error: snapshot.error!, onRetry: _reload);
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator(color: colors.first));
                    }
                    final conversations = snapshot.data!;
                    if (conversations.isEmpty) {
                      return EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No conversations yet',
                        subtitle: widget.forTailor
                            ? 'Conversations will appear when customers place orders'
                            : 'Place an order to chat with your tailor',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _conversations;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: conversations.length,
                        itemBuilder: (ctx, i) => _tile(conversations[i], colors),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(ConversationModel c, List<Color> colors) {
    final subtitle = c.lastMessage.isEmpty ? 'Order: ${c.orderId} · ${c.garmentType}' : c.lastMessage;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _open(c),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)),
            child: Center(
              child: Text(
                initialsOf(c.otherUserName, max: 1),
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.otherUserName,
                    style: GoogleFonts.poppins(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          if (c.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: colors.first, borderRadius: BorderRadius.circular(10)),
              child: Text('${c.unreadCount}',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            )
          else
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
        ],
      ),
    );
  }
}

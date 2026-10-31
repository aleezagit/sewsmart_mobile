import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/app_refresh.dart';
import '../services/tailor_service.dart';
import 'order_detail_screen.dart';

class IncomingOrdersScreen extends StatefulWidget {
  const IncomingOrdersScreen({super.key});

  @override
  State<IncomingOrdersScreen> createState() => _IncomingOrdersScreenState();
}

class _IncomingOrdersScreenState extends State<IncomingOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OrderModel> _orders = [];
  bool _loading = true;
  Object? _loadError;
  final Map<String, bool> _actionLoading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
    // Load again when an order changes here or on the order detail screen.
    AppRefresh.orders.addListener(_loadOrders);
  }

  @override
  void dispose() {
    AppRefresh.orders.removeListener(_loadOrders);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await TailorService().getOrders();
      if (mounted) setState(() { _orders = orders; _loading = false; _loadError = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
    }
  }

  List<OrderModel> get _pendingOrders =>
      _orders.where((o) => o.status == OrderStatus.pending).toList();

  List<OrderModel> get _inProgressOrders => _orders
      .where((o) =>
          o.status == OrderStatus.accepted ||
          o.status == OrderStatus.inProgress ||
          o.status == OrderStatus.qualityCheck ||
          o.status == OrderStatus.readyForDelivery)
      .toList();

  List<OrderModel> get _completedOrders => _orders
      .where((o) =>
          o.status == OrderStatus.completed ||
          o.status == OrderStatus.delivered)
      .toList();

  Future<void> _handleAccept(OrderModel order) async {
    setState(() => _actionLoading['accept_${order.id}'] = true);
    try {
      await TailorService().acceptOrder(order.id);
      AppRefresh.ordersChanged();
      if (mounted) showMessage(context, 'Order accepted!');
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _actionLoading['accept_${order.id}'] = false);
  }

  Future<void> _handleReject(OrderModel order) async {
    // Rejecting cannot be undone, so ask first.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject Order?',
            style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'Reject the ${order.garmentType} order from ${order.customerName}? This cannot be undone.',
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reject',
                style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionLoading['reject_${order.id}'] = true);
    try {
      await TailorService().rejectOrder(order.id);
      AppRefresh.ordersChanged();
      if (mounted) showMessage(context, 'Order rejected', success: false);
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _actionLoading['reject_${order.id}'] = false);
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.accepted:
        return AppColors.info;
      case OrderStatus.inProgress:
        return AppColors.primary;
      case OrderStatus.qualityCheck:
        return AppColors.secondary;
      case OrderStatus.readyForDelivery:
        return AppColors.teal;
      case OrderStatus.completed:
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
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
              _buildAppBar(),
              _buildTabBar(),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.tealLight,
                          strokeWidth: 2,
                        ),
                      )
                    : _loadError != null
                    ? LoadError(error: _loadError!, onRetry: () {
                        setState(() => _loading = true);
                        _loadOrders();
                      })
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOrderList(_pendingOrders, showActions: true),
                          _buildOrderList(_inProgressOrders),
                          _buildOrderList(_completedOrders),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 0),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
            ),
          Expanded(
            child: Text(
              'Orders',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadOrders,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(Icons.filter_list_rounded, color: AppColors.textPrimary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pending'),
                if (_pendingOrders.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_pendingOrders.length}',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'In Progress'),
          const Tab(text: 'Completed'),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<OrderModel> orders, {bool showActions = false}) {
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders here',
        subtitle: 'New orders will appear here',
      );
    }
    return RefreshIndicator(
      color: AppColors.tealLight,
      backgroundColor: AppColors.card,
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        itemCount: orders.length,
        itemBuilder: (_, i) => _OrderCard(
          order: orders[i],
          statusColor: _statusColor(orders[i].status),
          showActions: showActions,
          acceptLoading: _actionLoading['accept_${orders[i].id}'] ?? false,
          rejectLoading: _actionLoading['reject_${orders[i].id}'] ?? false,
          onAccept: () => _handleAccept(orders[i]),
          onReject: () => _handleReject(orders[i]),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailScreen(order: orders[i])),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final Color statusColor;
  final bool showActions;
  final bool acceptLoading;
  final bool rejectLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.showActions,
    required this.acceptLoading,
    required this.rejectLoading,
    required this.onAccept,
    required this.onReject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.checkroom_rounded, color: AppColors.tealLight, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.garmentType,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      order.customerName,
                      style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Rs ${order.amount.toInt()}',
                          style: GoogleFonts.poppins(
                            color: AppColors.tealLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.measurements,
                            style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(label: order.statusLabel, color: statusColor),
                  if (order.hasDesignRef) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Design Ref',
                        style: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 8, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 12),
            Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: rejectLoading ? null : onReject,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: rejectLoading
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(color: AppColors.error, strokeWidth: 2),
                              )
                            : Text(
                                'Reject',
                                style: GoogleFonts.poppins(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: acceptLoading ? null : onAccept,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Center(
                        child: acceptLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Accept',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

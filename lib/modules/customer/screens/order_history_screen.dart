import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/app_refresh.dart';
import '../services/customer_service.dart';
import 'order_tracking_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OrderModel> _orders = [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
    // This tab stays alive, so load again when an order is placed or paid.
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
      final orders = await CustomerService().getMyOrders();
      if (mounted) setState(() { _orders = orders; _loading = false; _loadError = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
    }
  }

  List<OrderModel> get _activeOrders => _orders.where((o) =>
    o.status == OrderStatus.pending || o.status == OrderStatus.accepted ||
    o.status == OrderStatus.inProgress || o.status == OrderStatus.qualityCheck ||
    o.status == OrderStatus.readyForDelivery).toList();

  List<OrderModel> get _completedOrders => _orders.where((o) =>
    o.status == OrderStatus.completed || o.status == OrderStatus.delivered).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SewAppBar(title: 'My Orders'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
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
                    tabs: [
                      Tab(text: 'Active (${_activeOrders.length})'),
                      Tab(text: 'Done (${_completedOrders.length})'),
                      Tab(text: 'All (${_orders.length})'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2))
                    : _loadError != null
                    ? LoadError(error: _loadError!, onRetry: () {
                        setState(() => _loading = true);
                        _loadOrders();
                      })
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOrderList(_activeOrders),
                          _buildOrderList(_completedOrders),
                          _buildOrderList(_orders),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders here',
        subtitle: 'Your orders will appear here',
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryLight,
      backgroundColor: AppColors.card,
      onRefresh: _loadOrders,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _OrderCard(order: orders[i]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  Color get _statusColor {
    switch (order.status) {
      case OrderStatus.pending: return AppColors.warning;
      case OrderStatus.accepted: return AppColors.info;
      case OrderStatus.inProgress: return AppColors.primary;
      case OrderStatus.qualityCheck: return const Color(0xFF8B5CF6);
      case OrderStatus.readyForDelivery: return AppColors.success;
      case OrderStatus.delivered: return AppColors.teal;
      case OrderStatus.completed: return AppColors.success;
      case OrderStatus.cancelled: return AppColors.error;
      case OrderStatus.rejected: return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.id, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
              StatusBadge(label: order.statusLabel, color: _statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(order.garmentType, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.cut_rounded, color: AppColors.textMuted, size: 13),
              const SizedBox(width: 4),
              Text(order.tailorName, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, color: AppColors.textMuted, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                    style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
              Text(
                'Rs ${order.amount.toInt()}',
                style: GoogleFonts.poppins(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          if (order.status == OrderStatus.readyForDelivery) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order))),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping_outlined, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    Text('Schedule Delivery', style: GoogleFonts.poppins(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

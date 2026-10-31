import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api.dart';
import '../../core/services/admin_service.dart';
import '../../core/models/admin_models.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = AdminService();
  List<AdminOrder> _orders = [];
  List<AdminOrder> _filtered = [];
  bool _loading = true;
  String _search = '';

  final _tabs = const ['All', 'Pending', 'In Progress', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getAllOrders();
      if (mounted) setState(() => _orders = data);
    } on AdminApiException {
      // AdminApi already showed the message.
    }
    if (mounted) {
      setState(() => _loading = false);
      _applyFilter();
    }
  }

  void _applyFilter() {
    if (!mounted) return;
    final statusFilter = _tabs[_tabController.index];
    setState(() {
      _filtered = _orders.where((o) {
        final matchStatus = statusFilter == 'All' ||
            o.status.toLowerCase() == statusFilter.toLowerCase();
        final matchSearch = _search.isEmpty ||
            o.id.toLowerCase().contains(_search.toLowerCase()) ||
            o.customerName.toLowerCase().contains(_search.toLowerCase()) ||
            o.tailorName.toLowerCase().contains(_search.toLowerCase());
        return matchStatus && matchSearch;
      }).toList();
    });
  }

  void _showOrderDetail(AdminOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Order ${order.id}',
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    statusBadge(order.status),
                    const SizedBox(width: 12),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20)),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: AdminColors.border),
                const SizedBox(height: 16),
                _DetailSection(title: 'Customer', value: order.customerName),
                _DetailSection(title: 'Tailor', value: order.tailorName),
                _DetailSection(title: 'Garment', value: order.garment),
                _DetailSection(title: 'Amount', value: 'Rs. ${order.amount.toStringAsFixed(0)}'),
                _DetailSection(title: 'Date', value: order.date),
                _DetailSection(title: 'City', value: order.city),
                const SizedBox(height: 20),
                // Timeline
                Text('Order Timeline',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _TimelineItem(label: 'Order Placed', date: order.date, isDone: true),
                _TimelineItem(
                  label: 'Payment Confirmed',
                  date: order.date,
                  isDone: order.status != 'Pending',
                ),
                _TimelineItem(
                  label: 'In Production',
                  date: order.status == 'Completed' ? order.date : '',
                  isDone: order.status == 'Completed' || order.status == 'In Progress',
                ),
                _TimelineItem(
                  label: 'Delivered',
                  date: order.status == 'Completed' ? order.date : '',
                  isDone: order.status == 'Completed',
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (order.status != 'Cancelled' && order.status != 'Completed')
                      OutlineAdminButton(
                        label: 'Cancel Order',
                        color: AdminColors.error,
                        icon: Icons.cancel_outlined,
                        onPressed: () async {
                          Navigator.pop(ctx);
                          if (!await _service.cancelOrder(order.id)) return;
                          _load();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order cancelled.', style: GoogleFonts.poppins()),
                                backgroundColor: AdminColors.error,
                              ),
                            );
                          }
                        },
                      ),
                    const SizedBox(width: 12),
                    AdminButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Orders',
            subtitle: 'Manage all platform orders',
            badge: AdminBadge(label: '${_orders.length} total', color: AdminColors.info),
          ),
          const SizedBox(height: 20),
          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AdminColors.primary,
            unselectedLabelColor: AdminColors.textSecondary,
            indicatorColor: AdminColors.primary,
            labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
            tabs: _tabs.map((t) {
              final count = _orders.where((o) => t == 'All' || o.status.toLowerCase() == t.toLowerCase()).length;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: AdminColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Search and filters
          Row(
            children: [
              Expanded(
                child: AdminTextField(
                  hint: 'Search by order ID, customer or tailor...',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (v) {
                    _search = v;
                    _applyFilter();
                  },
                ),
              ),
              const SizedBox(width: 12),
              _FilterChip(label: 'Today'),
              const SizedBox(width: 8),
              _FilterChip(label: 'This Week'),
              const SizedBox(width: 8),
              _FilterChip(label: 'This Month'),
            ],
          ),
          const SizedBox(height: 16),
          // Table
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                TableHeader(
                  columns: const ['ORDER ID', 'CUSTOMER', 'TAILOR', 'GARMENT', 'AMOUNT', 'STATUS', 'DATE', 'ACTIONS'],
                  flexValues: const [1.5, 2, 2.5, 2, 1.5, 1.5, 1.5, 2],
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: EmptyState(icon: Icons.receipt_long_outlined, message: 'No orders found'),
                  )
                else
                  ..._filtered.map(
                    (o) => Column(
                      children: [
                        AdminRow(
                          cells: [
                            Text(o.id,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.primary)),
                            Row(children: [
                              AdminAvatar(name: o.customerName, size: 26, color: AdminColors.customerColor),
                              const SizedBox(width: 6),
                              Expanded(child: Text(o.customerName,
                                  style: GoogleFonts.poppins(fontSize: 12),
                                  overflow: TextOverflow.ellipsis)),
                            ]),
                            Text(o.tailorName,
                                style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary),
                                overflow: TextOverflow.ellipsis),
                            Text(o.garment, style: GoogleFonts.poppins(fontSize: 12), overflow: TextOverflow.ellipsis),
                            Text('Rs. ${o.amount.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                            statusBadge(o.status),
                            Text(o.date, style: GoogleFonts.poppins(fontSize: 11, color: AdminColors.textSecondary)),
                            Row(children: [
                              _ActionBtn(icon: Icons.visibility_rounded, color: AdminColors.info, tooltip: 'View', onTap: () => _showOrderDetail(o)),
                              const SizedBox(width: 4),
                              if (o.status != 'Cancelled' && o.status != 'Completed')
                                _ActionBtn(
                                  icon: Icons.cancel_outlined,
                                  color: AdminColors.error,
                                  tooltip: 'Cancel',
                                  onTap: () async {
                                    if (await _service.cancelOrder(o.id)) _load();
                                  },
                                ),
                            ]),
                          ],
                          flexValues: const [1.5, 2, 2.5, 2, 1.5, 1.5, 1.5, 2],
                        ),
                        const Divider(height: 1, color: AdminColors.border),
                      ],
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

class _FilterChip extends StatefulWidget {
  final String label;
  const _FilterChip({required this.label});

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _active = !_active),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _active ? AdminColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _active ? AdminColors.primary : AdminColors.border,
          ),
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _active ? Colors.white : AdminColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String value;
  const _DetailSection({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(title,
                style: GoogleFonts.poppins(fontSize: 13, color: AdminColors.textSecondary)),
          ),
          Text(value,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String label;
  final String date;
  final bool isDone;
  const _TimelineItem({required this.label, required this.date, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isDone ? AdminColors.success : AdminColors.border,
              shape: BoxShape.circle,
            ),
            child: isDone
                ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDone ? AdminColors.text : AdminColors.textSecondary,
                    fontWeight: isDone ? FontWeight.w500 : FontWeight.w400)),
          ),
          if (date.isNotEmpty)
            Text(date,
                style: GoogleFonts.poppins(fontSize: 11, color: AdminColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

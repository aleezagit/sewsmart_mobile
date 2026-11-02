import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api.dart';
import '../../core/services/admin_service.dart';
import '../../core/models/admin_models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = AdminService();
  PlatformStats? _stats;
  // The dashboard could not be loaded; the reason was shown in a snack bar.
  bool _failed = false;
  List<MonthlyRevenue> _monthlyRevenue = [];
  List<AdminOrder> _recentOrders = [];
  List<TopTailor> _topTailors = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // The four requests start together and the screen updates once.
  Future<void> _loadStats() async {
    final statsFuture = _service.getStats();
    final revenueFuture = _service.getMonthlyRevenue();
    final ordersFuture = _service.getRecentOrders();
    final tailorsFuture = _service.getTopTailors();
    try {
      final stats = await statsFuture;
      final revenue = await revenueFuture;
      final orders = await ordersFuture;
      final tailors = await tailorsFuture;
      if (mounted) {
        setState(() {
          _stats = stats;
          _monthlyRevenue = revenue;
          _recentOrders = orders;
          _topTailors = tailors;
          _failed = false;
        });
      }
    } on AdminApiException {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    if (stats == null) {
      return Center(
        child: _failed
            ? AdminButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: () {
                setState(() => _failed = false);
                _loadStats();
              })
            : const CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          PageHeader(
            title: 'Dashboard',
            subtitle: 'Welcome back, Admin! Here\'s what\'s happening today.',
            action: AdminButton(
              label: 'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: _loadStats,
              isSmall: true,
            ),
          ),
          const SizedBox(height: 24),

          // Row 1: 4 stat cards
          _StatsRow1(stats: stats, fmt: _fmt),
          const SizedBox(height: 16),

          // Row 2: 3 more stat cards
          _StatsRow2(stats: stats),
          const SizedBox(height: 24),

          // Revenue Chart
          _RevenueChart(data: _monthlyRevenue),
          const SizedBox(height: 24),

          // Recent Orders + Top Tailors
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _RecentOrdersCard(orders: _recentOrders)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _TopTailorsCard(tailors: _topTailors)),
            ],
          ),
          const SizedBox(height: 24),

          // Pending Verifications
          _PendingVerificationsCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatsRow1 extends StatelessWidget {
  final PlatformStats stats;
  final String Function(double) fmt;
  const _StatsRow1({required this.stats, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            icon: Icons.people_rounded,
            iconColor: AdminColors.customerColor,
            value: '${stats.totalUsers}',
            label: 'Total Users',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            icon: Icons.receipt_long_rounded,
            iconColor: AdminColors.info,
            value: '${stats.activeOrders}',
            label: 'Active Orders',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            icon: Icons.payments_rounded,
            iconColor: AdminColors.success,
            value: 'Rs. ${fmt(stats.thisMonthRevenue)}',
            label: 'Revenue This Month',
            // Compared with last month, when there was revenue to compare with.
            changeText: stats.lastMonthRevenue > 0
                ? '${stats.thisMonthRevenue >= stats.lastMonthRevenue ? '+' : ''}'
                    '${((stats.thisMonthRevenue - stats.lastMonthRevenue) / stats.lastMonthRevenue * 100).toStringAsFixed(0)}%'
                : null,
            isPositiveChange: stats.thisMonthRevenue >= stats.lastMonthRevenue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            icon: Icons.pending_actions_rounded,
            iconColor: AdminColors.warning,
            value: '${stats.pendingVerifications}',
            label: 'Pending Verifications',
          ),
        ),
      ],
    );
  }
}

class _StatsRow2 extends StatelessWidget {
  final PlatformStats stats;
  const _StatsRow2({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            icon: Icons.design_services_rounded,
            iconColor: AdminColors.tailorColor,
            value: '${stats.registeredTailors}',
            label: 'Registered Tailors',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            icon: Icons.gavel_rounded,
            iconColor: AdminColors.error,
            value: '${stats.openDisputes}',
            label: 'Open Disputes',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            icon: Icons.star_rounded,
            iconColor: AdminColors.warning,
            value: stats.averageTailorRating.toStringAsFixed(1),
            label: 'Avg. Tailor Rating',
          ),
        ),
      ],
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<MonthlyRevenue> data;
  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    // reduce throws on an empty list, so an empty chart gets its own card.
    if (data.isEmpty) {
      return const AdminCard(
        child: EmptyState(
          icon: Icons.show_chart_rounded,
          message: 'No revenue data yet',
        ),
      );
    }
    final maxY = data.map((d) => d.revenue).reduce((a, b) => a > b ? a : b) * 1.2;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'Revenue Overview',
            action: AdminBadge(
              label: 'Last 6 Months',
              color: AdminColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AdminColors.border,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        final label = value >= 1000
                            ? '${(value / 1000).toStringAsFixed(0)}K'
                            : value.toStringAsFixed(0);
                        return Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AdminColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data[idx].month,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AdminColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      data.length,
                      (i) => FlSpot(i.toDouble(), data[i].revenue),
                    ),
                    isCurved: true,
                    color: AdminColors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: AdminColors.primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AdminColors.primary.withOpacity(0.18),
                          AdminColors.primary.withOpacity(0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersCard extends StatelessWidget {
  final List<AdminOrder> orders;
  const _RecentOrdersCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: SectionTitle(
              title: 'Recent Orders',
              action: TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AdminColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AdminColors.border),
          TableHeader(
            columns: const ['ORDER ID', 'CUSTOMER', 'TAILOR', 'AMOUNT', 'STATUS'],
            flexValues: const [1.5, 2, 2, 1.5, 1.5],
          ),
          ...orders.map(
            (o) => Column(
              children: [
                AdminRow(
                  cells: [
                    Text(o.id,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.primary)),
                    Text(o.customerName,
                        style: GoogleFonts.poppins(fontSize: 12)),
                    Text(o.tailorName,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AdminColors.textSecondary),
                        overflow: TextOverflow.ellipsis),
                    Text('Rs. ${o.amount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    statusBadge(o.status),
                  ],
                  flexValues: const [1.5, 2, 2, 1.5, 1.5],
                ),
                const Divider(height: 1, color: AdminColors.border),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTailorsCard extends StatelessWidget {
  final List<TopTailor> tailors;
  const _TopTailorsCard({required this.tailors});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: SectionTitle(title: 'Top Tailors'),
          ),
          const Divider(height: 1, color: AdminColors.border),
          ...tailors.asMap().entries.map(
            (e) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: e.key == 0
                              ? AdminColors.warning.withOpacity(0.15)
                              : AdminColors.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '#${e.key + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: e.key == 0
                                  ? AdminColors.warning
                                  : AdminColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AdminAvatar(
                        name: e.value.name,
                        size: 32,
                        color: AdminColors.tailorColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.value.name,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AdminColors.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${e.value.orders} orders',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AdminColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs. ${(e.value.revenue / 1000).toStringAsFixed(0)}K',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AdminColors.text,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 12, color: AdminColors.warning),
                              const SizedBox(width: 2),
                              Text(
                                e.value.rating.toStringAsFixed(1),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AdminColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AdminColors.border),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingVerificationsCard extends StatefulWidget {
  @override
  State<_PendingVerificationsCard> createState() =>
      _PendingVerificationsCardState();
}

class _PendingVerificationsCardState extends State<_PendingVerificationsCard> {
  final _service = AdminService();
  List<PendingVerification> _items = [];
  bool _loading = true;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pending = await _service.getPendingVerifications();
      if (mounted) setState(() => _items = pending.take(3).toList());
    } on AdminApiException {
      // AdminApi already showed the message.
    }
    if (mounted) setState(() => _loading = false);
  }

  void _approve(String id) async {
    setState(() => _processing.add(id));
    final ok = await _service.approveVerification(id);
    if (!ok) {
      if (mounted) setState(() => _processing.remove(id));
      return;
    }
    if (mounted) {
      setState(() {
        _processing.remove(id);
        _items.removeWhere((v) => v.id == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account activated successfully!',
              style: GoogleFonts.poppins()),
          backgroundColor: AdminColors.success,
        ),
      );
    }
  }

  void _reject(String id) async {
    setState(() => _processing.add(id));
    final ok = await _service.rejectVerification(id, 'Rejected from dashboard');
    if (!ok) {
      if (mounted) setState(() => _processing.remove(id));
      return;
    }
    if (mounted) {
      setState(() {
        _processing.remove(id);
        _items.removeWhere((v) => v.id == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application rejected.', style: GoogleFonts.poppins()),
          backgroundColor: AdminColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: SectionTitle(
              title: 'Pending Verifications',
              action: _items.isNotEmpty
                  ? AdminBadge(
                      label: '${_items.length} pending',
                      color: AdminColors.warning,
                    )
                  : null,
            ),
          ),
          const Divider(height: 1, color: AdminColors.border),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: EmptyState(
                icon: Icons.check_circle_outline_rounded,
                message: 'All caught up!',
                subMessage: 'No pending verifications.',
              ),
            )
          else
            ...(_items.map(
              (v) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        AdminAvatar(
                          name: v.name,
                          size: 40,
                          color: AdminColors.tailorColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${v.city} • TAILOR • Submitted ${v.submittedDate}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AdminColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AdminBadge(
                          label: 'tailor',
                          color: AdminColors.tailorColor,
                        ),
                        const SizedBox(width: 12),
                        AdminButton(
                          label: 'Approve',
                          color: AdminColors.success,
                          isSmall: true,
                          isLoading: _processing.contains(v.id),
                          onPressed: () => _approve(v.id),
                        ),
                        const SizedBox(width: 8),
                        OutlineAdminButton(
                          label: 'Reject',
                          color: AdminColors.error,
                          isSmall: true,
                          onPressed: () => _reject(v.id),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AdminColors.border),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

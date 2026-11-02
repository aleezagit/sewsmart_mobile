import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/payout_service.dart';
import '../services/tailor_service.dart';

class TailorEarningsScreen extends StatefulWidget {
  const TailorEarningsScreen({super.key});

  @override
  State<TailorEarningsScreen> createState() => _TailorEarningsScreenState();
}

class _TailorEarningsScreenState extends State<TailorEarningsScreen> {
  TailorEarnings? _earnings;
  List<OrderModel> _orders = [];
  bool _loading = true;
  Object? _loadError;
  bool _withdrawing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final id = AuthService().currentUser?.id;
    if (id == null) return;
    try {
      final results = await Future.wait([TailorService().getEarnings(id), TailorService().getOrders()]);
      if (!mounted) return;
      setState(() {
        _earnings = results[0] as TailorEarnings;
        _orders = results[1] as List<OrderModel>;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
    }
  }

  // Asks for the whole available balance. Payouts are sent on Mondays.
  Future<void> _handleWithdraw() async {
    setState(() => _withdrawing = true);
    try {
      final withdrawal = await PayoutService().requestWithdrawal();
      if (mounted) showMessage(context, 'Withdrawal of Rs ${withdrawal.amount.toInt()} requested. Payouts are sent on Mondays.');
      await _loadData();
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _withdrawing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        orb1: AppColors.tealOrb,
        orb2: AppColors.purpleOrb,
        child: SafeArea(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.tealLight, strokeWidth: 2))
              : _loadError != null
              ? LoadError(error: _loadError!, onRetry: () {
                  setState(() => _loading = true);
                  _loadData();
                })
              : Column(
                  children: [
                    const SewAppBar(title: 'Earnings'),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderCard(),
                            const SizedBox(height: 20),
                            _buildMetricGrid(),
                            const SizedBox(height: 24),
                            _buildBarChart(),
                            const SizedBox(height: 24),
                            _buildTransactionList(),
                            const SizedBox(height: 24),
                            GradientButton(
                              text: 'Withdraw Earnings',
                              colors: [AppColors.teal, AppColors.tealLight],
                              loading: _withdrawing,
                              onTap: _handleWithdraw,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final total = _earnings?.total ?? 0;
    final thisMonth = _earnings?.thisMonth ?? 0;
    final totalOrders = _orders.length;
    final avgPerOrder = totalOrders > 0 ? total / totalOrders : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Earnings',
            style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Rs ${total.toInt()}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _EarningsStatItem(label: 'Orders', value: '$totalOrders'),
              _EarningsDivider(),
              _EarningsStatItem(
                  label: 'Avg/Order', value: 'Rs ${avgPerOrder.toInt()}'),
              _EarningsDivider(),
              _EarningsStatItem(label: 'This Month', value: 'Rs ${thisMonth.toInt()}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid() {
    final pending = _earnings?.pending ?? 0;
    final withdrawn = _earnings?.withdrawn ?? 0;
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        MetricCard(
          label: 'Pending Payment',
          value: 'Rs ${pending.toInt()}',
          icon: Icons.pending_rounded,
          color: AppColors.warning,
        ),
        MetricCard(
          label: 'Withdrawn',
          value: 'Rs ${withdrawn.toInt()}',
          icon: Icons.account_balance_rounded,
          color: AppColors.success,
        ),
        MetricCard(
          label: 'Avg Rating',
          value: '4.9',
          icon: Icons.star_rounded,
          color: AppColors.gold,
        ),
        MetricCard(
          label: 'Repeat Customers',
          value: '18',
          icon: Icons.people_rounded,
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    final monthly = _earnings?.monthly ?? const <MonthlyEarning>[];
    // At least 1, so a chart of empty months still has a height.
    final maxAmt = monthly.fold<double>(1, (top, m) => m.amount > top ? m.amount : top);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Earnings',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          child: SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxAmt * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.card,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      'Rs ${rod.toY.toInt()}',
                      GoogleFonts.poppins(color: AppColors.tealLight, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= monthly.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            monthly[idx].shortMonth,
                            style: GoogleFonts.poppins(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.divider,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: monthly.asMap().entries.map((entry) {
                  final i = entry.key;
                  final m = entry.value;
                  final isLast = i == monthly.length - 1;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: m.amount,
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isLast
                              ? [AppColors.teal, AppColors.tealLight]
                              : [
                                  AppColors.teal.withValues(alpha: 0.4),
                                  AppColors.tealLight.withValues(alpha: 0.6),
                                ],
                        ),
                        width: 24,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transactions',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),
        if (_orders.isEmpty)
          const EmptyState(icon: Icons.receipt_rounded, title: 'No transactions yet')
        else
          ..._orders.map((order) => _TransactionRow(order: order)),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final OrderModel order;
  const _TransactionRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final isCompleted = order.status == OrderStatus.completed;
    final isPending = order.status == OrderStatus.pending || order.status == OrderStatus.inProgress;
    final color = isCompleted ? AppColors.success : isPending ? AppColors.warning : AppColors.info;
    final icon = isCompleted ? Icons.check_circle_rounded : isPending ? Icons.pending_rounded : Icons.local_shipping_rounded;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
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
                    fontSize: 12,
                  ),
                ),
                Text(
                  order.customerName,
                  style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            'Rs ${order.amount.toInt()}',
            style: GoogleFonts.poppins(
              color: isCompleted ? AppColors.success : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsStatItem extends StatelessWidget {
  final String label, value;
  const _EarningsStatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EarningsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}

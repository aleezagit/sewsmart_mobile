import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api.dart';
import '../../core/services/admin_service.dart';
import '../../core/models/admin_models.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _service = AdminService();
  AdminReport? _report;
  String _range = 'This Month';
  // The days picked for the Custom range.
  DateTimeRange? _dates;
  bool _failed = false;

  final _ranges = ['Today', 'This Week', 'This Month', 'Custom'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Runs on open and again whenever the range chip changes.
  Future<void> _load() async {
    final range = _range;
    try {
      final report = await _service.getReports(range: range, dates: _dates);
      // A late reply for an older range must not replace the current one.
      if (mounted && range == _range) setState(() { _report = report; _failed = false; });
    } on AdminApiException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _pickRange(String range) async {
    if (range == 'Custom') {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: now,
        initialDateRange: _dates,
      );
      if (picked == null) return;
      _dates = picked;
    }
    setState(() => _range = range);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null) {
      return Center(
        child: _failed
            ? AdminButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: () {
                setState(() => _failed = false);
                _load();
              })
            : const CircularProgressIndicator(),
      );
    }
    final stats = report.stats;
    final monthly = report.monthlyRevenue;
    final categories = report.revenueByCategory;
    final topTailors = report.topTailors;
    final statusCounts = report.orderStatusDistribution;
    final statusTotal = statusCounts.values.fold<int>(0, (a, b) => a + b);
    double share(int count) => statusTotal == 0 ? 0.0 : count / statusTotal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          PageHeader(
            title: 'Reports & Analytics',
            subtitle: 'Platform performance and insights',
          ),
          const SizedBox(height: 20),

          // Date range chips
          Row(
            children: _ranges.map((r) {
              final active = _range == r;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _pickRange(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AdminColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active ? AdminColors.primary : AdminColors.border),
                    ),
                    child: Text(
                      r,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: active ? Colors.white : AdminColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 6 metric cards
          Row(
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
                  value: '${stats.totalOrders}',
                  label: 'Total Orders',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  icon: Icons.payments_rounded,
                  iconColor: AdminColors.success,
                  value: 'Rs. ${(stats.totalRevenue / 1000000).toStringAsFixed(1)}M',
                  label: 'Total Revenue',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.design_services_rounded,
                  iconColor: AdminColors.tailorColor,
                  value: '${stats.registeredTailors}',
                  label: 'Active Tailors',
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
                  label: 'Avg. Rating',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Charts row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bar chart
              Expanded(
                flex: 3,
                child: AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(title: 'Monthly Revenue'),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 220,
                        child: BarChart(
                          BarChartData(
                            barGroups: List.generate(monthly.length, (i) {
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: monthly[i].revenue,
                                    color: AdminColors.primary,
                                    width: 28,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                    backDrawRodData: BackgroundBarChartRodData(
                                      show: true,
                                      toY: monthly.map((d) => d.revenue).reduce(math.max) * 1.2,
                                      color: AdminColors.border,
                                    ),
                                  ),
                                ],
                              );
                            }),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (v) => FlLine(
                                color: AdminColors.border,
                                strokeWidth: 1,
                                dashArray: [4, 4],
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.toInt();
                                    if (idx < 0 || idx >= monthly.length) return const SizedBox();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(monthly[idx].month,
                                          style: GoogleFonts.poppins(
                                              fontSize: 11, color: AdminColors.textSecondary)),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 50,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) return const SizedBox();
                                    return Text(
                                      '${(value / 1000).toStringAsFixed(0)}K',
                                      style: GoogleFonts.poppins(
                                          fontSize: 10, color: AdminColors.textSecondary),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Pie chart
              Expanded(
                flex: 2,
                child: AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(title: 'Revenue by Category'),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(enabled: false),
                            borderData: FlBorderData(show: false),
                            sectionsSpace: 2,
                            centerSpaceRadius: 50,
                            sections: categories.asMap().entries.map((e) {
                              final cat = e.value;
                              final total = categories.fold<double>(0, (a, b) => a + b.amount);
                              final pct = (cat.amount / total * 100).toStringAsFixed(0);
                              return PieChartSectionData(
                                color: Color(cat.color),
                                value: cat.amount,
                                title: '$pct%',
                                radius: 40,
                                titleStyle: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(cat.color),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(cat.category,
                                  style: GoogleFonts.poppins(fontSize: 12)),
                            ),
                            Text(
                              'Rs. ${(cat.amount / 1000).toStringAsFixed(0)}K',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top Tailors table
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: SectionTitle(title: 'Top Performing Tailors'),
                ),
                const Divider(height: 1, color: AdminColors.border),
                TableHeader(
                  columns: const ['RANK', 'NAME', 'CITY', 'ORDERS', 'REVENUE', 'RATING', 'COMPLETION'],
                  flexValues: const [0.8, 2.5, 1.2, 1, 1.5, 1, 1.5],
                ),
                ...topTailors.asMap().entries.map(
                  (e) => Column(
                    children: [
                      AdminRow(
                        cells: [
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
                              child: Text('#${e.key + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: e.key == 0
                                        ? AdminColors.warning
                                        : AdminColors.textSecondary,
                                  )),
                            ),
                          ),
                          Row(children: [
                            AdminAvatar(name: e.value.name, size: 30, color: AdminColors.tailorColor),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.value.name,
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis)),
                          ]),
                          Text(e.value.city, style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary)),
                          Text('${e.value.orders}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('Rs. ${(e.value.revenue / 1000).toStringAsFixed(0)}K',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                          Row(children: [
                            const Icon(Icons.star_rounded, size: 13, color: AdminColors.warning),
                            const SizedBox(width: 2),
                            Text(e.value.rating.toStringAsFixed(1), style: GoogleFonts.poppins(fontSize: 12)),
                          ]),
                          Row(children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: e.value.completionRate / 100,
                                  backgroundColor: AdminColors.border,
                                  valueColor: const AlwaysStoppedAnimation(AdminColors.success),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${e.value.completionRate.toStringAsFixed(0)}%',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ],
                        flexValues: const [0.8, 2.5, 1.2, 1, 1.5, 1, 1.5],
                      ),
                      const Divider(height: 1, color: AdminColors.border),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Order status distribution
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: SectionTitle(title: 'Order Status Distribution'),
                ),
                const Divider(height: 1, color: AdminColors.border),
                TableHeader(
                  columns: const ['STATUS', 'COUNT', 'PERCENTAGE', 'DISTRIBUTION'],
                  flexValues: const [1.5, 1, 1, 3],
                ),
                ...[
                  ('Completed', statusCounts['Completed'] ?? 0, AdminColors.success),
                  ('In Progress', statusCounts['In Progress'] ?? 0, AdminColors.info),
                  ('Pending', statusCounts['Pending'] ?? 0, AdminColors.warning),
                  ('Cancelled', statusCounts['Cancelled'] ?? 0, AdminColors.error),
                ].map(
                  (item) => Column(
                    children: [
                      AdminRow(
                        cells: [
                          statusBadge(item.$1),
                          Text('${item.$2}',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${(share(item.$2) * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary)),
                          Row(children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: share(item.$2),
                                  backgroundColor: AdminColors.border,
                                  valueColor: AlwaysStoppedAnimation(item.$3),
                                  minHeight: 8,
                                ),
                              ),
                            ),
                          ]),
                        ],
                        flexValues: const [1.5, 1, 1, 3],
                      ),
                      const Divider(height: 1, color: AdminColors.border),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

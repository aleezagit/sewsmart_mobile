import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api.dart';
import '../../core/services/admin_service.dart';
import '../../core/models/admin_models.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _service = AdminService();
  List<AdminPayment> _payments = [];
  List<AdminPayment> _filtered = [];
  PaymentSummary? _summary;
  bool _loading = true;
  String _methodFilter = 'All';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final paymentsFuture = _service.getAllPayments();
    final summaryFuture = _service.getPaymentSummary();
    try {
      final data = await paymentsFuture;
      final summary = await summaryFuture;
      if (mounted) {
        setState(() {
          _payments = data;
          _summary = summary;
        });
        _applyFilters();
      }
    } on AdminApiException {
      // AdminApi already showed the message.
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilters() {
    setState(() {
      _filtered = _payments.where((p) {
        final matchMethod = _methodFilter == 'All' || p.method == _methodFilter;
        final matchStatus = _statusFilter == 'All' || p.status == _statusFilter;
        return matchMethod && matchStatus;
      }).toList();
    });
  }

  // The four totals come from the server, not from the rows on screen.
  double get _totalRevenue => _summary?.totalRevenue ?? 0.0;
  double get _thisMonth => _summary?.thisMonth ?? 0.0;
  double get _pending => _summary?.pending ?? 0.0;
  double get _refunded => _summary?.refunded ?? 0.0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Payments',
            subtitle: 'Monitor all financial transactions',
          ),
          const SizedBox(height: 20),

          // Stat cards
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AdminColors.success,
                  value: 'Rs. ${(_totalRevenue / 1000).toStringAsFixed(0)}K',
                  label: 'Total Revenue',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  icon: Icons.calendar_today_rounded,
                  iconColor: AdminColors.primary,
                  value: 'Rs. ${(_thisMonth / 1000).toStringAsFixed(0)}K',
                  label: 'This Month',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  icon: Icons.hourglass_empty_rounded,
                  iconColor: AdminColors.warning,
                  value: 'Rs. ${(_pending / 1000).toStringAsFixed(0)}K',
                  label: 'Pending',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  icon: Icons.replay_rounded,
                  iconColor: AdminColors.error,
                  value: 'Rs. ${(_refunded / 1000).toStringAsFixed(0)}K',
                  label: 'Refunded',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminColors.border),
                ),
                child: DropdownButton<String>(
                  value: _methodFilter,
                  underline: const SizedBox(),
                  hint: Text('Method', style: GoogleFonts.poppins(fontSize: 13)),
                  style: GoogleFonts.poppins(fontSize: 13, color: AdminColors.text),
                  items: ['All', 'JazzCash', 'EasyPaisa', 'Bank', 'Card']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      _methodFilter = v;
                      _applyFilters();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminColors.border),
                ),
                child: DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox(),
                  style: GoogleFonts.poppins(fontSize: 13, color: AdminColors.text),
                  items: ['All', 'Paid', 'Processing', 'Refunded']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      _statusFilter = v;
                      _applyFilters();
                    }
                  },
                ),
              ),
              const Spacer(),
              Text(
                'Showing ${_filtered.length} transactions',
                style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                TableHeader(
                  columns: const ['TXN ID', 'CUSTOMER', 'TAILOR', 'AMOUNT', 'METHOD', 'STATUS', 'DATE'],
                  flexValues: const [1.5, 2, 2.5, 1.5, 1.5, 1.5, 1.5],
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: EmptyState(icon: Icons.payments_outlined, message: 'No transactions found'),
                  )
                else
                  ..._filtered.map(
                    (p) => Column(
                      children: [
                        AdminRow(
                          cells: [
                            Text(p.transactionId,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.primary)),
                            Text(p.customerName, style: GoogleFonts.poppins(fontSize: 12)),
                            Text(p.tailorName,
                                style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary),
                                overflow: TextOverflow.ellipsis),
                            Text('Rs. ${p.amount.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                            _MethodBadge(method: p.method),
                            statusBadge(p.status),
                            Text(p.date, style: GoogleFonts.poppins(fontSize: 11, color: AdminColors.textSecondary)),
                          ],
                          flexValues: const [1.5, 2, 2.5, 1.5, 1.5, 1.5, 1.5],
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

class _MethodBadge extends StatelessWidget {
  final String method;
  const _MethodBadge({required this.method});

  Color get _color {
    switch (method) {
      case 'JazzCash': return const Color(0xFFCC0000);
      case 'EasyPaisa': return const Color(0xFF00A651);
      case 'Bank': return AdminColors.primary;
      case 'Card': return AdminColors.info;
      default: return AdminColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        method,
        style: GoogleFonts.poppins(fontSize: 11, color: _color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

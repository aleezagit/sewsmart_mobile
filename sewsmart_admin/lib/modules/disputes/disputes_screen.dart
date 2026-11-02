import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api.dart';
import '../../core/services/admin_service.dart';
import '../../core/models/admin_models.dart';

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = AdminService();
  List<AdminDispute> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final data = await _service.getDisputes();
      if (mounted) setState(() => _all = data);
    } on AdminApiException {
      // AdminApi already showed the message.
    }
    if (mounted) setState(() => _loading = false);
  }

  List<AdminDispute> get _open => _all.where((d) => d.status == 'Open').toList();
  List<AdminDispute> get _resolved => _all.where((d) => d.status == 'Resolved').toList();

  void _showResolveDialog(AdminDispute dispute) {
    String _resolutionType = 'Refund';
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Resolve Dispute ${dispute.id}',
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Issue summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminColors.warning.withOpacity(0.25)),
                  ),
                  child: Text(dispute.issue,
                      style: GoogleFonts.poppins(fontSize: 13, color: AdminColors.text)),
                ),
                const SizedBox(height: 16),
                Text('Resolution Type',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                // Resolution type selector
                Row(
                  children: ['Refund', 'Warning', 'Dismiss'].map((type) {
                    final selected = _resolutionType == type;
                    Color typeColor;
                    switch (type) {
                      case 'Refund': typeColor = AdminColors.success; break;
                      case 'Warning': typeColor = AdminColors.warning; break;
                      default: typeColor = AdminColors.textSecondary;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setSt(() => _resolutionType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? typeColor.withOpacity(0.12) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? typeColor : AdminColors.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            type,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? typeColor : AdminColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                AdminTextField(
                  label: 'Resolution Notes',
                  hint: 'Describe the resolution taken...',
                  controller: notesCtrl,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AdminColors.textSecondary)),
            ),
            AdminButton(
              label: 'Confirm Resolution',
              onPressed: () async {
                Navigator.pop(ctx);
                if (!await _service.resolveDispute(dispute.id, _resolutionType, notesCtrl.text)) return;
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Dispute resolved: $_resolutionType', style: GoogleFonts.poppins()),
                      backgroundColor: AdminColors.success,
                    ),
                  );
                }
              },
            ),
          ],
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
            title: 'Disputes & Refunds',
            subtitle: 'Manage customer and tailor disputes',
            badge: _open.isNotEmpty
                ? AdminBadge(label: '${_open.length} open', color: AdminColors.error)
                : null,
          ),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AdminColors.primary,
            unselectedLabelColor: AdminColors.textSecondary,
            indicatorColor: AdminColors.primary,
            labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Open'),
                    const SizedBox(width: 6),
                    if (_open.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${_open.length}',
                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Resolved'),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_resolved.length}',
                          style: GoogleFonts.poppins(fontSize: 10, color: AdminColors.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              height: MediaQuery.sizeOf(context).height - 270,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _DisputeList(disputes: _open, showResolve: true, onResolve: _showResolveDialog),
                  _DisputeList(disputes: _resolved, showResolve: false, onResolve: _showResolveDialog),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DisputeList extends StatelessWidget {
  final List<AdminDispute> disputes;
  final bool showResolve;
  final void Function(AdminDispute) onResolve;

  const _DisputeList({
    required this.disputes,
    required this.showResolve,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    if (disputes.isEmpty) {
      return EmptyState(
        icon: showResolve ? Icons.gavel_outlined : Icons.check_circle_outline_rounded,
        message: showResolve ? 'No open disputes' : 'No resolved disputes',
        subMessage: showResolve ? 'Great! All disputes have been addressed.' : 'Resolved disputes will appear here.',
      );
    }
    return ListView.separated(
      itemCount: disputes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _DisputeCard(
        dispute: disputes[i],
        showResolve: showResolve,
        onResolve: () => onResolve(disputes[i]),
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final AdminDispute dispute;
  final bool showResolve;
  final VoidCallback onResolve;

  const _DisputeCard({
    required this.dispute,
    required this.showResolve,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final d = dispute;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AdminColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(d.id,
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w700, color: AdminColors.primary)),
                    ),
                    const SizedBox(width: 10),
                    Text('Order: ${d.orderId}',
                        style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary)),
                  ],
                ),
              ),
              statusBadge(d.status),
            ],
          ),
          const SizedBox(height: 12),

          // Parties
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    AdminAvatar(name: d.customerName, size: 32, color: AdminColors.customerColor),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.customerName,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('Customer', style: GoogleFonts.poppins(fontSize: 11, color: AdminColors.customerColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: AdminColors.textSecondary),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(d.tailorName,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('Tailor', style: GoogleFonts.poppins(fontSize: 11, color: AdminColors.tailorColor)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    AdminAvatar(name: d.tailorName, size: 32, color: AdminColors.tailorColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AdminColors.border),
          const SizedBox(height: 10),

          // Issue
          Text('Issue:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AdminColors.textSecondary)),
          const SizedBox(height: 4),
          Text(d.issue, style: GoogleFonts.poppins(fontSize: 13, color: AdminColors.text)),
          const SizedBox(height: 10),

          // Show resolution if resolved
          if (d.resolution != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminColors.success.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: AdminColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Resolution: ${d.resolution!}',
                        style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.success)),
                  ),
                ],
              ),
            ),
          ],

          Row(
            children: [
              Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 14, color: AdminColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Rs. ${d.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: AdminColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(d.dateRaised, style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary)),
                ],
              ),
              const Spacer(),
              if (showResolve)
                AdminButton(
                  label: 'Resolve',
                  icon: Icons.gavel_rounded,
                  onPressed: onResolve,
                  isSmall: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

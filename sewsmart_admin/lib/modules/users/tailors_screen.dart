import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api.dart';
import '../../core/services/admin_service.dart';
import '../../core/models/admin_models.dart';

class TailorsScreen extends StatefulWidget {
  const TailorsScreen({super.key});

  @override
  State<TailorsScreen> createState() => _TailorsScreenState();
}

class _TailorsScreenState extends State<TailorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = AdminService();
  List<AdminTailor> _tailors = [];
  List<AdminTailor> _filtered = [];
  List<PendingVerification> _pending = [];
  bool _loading = true;
  String _search = '';
  String _statusFilter = 'All';

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
      final tailors = await _service.getTailors();
      final pending = await _service.getPendingVerifications();
      if (mounted) {
        setState(() {
          _tailors = tailors;
          _filtered = tailors;
          _pending = pending;
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
      _filtered = _tailors.where((t) {
        final matchSearch = _search.isEmpty ||
            t.name.toLowerCase().contains(_search.toLowerCase()) ||
            t.city.toLowerCase().contains(_search.toLowerCase()) ||
            t.category.toLowerCase().contains(_search.toLowerCase());
        final matchStatus = _statusFilter == 'All' || t.status == _statusFilter;
        return matchSearch && matchStatus;
      }).toList();
    });
  }

  Future<void> _approvePending(String id) async {
    if (!await _service.approveVerification(id)) return;
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tailor account activated!', style: GoogleFonts.poppins()),
          backgroundColor: AdminColors.success,
        ),
      );
    }
  }

  void _showRejectDialog(String id) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Reject Application',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please provide a reason for rejection:',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AdminColors.textSecondary)),
            const SizedBox(height: 12),
            AdminTextField(
              hint: 'Enter reason...',
              controller: ctrl,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: AdminColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (!await _service.rejectVerification(id, ctrl.text)) return;
              _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Application rejected.', style: GoogleFonts.poppins()),
                    backgroundColor: AdminColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: Text('Reject', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _requestMoreDocs(String id) async {
    if (!await _service.requestMoreDocuments(id) || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request sent to applicant.', style: GoogleFonts.poppins())),
    );
  }

  void _confirmRemove(String id) {
    final idx = _tailors.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final tailor = _tailors[idx];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Remove Tailor',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
            'Are you sure you want to permanently remove ${tailor.name}? This action cannot be undone.',
            style: GoogleFonts.poppins(
                fontSize: 14, color: AdminColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: AdminColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (await _service.removeTailor(tailor.id) && mounted) _load();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: Text('Remove', style: GoogleFonts.poppins()),
          ),
        ],
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
            title: 'Tailors',
            subtitle: 'Manage registered tailor accounts',
            badge: AdminBadge(
              label: '${_tailors.length}',
              color: AdminColors.tailorColor,
            ),
          ),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AdminColors.primary,
            unselectedLabelColor: AdminColors.textSecondary,
            indicatorColor: AdminColors.primary,
            labelStyle: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400),
            tabs: [
              const Tab(text: 'All Tailors'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Pending Approval'),
                    const SizedBox(width: 6),
                    if (_pending.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${_pending.length}',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: MediaQuery.sizeOf(context).height - 280,
            child: TabBarView(
              controller: _tabController,
              children: [
                _AllTailorsTab(
                  tailors: _filtered,
                  loading: _loading,
                  search: _search,
                  statusFilter: _statusFilter,
                  onSearchChanged: (v) {
                    _search = v;
                    _applyFilters();
                  },
                  onFilterChanged: (v) {
                    _statusFilter = v;
                    _applyFilters();
                  },
                  onSuspend: (id) async {
                    final tailor = _tailors.firstWhere((t) => t.id == id);
                    if (await _service.suspendTailor(id, suspend: tailor.status == 'Active')) _load();
                  },
                  onRemove: _confirmRemove,
                ),
                _PendingTailorsTab(
                  pending: _pending,
                  onApprove: _approvePending,
                  onReject: _showRejectDialog,
                  onRequestDocs: _requestMoreDocs,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllTailorsTab extends StatelessWidget {
  final List<AdminTailor> tailors;
  final bool loading;
  final String search;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function(String) onSuspend;
  final void Function(String) onRemove;

  const _AllTailorsTab({
    required this.tailors,
    required this.loading,
    required this.search,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSuspend,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AdminTextField(
                hint: 'Search tailors...',
                prefixIcon: Icons.search_rounded,
                onChanged: onSearchChanged,
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
                value: statusFilter,
                underline: const SizedBox(),
                style: GoogleFonts.poppins(fontSize: 13, color: AdminColors.text),
                items: ['All', 'Active', 'Suspended']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onFilterChanged(v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AdminCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                TableHeader(
                  columns: const [
                    'NAME',
                    'CITY',
                    'CATEGORY',
                    'ORDERS',
                    'RATING',
                    'REVENUE',
                    'VERIFIED',
                    'STATUS',
                    'ACTIONS'
                  ],
                  flexValues: const [2.5, 1.2, 1.5, 1, 1, 1.5, 1, 1.2, 2],
                ),
                if (loading)
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                else if (tailors.isEmpty)
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.design_services_outlined,
                      message: 'No tailors found',
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: tailors
                          .map(
                            (t) => Column(
                              children: [
                                AdminRow(
                                  cells: [
                                    Row(children: [
                                      AdminAvatar(
                                          name: t.name,
                                          size: 30,
                                          color: AdminColors.tailorColor),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(t.name,
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ]),
                                    Text(t.city,
                                        style: GoogleFonts.poppins(fontSize: 12)),
                                    AdminBadge(
                                        label: t.category,
                                        color: AdminColors.tailorColor),
                                    Text('${t.totalOrders}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                    Row(children: [
                                      const Icon(Icons.star_rounded,
                                          size: 13, color: AdminColors.warning),
                                      const SizedBox(width: 2),
                                      Text(t.rating.toStringAsFixed(1),
                                          style: GoogleFonts.poppins(fontSize: 12)),
                                    ]),
                                    Text(
                                        'Rs. ${(t.revenue / 1000).toStringAsFixed(0)}K',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                    t.isVerified
                                        ? const Icon(Icons.verified_rounded,
                                            size: 18, color: AdminColors.success)
                                        : const Icon(Icons.pending_outlined,
                                            size: 18, color: AdminColors.warning),
                                    statusBadge(t.status),
                                    Row(children: [
                                      _ActionBtn(
                                        icon: Icons.visibility_rounded,
                                        color: AdminColors.info,
                                        tooltip: 'View',
                                        onTap: () {},
                                      ),
                                      const SizedBox(width: 4),
                                      _ActionBtn(
                                        icon: t.status == 'Active'
                                            ? Icons.block_rounded
                                            : Icons.check_circle_rounded,
                                        color: t.status == 'Active'
                                            ? AdminColors.warning
                                            : AdminColors.success,
                                        tooltip: t.status == 'Active'
                                            ? 'Suspend'
                                            : 'Activate',
                                        onTap: () => onSuspend(t.id),
                                      ),
                                      const SizedBox(width: 4),
                                      _ActionBtn(
                                        icon: Icons.delete_rounded,
                                        color: AdminColors.error,
                                        tooltip: 'Remove',
                                        onTap: () => onRemove(t.id),
                                      ),
                                    ]),
                                  ],
                                  flexValues: const [2.5, 1.2, 1.5, 1, 1, 1.5, 1, 1.2, 2],
                                ),
                                const Divider(height: 1, color: AdminColors.border),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingTailorsTab extends StatelessWidget {
  final List<PendingVerification> pending;
  final Future<void> Function(String) onApprove;
  final void Function(String) onReject;
  final void Function(String) onRequestDocs;

  const _PendingTailorsTab({
    required this.pending,
    required this.onApprove,
    required this.onReject,
    required this.onRequestDocs,
  });

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        message: 'No pending tailor approvals',
        subMessage: 'All tailor applications have been reviewed.',
      );
    }
    return ListView(
      children: pending.map((v) => _PendingCard(
        verification: v,
        onApprove: () => onApprove(v.id),
        onReject: () => onReject(v.id),
        onRequestDocs: () => onRequestDocs(v.id),
      )).toList(),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final PendingVerification verification;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestDocs;

  const _PendingCard({
    required this.verification,
    required this.onApprove,
    required this.onReject,
    required this.onRequestDocs,
  });

  @override
  Widget build(BuildContext context) {
    final v = verification;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AdminAvatar(name: v.name, size: 48, color: AdminColors.tailorColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name,
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(
                          '${v.phone} • ${v.city} • Submitted: ${v.submittedDate}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AdminColors.textSecondary)),
                    ],
                  ),
                ),
                AdminBadge(
                  label: v.documentsSubmitted ? 'Docs Submitted' : 'Docs Missing',
                  color: v.documentsSubmitted ? AdminColors.success : AdminColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Document placeholders
            Text('Submitted Documents',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                _DocBox(label: 'CNIC Front', color: AdminColors.info),
                const SizedBox(width: 12),
                _DocBox(label: 'CNIC Back', color: AdminColors.info),
                const SizedBox(width: 12),
                _DocBox(
                    label: 'Business Proof',
                    color: v.documentsSubmitted
                        ? AdminColors.success
                        : AdminColors.border),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                AdminButton(
                  label: 'Approve',
                  icon: Icons.check_rounded,
                  color: AdminColors.success,
                  onPressed: onApprove,
                ),
                const SizedBox(width: 12),
                OutlineAdminButton(
                  label: 'Reject',
                  icon: Icons.close_rounded,
                  color: AdminColors.error,
                  onPressed: onReject,
                ),
                const SizedBox(width: 12),
                OutlineAdminButton(
                  label: 'Request More Docs',
                  icon: Icons.upload_file_rounded,
                  onPressed: onRequestDocs,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocBox extends StatelessWidget {
  final String label;
  final Color color;
  const _DocBox({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: color, fontWeight: FontWeight.w500)),
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
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

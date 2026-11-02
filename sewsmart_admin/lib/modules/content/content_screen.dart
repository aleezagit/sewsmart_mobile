import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api.dart';
import '../../core/services/admin_service.dart';
import '../../core/models/admin_models.dart';

class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen>
    with SingleTickerProviderStateMixin {
  final _service = AdminService();
  late TabController _tabController;
  List<ContentItem> _designs = [];
  List<ReviewItem> _reviews = [];
  List<FlaggedItem> _flagged = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // The three lists load together. _loading is only true for the first load,
  // so a later refresh does not rebuild the tabs.
  Future<void> _load() async {
    final designsFuture = _service.getDesigns();
    final reviewsFuture = _service.getReviews();
    final flaggedFuture = _service.getFlaggedContent();
    try {
      final designs = await designsFuture;
      final reviews = await reviewsFuture;
      final flagged = await flaggedFuture;
      if (mounted) {
        setState(() {
          _designs = designs;
          _reviews = reviews;
          _flagged = flagged;
        });
      }
    } on AdminApiException {
      // AdminApi already showed the message.
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showMessage(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.poppins()),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _removeDesign(String id) async {
    final removed = await _service.removeDesign(id);
    if (!mounted) return;
    if (!removed) {
      _showMessage('Could not remove the design.', AdminColors.error);
      return;
    }
    setState(() => _designs.removeWhere((d) => d.id == id));
    _showMessage('Design removed.', AdminColors.error);
  }

  Future<void> _removeReview(String id) async {
    final removed = await _service.removeReview(id);
    if (!mounted) return;
    if (!removed) {
      _showMessage('Could not remove the review.', AdminColors.error);
      return;
    }
    setState(() => _reviews.removeWhere((r) => r.id == id));
    _showMessage('Review removed.', AdminColors.error);
  }

  void _takeAction(FlaggedItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        String _action = 'Remove Content';
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text('Take Action', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Flagged Item: ${item.reportedItem}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text('Reason: ${item.reason}',
                      style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary)),
                  const SizedBox(height: 16),
                  Text('Action:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...['Remove Content', 'Issue Warning', 'Dismiss Report'].map((a) => RadioListTile<String>(
                    value: a,
                    groupValue: _action,
                    onChanged: (v) => setSt(() => _action = v!),
                    title: Text(a, style: GoogleFonts.poppins(fontSize: 13)),
                    dense: true,
                    activeColor: AdminColors.primary,
                  )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.poppins(color: AdminColors.textSecondary)),
              ),
              AdminButton(
                label: 'Apply Action',
                onPressed: () async {
                  Navigator.pop(ctx);
                  final resolved = await _service.resolveFlaggedContent(item.id, _action);
                  // Removing content can change the other two lists as well.
                  await _load();
                  if (!mounted) return;
                  if (resolved) {
                    _showMessage('Action applied: $_action', AdminColors.success);
                  } else {
                    _showMessage('Could not apply the action.', AdminColors.error);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  final _designColors = [
    const Color(0xFFEEF2FF),
    const Color(0xFFF0FDF4),
    const Color(0xFFFFF7ED),
    const Color(0xFFFDF2F8),
    const Color(0xFFEFF6FF),
    const Color(0xFFFEFCE8),
  ];

  final _designAccents = [
    AdminColors.primary,
    AdminColors.tailorColor,
    AdminColors.orange,
    AdminColors.customerColor,
    AdminColors.info,
    AdminColors.warning,
  ];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Content Moderation',
            subtitle: 'Review and manage platform content',
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
              Tab(text: 'Designs (${_designs.length})'),
              Tab(text: 'Reviews (${_reviews.length})'),
              Tab(text: 'Reports (${_flagged.where((f) => f.status == 'Pending').length})'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: MediaQuery.sizeOf(context).height - 260,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Designs tab
                _designs.isEmpty
                    ? const EmptyState(icon: Icons.design_services_outlined, message: 'No designs')
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _designs.length,
                        itemBuilder: (_, i) {
                          final d = _designs[i];
                          final idx = i % _designColors.length;
                          return AdminCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Design placeholder
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _designColors[idx],
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.design_services_rounded,
                                              size: 40, color: _designAccents[idx]),
                                          const SizedBox(height: 8),
                                          if (d.status == 'Flagged')
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AdminColors.error,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text('Flagged',
                                                  style: GoogleFonts.poppins(
                                                      fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.title,
                                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis),
                                      Text(d.creator,
                                          style: GoogleFonts.poppins(fontSize: 11, color: AdminColors.textSecondary),
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlineAdminButton(
                                          label: 'Remove',
                                          icon: Icons.delete_rounded,
                                          color: AdminColors.error,
                                          isSmall: true,
                                          onPressed: () => _removeDesign(d.id),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // Reviews tab
                AdminCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      TableHeader(
                        columns: const ['CUSTOMER', 'TAILOR', 'RATING', 'COMMENT', 'DATE', 'STATUS', 'ACTION'],
                        flexValues: const [1.8, 2, 0.8, 3, 1.2, 1.2, 1.2],
                      ),
                      Expanded(
                        child: _reviews.isEmpty
                            ? const EmptyState(icon: Icons.reviews_outlined, message: 'No reviews')
                            : ListView(
                                children: _reviews.map((r) => Column(
                                  children: [
                                    AdminRow(
                                      cells: [
                                        Text(r.customer, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                                        Text(r.tailor, style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.tailorColor), overflow: TextOverflow.ellipsis),
                                        Row(
                                          children: List.generate(5, (i) => Icon(
                                            i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                            size: 13,
                                            color: AdminColors.warning,
                                          )),
                                        ),
                                        Text(r.comment, style: GoogleFonts.poppins(fontSize: 11, color: AdminColors.textSecondary), overflow: TextOverflow.ellipsis, maxLines: 2),
                                        Text(r.date, style: GoogleFonts.poppins(fontSize: 11, color: AdminColors.textSecondary)),
                                        AdminBadge(
                                          label: r.status,
                                          color: r.status == 'Flagged' ? AdminColors.error : AdminColors.success,
                                        ),
                                        _ActionBtn(
                                          icon: Icons.delete_rounded,
                                          color: AdminColors.error,
                                          tooltip: 'Remove',
                                          onTap: () => _removeReview(r.id),
                                        ),
                                      ],
                                      flexValues: const [1.8, 2, 0.8, 3, 1.2, 1.2, 1.2],
                                    ),
                                    const Divider(height: 1, color: AdminColors.border),
                                  ],
                                )).toList(),
                              ),
                      ),
                    ],
                  ),
                ),

                // Reports tab
                _flagged.isEmpty
                    ? const EmptyState(icon: Icons.flag_outlined, message: 'No reports')
                    : ListView.separated(
                        itemCount: _flagged.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final f = _flagged[i];
                          return AdminCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(f.reportedItem,
                                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                                          ),
                                          statusBadge(f.status),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Reported by ${f.reporter}  •  ${f.date}',
                                          style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.flag_rounded, size: 14, color: AdminColors.error),
                                          const SizedBox(width: 4),
                                          Text('Reason: ${f.reason}',
                                              style: GoogleFonts.poppins(fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                if (f.status == 'Pending')
                                  AdminButton(
                                    label: 'Take Action',
                                    icon: Icons.gavel_rounded,
                                    isSmall: true,
                                    onPressed: () => _takeAction(f),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
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

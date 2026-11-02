import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api.dart';
import '../../core/services/admin_service.dart';
import '../../core/models/admin_models.dart';

class VerificationsScreen extends StatefulWidget {
  const VerificationsScreen({super.key});

  @override
  State<VerificationsScreen> createState() => _VerificationsScreenState();
}

class _VerificationsScreenState extends State<VerificationsScreen> {
  final _service = AdminService();
  List<PendingVerification> _all = [];
  bool _loading = true;
  String _statusFilter = 'Pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getAllVerifications();
      if (mounted) setState(() => _all = data);
    } on AdminApiException {
      // AdminApi already showed the message.
    }
    if (mounted) setState(() => _loading = false);
  }

  List<PendingVerification> get _items =>
      _all.where((v) => _statusFilter == 'All' || v.status == _statusFilter).toList();

  Future<void> _approve(String id) async {
    if (!await _service.approveVerification(id)) return;
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tailor account verified successfully!',
            style: GoogleFonts.poppins(),
          ),
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
        title: Text('Reject Application', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please provide a reason:', style: GoogleFonts.poppins(fontSize: 13, color: AdminColors.textSecondary)),
            const SizedBox(height: 12),
            AdminTextField(hint: 'Enter rejection reason...', controller: ctrl, maxLines: 3),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AdminColors.textSecondary)),
          ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Confirm Reject', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _requestMoreDocs(String id) async {
    final idx = _all.indexWhere((v) => v.id == id);
    final name = idx == -1 ? 'the applicant' : _all[idx].name;
    if (!await _service.requestMoreDocuments(id) || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Document request sent to $name.', style: GoogleFonts.poppins())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _all.where((v) => v.status == 'Pending').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Verifications',
            subtitle: 'Review and approve tailor applications',
            badge: pendingCount > 0
                ? AdminBadge(label: '$pendingCount pending', color: AdminColors.warning)
                : null,
          ),
          const SizedBox(height: 20),

          // Status filter chips
          Row(
            children: ['Pending', 'Approved', 'Rejected', 'All'].map((s) {
              final active = _statusFilter == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _statusFilter = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AdminColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? AdminColors.primary : AdminColors.border),
                    ),
                    child: Text(
                      s,
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
          const SizedBox(height: 16),

          SizedBox(
            height: MediaQuery.sizeOf(context).height - 320,
            child: _VerificationList(
              items: _items,
              loading: _loading,
              onApprove: _approve,
              onReject: _showRejectDialog,
              onRequestDocs: _requestMoreDocs,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationList extends StatelessWidget {
  final List<PendingVerification> items;
  final bool loading;
  final Future<void> Function(String) onApprove;
  final void Function(String) onReject;
  final void Function(String) onRequestDocs;

  const _VerificationList({
    required this.items,
    required this.loading,
    required this.onApprove,
    required this.onReject,
    required this.onRequestDocs,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        message: 'No applications in this category',
        subMessage: 'All applications have been reviewed.',
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final v = items[i];
        return _VerificationCard(
          verification: v,
          onApprove: () => onApprove(v.id),
          onReject: () => onReject(v.id),
          onRequestDocs: () => onRequestDocs(v.id),
        );
      },
    );
  }
}

class _VerificationCard extends StatelessWidget {
  final PendingVerification verification;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestDocs;

  const _VerificationCard({
    required this.verification,
    required this.onApprove,
    required this.onReject,
    required this.onRequestDocs,
  });

  @override
  Widget build(BuildContext context) {
    final v = verification;
    final isPending = v.status == 'Pending';
    final isApproved = v.status == 'Approved';
    const color = AdminColors.tailorColor;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              AdminAvatar(name: v.name, size: 52, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.name,
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('${v.phone}  •  ${v.city}',
                        style: GoogleFonts.poppins(fontSize: 13, color: AdminColors.textSecondary)),
                    Text('Submitted: ${v.submittedDate}',
                        style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary)),
                  ],
                ),
              ),
              statusBadge(v.status),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AdminColors.border),
          const SizedBox(height: 12),

          // Documents
          Text('Submitted Documents',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              _DocCard(label: 'CNIC Front', icon: Icons.badge_rounded, color: AdminColors.info, url: v.documents['cnicFront']),
              const SizedBox(width: 12),
              _DocCard(label: 'CNIC Back', icon: Icons.badge_outlined, color: AdminColors.info, url: v.documents['cnicBack']),
              const SizedBox(width: 12),
              _DocCard(
                label: 'Business Proof',
                icon: Icons.storefront_rounded,
                color: v.documentsSubmitted ? color : AdminColors.border,
                url: v.documents['businessProof'],
              ),
            ],
          ),

          // Show resolution info if not pending
          if (!isPending) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isApproved
                    ? AdminColors.success.withOpacity(0.08)
                    : AdminColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isApproved
                      ? AdminColors.success.withOpacity(0.25)
                      : AdminColors.error.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isApproved ? AdminColors.success : AdminColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isApproved ? 'Application approved and account activated.' : 'Application rejected.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isApproved ? AdminColors.success : AdminColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons (only for pending)
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                // Approve. The Material puts the Ink above the white card;
                // without it the gradient is painted behind the card and the button is invisible.
                Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      onTap: onApprove,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text('Approve',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlineAdminButton(
                  label: 'Reject',
                  icon: Icons.close_rounded,
                  color: AdminColors.error,
                  onPressed: onReject,
                ),
                const SizedBox(width: 10),
                OutlineAdminButton(
                  label: 'Request More Docs',
                  icon: Icons.upload_file_rounded,
                  onPressed: onRequestDocs,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// One document of a request. A sent document opens full size when tapped.
class _DocCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  // The uploaded image, or null when the document was not sent.
  final String? url;

  const _DocCard({
    required this.label,
    required this.icon,
    required this.color,
    this.url,
  });

  bool get submitted => url != null && url!.isNotEmpty;

  void _open(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
              child: InteractiveViewer(
                child: Image.network(
                  url!,
                  errorBuilder: (_, _, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('The image could not be loaded.', style: GoogleFonts.poppins()),
                  ),
                ),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: submitted ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
      width: 130,
      height: 90,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: color, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                submitted ? Icons.check_circle_rounded : Icons.help_outline_rounded,
                size: 12,
                color: submitted ? AdminColors.success : AdminColors.warning,
              ),
              const SizedBox(width: 3),
              Text(
                submitted ? 'Submitted' : 'Missing',
                style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: submitted ? AdminColors.success : AdminColors.warning),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}

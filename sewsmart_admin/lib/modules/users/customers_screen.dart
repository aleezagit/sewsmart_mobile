import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api.dart';
import '../../core/services/admin_service.dart';
import '../../core/models/admin_models.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _service = AdminService();
  List<AdminUser> _users = [];
  List<AdminUser> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _statusFilter = 'All';
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getUsers();
      if (mounted) {
        setState(() {
          _users = data;
          _filtered = data;
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
      _filtered = _users.where((u) {
        final matchSearch = _search.isEmpty ||
            u.name.toLowerCase().contains(_search.toLowerCase()) ||
            u.email.toLowerCase().contains(_search.toLowerCase()) ||
            u.city.toLowerCase().contains(_search.toLowerCase());
        final matchStatus =
            _statusFilter == 'All' || u.status == _statusFilter;
        return matchSearch && matchStatus;
      }).toList();
    });
  }

  Future<void> _toggleStatus(AdminUser user) async {
    setState(() => _processing.add(user.id));
    final ok = await _service.suspendUser(user.id, suspend: user.status == 'Active');
    if (!ok) {
      if (mounted) setState(() => _processing.remove(user.id));
      return;
    }
    await _load();
    if (mounted) {
      setState(() => _processing.remove(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.status == 'Active'
                ? 'User suspended successfully.'
                : 'User activated successfully.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor:
              user.status == 'Active' ? AdminColors.error : AdminColors.success,
        ),
      );
    }
  }

  void _showUserDetail(AdminUser user) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 480,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AdminAvatar(name: user.name, size: 56, color: AdminColors.customerColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: GoogleFonts.poppins(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(user.email,
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: AdminColors.textSecondary)),
                        ],
                      ),
                    ),
                    statusBadge(user.status),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: AdminColors.border),
                const SizedBox(height: 16),
                _DetailRow(label: 'Phone', value: user.phone),
                _DetailRow(label: 'City', value: user.city),
                _DetailRow(label: 'Role', value: user.role.toUpperCase()),
                _DetailRow(label: 'Joined', value: user.joinDate),
                _DetailRow(label: 'Total Orders', value: '${user.totalOrders}'),
                _DetailRow(
                    label: 'Total Spent',
                    value: 'Rs. ${user.totalSpent.toStringAsFixed(0)}'),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlineAdminButton(
                      label: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                    ),
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
            title: 'Customers',
            subtitle: 'Manage all registered customers',
            badge: AdminBadge(
              label: '${_filtered.length}',
              color: AdminColors.customerColor,
            ),
          ),
          const SizedBox(height: 20),

          // Filters
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AdminTextField(
                  hint: 'Search by name, email or city...',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (v) {
                    _search = v;
                    _applyFilters();
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
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AdminColors.text),
                  items: ['All', 'Active', 'Suspended']
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
            ],
          ),
          const SizedBox(height: 16),

          // Table
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                TableHeader(
                  columns: const [
                    'NAME',
                    'EMAIL',
                    'PHONE',
                    'CITY',
                    'ORDERS',
                    'STATUS',
                    'ACTIONS'
                  ],
                  flexValues: const [2, 2.5, 2, 1.5, 1, 1.5, 2.5],
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: EmptyState(
                      icon: Icons.people_outline,
                      message: 'No customers found',
                    ),
                  )
                else
                  ..._filtered.map(
                    (u) => Column(
                      children: [
                        AdminRow(
                          cells: [
                            Row(
                              children: [
                                AdminAvatar(
                                    name: u.name,
                                    size: 30,
                                    color: AdminColors.customerColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(u.name,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            Text(u.email,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AdminColors.textSecondary),
                                overflow: TextOverflow.ellipsis),
                            Text(u.phone,
                                style:
                                    GoogleFonts.poppins(fontSize: 12)),
                            Text(u.city,
                                style:
                                    GoogleFonts.poppins(fontSize: 12)),
                            Text('${u.totalOrders}',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            statusBadge(u.status),
                            Row(
                              children: [
                                _ActionBtn(
                                  icon: Icons.visibility_rounded,
                                  color: AdminColors.info,
                                  tooltip: 'View',
                                  onTap: () => _showUserDetail(u),
                                ),
                                const SizedBox(width: 4),
                                _ActionBtn(
                                  icon: u.status == 'Active'
                                      ? Icons.block_rounded
                                      : Icons.check_circle_rounded,
                                  color: u.status == 'Active'
                                      ? AdminColors.warning
                                      : AdminColors.success,
                                  tooltip: u.status == 'Active'
                                      ? 'Suspend'
                                      : 'Activate',
                                  onTap: () => _toggleStatus(u),
                                ),
                                const SizedBox(width: 4),
                                _ActionBtn(
                                  icon: Icons.delete_rounded,
                                  color: AdminColors.error,
                                  tooltip: 'Delete',
                                  onTap: () => _confirmDelete(u),
                                ),
                              ],
                            ),
                          ],
                          flexValues: const [2, 2.5, 2, 1.5, 1, 1.5, 2.5],
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

  void _confirmDelete(AdminUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Customer',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
            'Are you sure you want to permanently delete ${user.name}? This action cannot be undone.',
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
              if (await _service.deleteUser(user.id)) _load();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AdminColors.textSecondary)),
          ),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500)),
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

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

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

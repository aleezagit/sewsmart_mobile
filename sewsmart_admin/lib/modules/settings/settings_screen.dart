import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../core/api/admin_api.dart';
import '../../core/services/admin_service.dart';
import '../../core/models/admin_models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = AdminService();
  bool _loading = true;
  bool _failed = false;

  // Platform settings state. The values below only stand in until _load finishes.
  double _commissionRate = 8.5;
  final List<String> _categories = ['Bridal', 'Eastern', 'Western', 'Casual', 'Children'];
  final _newCategoryCtrl = TextEditingController();

  // Notification toggles
  bool _notifyNewOrder = true;
  bool _notifyOrderComplete = true;
  bool _notifyNewVerification = true;
  bool _notifyDispute = true;
  bool _notifyPayment = false;
  bool _notifyMarketing = false;

  // Security
  bool _twoFaEnabled = false;
  int _sessionTimeout = 30;
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newCategoryCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AdminSettings settings;
    try {
      settings = await _service.getSettings();
    } on AdminApiException {
      // AdminApi showed the message. Keep the spinner replaced by a retry.
      if (mounted) setState(() { _loading = false; _failed = true; });
      return;
    }
    if (!mounted) return;
    setState(() {
      _failed = false;
      // The slider and the dropdown only accept values inside their own range.
      _commissionRate = settings.commissionRate.clamp(2, 20).toDouble();
      _categories
        ..clear()
        ..addAll(settings.categories);
      _notifyNewOrder = settings.notifyNewOrder;
      _notifyOrderComplete = settings.notifyOrderComplete;
      _notifyNewVerification = settings.notifyNewVerification;
      _notifyDispute = settings.notifyDispute;
      _notifyPayment = settings.notifyPayment;
      _notifyMarketing = settings.notifyMarketing;
      _twoFaEnabled = settings.twoFaEnabled;
      _sessionTimeout =
          const [15, 30, 60, 120].contains(settings.sessionTimeout) ? settings.sessionTimeout : 30;
      _loading = false;
    });
  }

  // Sends the current values after a change. The screen has no Save button.
  // When the server refuses, the screen shows what the server kept.
  Future<void> _save() async {
    final saved = await _service.updateSettings(AdminSettings(
      commissionRate: _commissionRate,
      categories: List<String>.from(_categories),
      notifyNewOrder: _notifyNewOrder,
      notifyOrderComplete: _notifyOrderComplete,
      notifyNewVerification: _notifyNewVerification,
      notifyDispute: _notifyDispute,
      notifyPayment: _notifyPayment,
      notifyMarketing: _notifyMarketing,
      twoFaEnabled: _twoFaEnabled,
      sessionTimeout: _sessionTimeout,
    ));
    if (!saved) _load();
  }

  void _showMessage(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.poppins()),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _addCategory() async {
    final name = _newCategoryCtrl.text.trim();
    if (name.isEmpty || _categories.contains(name)) return;
    final added = await _service.addCategory(name);
    if (!mounted || !added) return;
    setState(() {
      _categories.add(name);
      _newCategoryCtrl.clear();
    });
  }

  Future<void> _removeCategory(String cat) async {
    final removed = await _service.removeCategory(cat);
    if (!mounted || !removed) return;
    setState(() => _categories.remove(cat));
  }

  Future<void> _savePassword() async {
    final current = _oldPassCtrl.text;
    final next = _newPassCtrl.text;
    if (current.isEmpty || next.isEmpty) {
      _showMessage('Enter your current and new password.', AdminColors.error);
      return;
    }
    if (next.length < 8) {
      _showMessage('The new password needs at least 8 characters.', AdminColors.error);
      return;
    }
    if (next != _confirmPassCtrl.text) {
      _showMessage('The new password and its confirmation do not match.', AdminColors.error);
      return;
    }
    final updated = await _service.changePassword(current, next);
    if (!mounted || !updated) return;
    _showMessage('Password updated successfully!', AdminColors.success);
    _oldPassCtrl.clear();
    _newPassCtrl.clear();
    _confirmPassCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: AdminButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: () {
          setState(() { _failed = false; _loading = true; });
          _load();
        }),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'System Settings',
            subtitle: 'Configure platform preferences and security',
          ),
          const SizedBox(height: 24),

          // ── Platform Settings ─────────────────────────────
          _SettingsSection(
            icon: Icons.tune_rounded,
            title: 'Platform Settings',
            color: AdminColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commission rate
                Text('Commission Rate', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: _commissionRate,
                                  min: 2,
                                  max: 20,
                                  divisions: 36,
                                  activeColor: AdminColors.primary,
                                  onChanged: (v) => setState(() => _commissionRate = v),
                                  onChangeEnd: (v) => _save(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AdminColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AdminColors.primary.withOpacity(0.3)),
                                ),
                                child: Text(
                                  '${_commissionRate.toStringAsFixed(1)}%',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16, fontWeight: FontWeight.w700, color: AdminColors.primary),
                                ),
                              ),
                            ],
                          ),
                          Text('Platform takes ${_commissionRate.toStringAsFixed(1)}% from each transaction',
                              style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Garment categories
                Text('Garment Categories', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) => Chip(
                    label: Text(cat, style: GoogleFonts.poppins(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => _removeCategory(cat),
                    backgroundColor: AdminColors.primary.withOpacity(0.08),
                    side: const BorderSide(color: AdminColors.primary, width: 0.5),
                    labelStyle: GoogleFonts.poppins(fontSize: 12, color: AdminColors.primary),
                    deleteIconColor: AdminColors.primary,
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AdminTextField(
                        hint: 'Add new category...',
                        controller: _newCategoryCtrl,
                        prefixIcon: Icons.add_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AdminButton(
                      label: 'Add',
                      icon: Icons.add_rounded,
                      isSmall: true,
                      onPressed: _addCategory,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Notifications ─────────────────────────────────
          _SettingsSection(
            icon: Icons.notifications_rounded,
            title: 'Notification Settings',
            color: AdminColors.info,
            child: Column(
              children: [
                _ToggleRow(
                  label: 'New Order Placed',
                  subtitle: 'Notify when a new order is placed on the platform',
                  value: _notifyNewOrder,
                  onChanged: (v) {
                    setState(() => _notifyNewOrder = v);
                    _save();
                  },
                ),
                _ToggleRow(
                  label: 'Order Completed',
                  subtitle: 'Notify when an order is marked as completed',
                  value: _notifyOrderComplete,
                  onChanged: (v) {
                    setState(() => _notifyOrderComplete = v);
                    _save();
                  },
                ),
                _ToggleRow(
                  label: 'New Verification Request',
                  subtitle: 'Notify when a tailor submits verification docs',
                  value: _notifyNewVerification,
                  onChanged: (v) {
                    setState(() => _notifyNewVerification = v);
                    _save();
                  },
                ),
                _ToggleRow(
                  label: 'Dispute Raised',
                  subtitle: 'Notify when a new dispute is opened',
                  value: _notifyDispute,
                  onChanged: (v) {
                    setState(() => _notifyDispute = v);
                    _save();
                  },
                ),
                _ToggleRow(
                  label: 'Payment Received',
                  subtitle: 'Notify on each successful payment',
                  value: _notifyPayment,
                  onChanged: (v) {
                    setState(() => _notifyPayment = v);
                    _save();
                  },
                ),
                _ToggleRow(
                  label: 'Marketing Updates',
                  subtitle: 'Receive platform marketing notifications',
                  value: _notifyMarketing,
                  onChanged: (v) {
                    setState(() => _notifyMarketing = v);
                    _save();
                  },
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Security ──────────────────────────────────────
          _SettingsSection(
            icon: Icons.security_rounded,
            title: 'Security',
            color: AdminColors.warning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2FA
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Two-Factor Authentication',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('Add an extra layer of security to your account',
                              style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _twoFaEnabled,
                      onChanged: (v) {
                        setState(() => _twoFaEnabled = v);
                        _save();
                      },
                      activeColor: AdminColors.primary,
                    ),
                    AdminBadge(
                      label: _twoFaEnabled ? 'Enabled' : 'Disabled',
                      color: _twoFaEnabled ? AdminColors.success : AdminColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AdminColors.border),
                const SizedBox(height: 16),

                // Session timeout
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Session Timeout',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('Auto-logout after $_sessionTimeout minutes of inactivity',
                              style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: DropdownButton<int>(
                        value: _sessionTimeout,
                        underline: const SizedBox(),
                        style: GoogleFonts.poppins(fontSize: 13, color: AdminColors.text),
                        items: [15, 30, 60, 120]
                            .map((t) => DropdownMenuItem(value: t, child: Text('$t min')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _sessionTimeout = v);
                          _save();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AdminColors.border),
                const SizedBox(height: 16),

                // Password change
                Text('Change Password', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AdminTextField(
                        label: 'Current Password',
                        hint: '••••••••',
                        controller: _oldPassCtrl,
                        obscureText: _obscureOld,
                        suffixIcon: _obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        onSuffixTap: () => setState(() => _obscureOld = !_obscureOld),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AdminTextField(
                        label: 'New Password',
                        hint: '••••••••',
                        controller: _newPassCtrl,
                        obscureText: _obscureNew,
                        suffixIcon: _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        onSuffixTap: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AdminTextField(
                        label: 'Confirm Password',
                        hint: '••••••••',
                        controller: _confirmPassCtrl,
                        obscureText: _obscureConfirm,
                        suffixIcon: _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AdminButton(
                  label: 'Update Password',
                  icon: Icons.lock_reset_rounded,
                  onPressed: _savePassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── About ─────────────────────────────────────────
          _SettingsSection(
            icon: Icons.info_rounded,
            title: 'About',
            color: AdminColors.tailorColor,
            child: Column(
              children: [
                _AboutRow(label: 'App Name', value: 'SewSmart Admin Panel'),
                _AboutRow(label: 'Version', value: 'v1.0.0 (Build 100)'),
                _AboutRow(label: 'Platform', value: 'Flutter Web'),
                _AboutRow(label: 'Server', value: AdminApi.baseUrl),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 10, color: AdminColors.success),
                          const SizedBox(width: 6),
                          Text('All systems operational',
                              style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.success, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
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

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AdminColors.border),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: AdminColors.textSecondary)),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AdminColors.primary,
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(color: AdminColors.border, height: 1),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;

  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 13, color: AdminColors.textSecondary)),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AdminColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

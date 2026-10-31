import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/validators.dart';
import '../services/customer_service.dart';

// The customer's delivery addresses. One of them is the default, and tailors
// deliver there. Addresses can be added, edited, made default and removed.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<AddressModel> _addresses = [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<AddressModel> addresses;
    try {
      addresses = await CustomerService().getAddresses();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
      return;
    }
    if (!mounted) return;
    setState(() {
      _loadError = null;
      // The default address first, the others in the order they were added.
      _addresses = [
        ...addresses.where((a) => a.isDefault),
        ...addresses.where((a) => !a.isDefault),
      ];
      _loading = false;
    });
  }

  Future<void> _openForm({AddressModel? address}) async {
    final saved = await showModalBottomSheet<AddressModel>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddressForm(address: address),
    );
    if (saved == null || !mounted) return;
    await _load();
    if (!mounted) return;
    showMessage(context, address == null ? 'Address added' : 'Address updated');
  }

  Future<void> _setDefault(AddressModel address) async {
    try {
      await CustomerService().setDefaultAddress(address.id);
      await _load();
      if (mounted) showMessage(context, '${_labelText(address.label)} is now your default address');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _confirmRemove(AddressModel address) {
    if (address.isDefault && _addresses.length > 1) {
      showMessage(context, 'Make another address the default before removing this one', success: false);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Address?',
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Remove ${_labelText(address.label)}: ${address.summary}?',
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _remove(address);
            },
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(AddressModel address) async {
    try {
      await CustomerService().removeAddress(address.id);
      await _load();
      if (mounted) showMessage(context, 'Address removed');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SewAppBar(title: 'Addresses', subtitle: 'Where your orders are delivered'),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2),
                      )
                    : _loadError != null
                    ? LoadError(error: _loadError!, onRetry: () {
                        setState(() => _loading = true);
                        _load();
                      })
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                        children: [
                          if (_addresses.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: EmptyState(
                                icon: Icons.location_off_outlined,
                                title: 'No addresses yet',
                                subtitle: 'Add the address where tailors should deliver your orders',
                              ),
                            ),
                          ..._addresses.map((address) => _AddressCard(
                                address: address,
                                onEdit: () => _openForm(address: address),
                                onSetDefault: () => _setDefault(address),
                                onRemove: () => _confirmRemove(address),
                              )),
                          const SizedBox(height: 6),
                          GradientButton(text: 'Add New Address', onTap: () => _openForm()),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.local_shipping_outlined, color: AppColors.textMuted, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Tailors deliver your orders to the default address.',
                                  style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final AddressModel address;
  final VoidCallback onEdit, onSetDefault, onRemove;
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onSetDefault,
    required this.onRemove,
  });

  PopupMenuItem<String> _menuItem(String value, IconData icon, String text, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.poppins(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = address;
    final landmark = a.landmark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: a.isDefault ? AppColors.primary.withValues(alpha: 0.5) : AppColors.divider,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_labelIcon(a.label), color: AppColors.primaryLight, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _labelText(a.label),
                      style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (a.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Default',
                          style: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(a.street, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                Text('${a.area}, ${a.city}', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                if (landmark != null)
                  Text(landmark, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(a.phone, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.cardAlt,
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'default') onSetDefault();
              if (value == 'remove') onRemove();
            },
            itemBuilder: (_) => [
              _menuItem('edit', Icons.edit_outlined, 'Edit', AppColors.textPrimary),
              if (!a.isDefault)
                _menuItem('default', Icons.check_circle_outline_rounded, 'Set as Default', AppColors.success),
              _menuItem('remove', Icons.delete_outline_rounded, 'Remove', AppColors.error),
            ],
          ),
        ],
      ),
    );
  }
}

// Add an address, or edit [address]. Pops with the saved address.
class _AddressForm extends StatefulWidget {
  final AddressModel? address;
  const _AddressForm({this.address});

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  static const _labels = ['home', 'work', 'other'];

  late String _label = widget.address?.label ?? 'home';
  late final TextEditingController _streetCtrl = TextEditingController(text: widget.address?.street ?? '');
  late final TextEditingController _areaCtrl = TextEditingController(text: widget.address?.area ?? '');
  late final TextEditingController _cityCtrl =
      TextEditingController(text: widget.address?.city ?? AuthService().currentUser?.city ?? '');
  late final TextEditingController _phoneCtrl =
      TextEditingController(text: widget.address?.phone ?? AuthService().currentUser?.phone ?? '');
  late final TextEditingController _landmarkCtrl = TextEditingController(text: widget.address?.landmark ?? '');
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.address != null;

  @override
  void dispose() {
    _streetCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  String? _problem() {
    if (_streetCtrl.text.trim().length < 3) return 'Enter the house number and street';
    if (_areaCtrl.text.trim().isEmpty) return 'Enter the area or sector';
    if (_cityCtrl.text.trim().isEmpty) return 'Enter the city';
    if (!Validators.isMobile(_phoneCtrl.text)) return 'Enter a valid mobile number, e.g. 0300-1234567';
    return null;
  }

  Future<void> _save() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final existing = widget.address;
    final AddressModel saved;
    try {
      if (existing == null) {
        saved = await CustomerService().addAddress(
          label: _label,
          street: _streetCtrl.text,
          area: _areaCtrl.text,
          city: _cityCtrl.text,
          phone: _phoneCtrl.text,
          landmark: _landmarkCtrl.text,
        );
      } else {
        saved = await CustomerService().updateAddress(
          id: existing.id,
          label: _label,
          street: _streetCtrl.text,
          area: _areaCtrl.text,
          city: _cityCtrl.text,
          phone: _phoneCtrl.text,
          landmark: _landmarkCtrl.text,
        );
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = '$e'; });
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _isEdit ? 'Edit Address' : 'Add Address',
              style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 16),
            Row(
              children: _labels
                  .map((label) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoicePill(
                          label: _labelText(label),
                          selected: _label == label,
                          onTap: () => setState(() => _label = label),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            AppTextField(
              ctrl: _streetCtrl,
              hint: 'House or flat number and street',
              label: 'House and street',
              icon: Icons.home_outlined,
            ),
            const SizedBox(height: 12),
            AppTextField(
              ctrl: _areaCtrl,
              hint: 'Area or sector, e.g. Gulberg III',
              label: 'Area',
              icon: Icons.map_outlined,
            ),
            const SizedBox(height: 12),
            AppTextField(ctrl: _cityCtrl, hint: 'City', label: 'City', icon: Icons.location_city_outlined),
            const SizedBox(height: 12),
            AppTextField(
              ctrl: _phoneCtrl,
              hint: 'Phone number for delivery',
              label: 'Phone',
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            AppTextField(
              ctrl: _landmarkCtrl,
              hint: 'A place that is easy to find',
              label: 'Landmark (optional)',
              icon: Icons.place_outlined,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            GradientButton(text: _isEdit ? 'Save Changes' : 'Save Address', onTap: _save, loading: _saving),
          ],
        ),
      ),
    );
  }
}

String _labelText(String label) {
  switch (label) {
    case 'home':
      return 'Home';
    case 'work':
      return 'Work';
    default:
      return 'Other';
  }
}

IconData _labelIcon(String label) {
  switch (label) {
    case 'home':
      return Icons.home_rounded;
    case 'work':
      return Icons.work_rounded;
    default:
      return Icons.location_on_rounded;
  }
}

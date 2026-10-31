import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/support_service.dart';
import '../../../core/utils/app_refresh.dart';
import '../../support/screens/raise_dispute_screen.dart';
import '../services/tailor_service.dart';
import 'tailor_chat_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  // Replaced by the server's copy after each change.
  late OrderModel _order = widget.order;
  bool _updatingStatus = false;
  bool _sendingRequest = false;
  // A dispute about this order, raised by the tailor or the customer.
  DisputeModel? _dispute;

  OrderStatus get _status => _order.status;

  bool get _showsDelivery =>
      _status == OrderStatus.readyForDelivery ||
      _status == OrderStatus.delivered ||
      _status == OrderStatus.completed;

  // The card only replaces the report link, so a failed load keeps the link.
  Future<void> _loadDispute() async {
    try {
      final disputes = await SupportService().getMyDisputes();
      if (!mounted) return;
      setState(() => _dispute = disputes.where((d) => d.orderId == _order.id).firstOrNull);
    } catch (_) {}
  }

  Future<void> _reportProblem() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RaiseDisputeScreen(order: _order, byTailor: true)),
    );
    if (mounted) _loadDispute();
  }

  final List<OrderStatus> _statusChips = [
    OrderStatus.accepted,
    OrderStatus.inProgress,
    OrderStatus.qualityCheck,
    OrderStatus.readyForDelivery,
    OrderStatus.delivered,
  ];

  @override
  void initState() {
    super.initState();
    _loadDispute();
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.accepted:
        return AppColors.info;
      case OrderStatus.inProgress:
        return AppColors.primary;
      case OrderStatus.qualityCheck:
        return AppColors.secondary;
      case OrderStatus.readyForDelivery:
        return AppColors.teal;
      case OrderStatus.delivered:
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.qualityCheck:
        return 'Quality Check';
      case OrderStatus.readyForDelivery:
        return 'Ready';
      case OrderStatus.delivered:
        return 'Delivered';
      default:
        return s.name;
    }
  }

  Future<void> _updateStatus(OrderStatus status) async {
    if (status == OrderStatus.readyForDelivery) {
      _showDeliveryRequestDialog();
      return;
    }
    if (status == OrderStatus.delivered && !await _confirmDelivered()) return;
    setState(() => _updatingStatus = true);
    try {
      final updated = await TailorService().updateOrderStatus(_order.id, status);
      AppRefresh.ordersChanged();
      if (!mounted) return;
      setState(() => _order = updated);
      showMessage(context, 'Status updated to ${_statusLabel(status)}');
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _updatingStatus = false);
  }

  // Marks the order ready, then asks the customer to choose delivery times.
  Future<void> _markReadyAndRequestDelivery() async {
    setState(() => _sendingRequest = true);
    final service = TailorService();
    try {
      if (_order.status != OrderStatus.readyForDelivery) {
        final updated = await service.updateOrderStatus(_order.id, OrderStatus.readyForDelivery);
        if (mounted) setState(() => _order = updated);
      }
      await service.sendDeliveryRequest(_order.id);
      AppRefresh.ordersChanged();
      if (mounted) showMessage(context, 'Delivery request sent!');
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _sendingRequest = false);
  }

  // Delivered cannot be undone, and it starts the customer's three days to
  // report a problem, so ask first.
  Future<bool> _confirmDelivered() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mark as Delivered?',
            style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text(
          'Confirm that ${_order.customerName} has received the ${_order.garmentType}.',
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delivered', style: GoogleFonts.poppins(color: AppColors.success, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _showDeliveryRequestDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Send Delivery Request?',
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: Text(
          'This will notify ${_order.customerName} to choose a delivery time for their order.',
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              _markReadyAndRequestDelivery();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.teal, AppColors.tealLight]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Send Request',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Orders store measurements as "Chest 36, Waist 30, Hips 38, Length 40,
  // Shoulder 15 (in)". A value the order does not have shows as '-'.
  Map<String, String> get _measurements {
    const names = ['Chest', 'Waist', 'Hips', 'Length', 'Shoulder'];
    final values = {
      for (final match in RegExp(r'(Chest|Waist|Hips|Length|Shoulder)\s+([\d.]+)').allMatches(_order.measurements))
        match.group(1)!: match.group(2)!,
    };
    return {for (final name in names) name: values[name] == null ? '-' : '${values[name]}"'};
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        orb1: AppColors.tealOrb,
        orb2: AppColors.purpleOrb,
        child: SafeArea(
          child: Column(
            children: [
              SewAppBar(
                title: 'Order Detail',
                subtitle: order.id,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderHeader(order),
                      const SizedBox(height: 20),
                      Divider(color: AppColors.divider),
                      const SizedBox(height: 16),
                      _buildMeasurements(),
                      if (order.hasDesignRef) ...[
                        const SizedBox(height: 20),
                        _buildDesignRef(),
                      ],
                      const SizedBox(height: 20),
                      _buildStatusUpdate(),
                      if (_showsDelivery) ...[
                        const SizedBox(height: 20),
                        _buildDeliverySection(),
                      ],
                      const SizedBox(height: 30),
                      _buildChatButton(context, order),
                      const SizedBox(height: 12),
                      if (_dispute case final dispute?)
                        DisputeStatusCard(dispute: dispute)
                      else
                        Center(
                          child: TextButton.icon(
                            onPressed: _reportProblem,
                            icon: Icon(Icons.report_problem_outlined, color: AppColors.textMuted, size: 16),
                            label: Text(
                              'Report a problem with this order',
                              style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
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

  Widget _buildOrderHeader(OrderModel order) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.checkroom_rounded, color: AppColors.tealLight, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.garmentType,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      order.customerName,
                      style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: order.statusLabel,
                color: _statusColor(order.status),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoItem(label: 'Order ID', value: order.id),
              _InfoItem(label: 'Amount', value: 'Rs ${order.amount.toInt()}'),
              _InfoItem(
                label: 'Date',
                value: '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurements() {
    final m = _measurements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Measurements',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: Column(
            children: m.entries.toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final kv = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(Icons.straighten_rounded, color: AppColors.tealLight, size: 14),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          kv.key,
                          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          kv.value,
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (idx < m.length - 1) Divider(color: AppColors.divider, height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDesignRef() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Design Reference',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        if (_order.designRefUrl case final url?)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(url, height: 220, width: double.infinity, fit: BoxFit.cover),
          )
        else
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.image_rounded, color: AppColors.primaryLight, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                'The customer has not sent the picture yet',
                style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusUpdate() {
    // A status only moves forward. A pending order is accepted or rejected on
    // the Orders list first, and a finished order cannot change any more.
    final current = _statusChips.indexOf(_order.status);
    if (current == -1) {
      final status = _order.status;
      final note = status == OrderStatus.pending
          ? 'Accept this order on the Orders screen before updating its status.'
          // The other statuses here are rejected, cancelled and completed.
          : 'This order is ${status.name}. Its status can no longer be changed.';
      return GlassCard(
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(note, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
            ),
          ],
        ),
      );
    }
    final busy = _updatingStatus || _sendingRequest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Update Status',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            if (_updatingStatus || _sendingRequest)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(color: AppColors.tealLight, strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _statusChips.map((status) {
            final isSelected = _status == status;
            final color = _statusColor(status);
            final canPick = !busy && _statusChips.indexOf(status) > current;
            return GestureDetector(
              onTap: canPick ? () => _updateStatus(status) : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: canPick || isSelected ? 1 : 0.4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.2) : AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? color : AppColors.divider,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: GoogleFonts.poppins(
                      color: isSelected ? color : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Where and when the tailor delivers the order. The address is the
  // customer's default address when the order was placed.
  Widget _buildDeliverySection() {
    final when = _order.scheduledDelivery;
    final rows = <(IconData, String)>[
      (Icons.location_on_rounded, _order.deliveryAddress ?? 'The customer has not saved an address yet. Ask them in the chat.'),
      if (when != null)
        (Icons.schedule_rounded, '${when.day}/${when.month}/${when.year}${_order.deliverySlot == null ? '' : ', ${_order.deliverySlot}'}')
      else if (_order.deliveryRequested)
        (Icons.hourglass_top_rounded, 'Waiting for the customer to choose a delivery time'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery',
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: Column(
            children: [
              for (final (icon, text) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: AppColors.tealLight, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(text, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatButton(BuildContext context, OrderModel order) {
    return GradientButton(
      text: 'Chat with Customer',
      colors: [AppColors.teal, AppColors.tealLight],
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TailorChatScreen(
            contactName: order.customerName,
            orderId: order.id,
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label, value;
  const _InfoItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

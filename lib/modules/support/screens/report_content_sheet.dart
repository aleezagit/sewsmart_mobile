import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/services/support_service.dart';

// Reports a review, a design or a tailor profile to the admin, who sees it on
// the Reports tab of the Content screen. targetType is review, design or
// profile. A message on the screen below confirms that the report was sent.
Future<void> showReportContentSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  required String itemLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ReportSheet(targetType: targetType, targetId: targetId, itemLabel: itemLabel),
  );
}

class _ReportSheet extends StatefulWidget {
  final String targetType, targetId, itemLabel;
  const _ReportSheet({required this.targetType, required this.targetId, required this.itemLabel});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = {
    'review': ['Fake or misleading', 'Offensive language', 'Spam or advertising', 'Not about this tailor', 'Other'],
    'design': ['Copied from someone else', 'Inappropriate image', 'Misleading price or details', 'Spam', 'Other'],
    'profile': ['Fake business', 'Scam or fraud', 'Offensive content', 'Pretending to be someone else', 'Other'],
  };

  final _detailsCtrl = TextEditingController();
  String? _reason;
  bool _sending = false;
  String? _error;

  List<String> get _options => _reasons[widget.targetType] ?? _reasons['profile']!;

  String get _title {
    switch (widget.targetType) {
      case 'review':
        return 'Report Review';
      case 'design':
        return 'Report Design';
      default:
        return 'Report Profile';
    }
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Choose a reason');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await SupportService().reportContent(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: reason,
        details: _detailsCtrl.text,
      );
    } catch (e) {
      if (mounted) setState(() { _sending = false; _error = '$e'; });
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text('Thanks. Our team will review this report.', style: GoogleFonts.poppins()),
      backgroundColor: AppColors.success,
    ));
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
            Row(
              children: [
                Icon(Icons.flag_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  _title,
                  style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.itemLabel,
              style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            Text(
              'Why are you reporting this?',
              style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _options
                  .map((reason) => ChoicePill(
                        label: reason,
                        selected: _reason == reason,
                        color: AppColors.error,
                        onTap: () => setState(() {
                          _reason = reason;
                          _error = null;
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            AppTextField(ctrl: _detailsCtrl, hint: 'Add details (optional)', maxLines: 3),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            GradientButton(
              text: 'Send Report',
              onTap: _send,
              loading: _sending,
              colors: [AppColors.error, Color(0xFFF87171)],
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'The person you report is not told who reported them.',
                style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

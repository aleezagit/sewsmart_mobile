import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../services/customer_service.dart';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  bool _isCm = true;
  bool _saving = false;
  bool _loading = true;

  static const _weight = 'Weight (kg)';

  // Body measurements in the unit shown. Weight is always in kilograms.
  final Map<String, TextEditingController> _ctrls = {
    for (final label in ['Height', _weight, 'Chest', 'Waist', 'Hips', 'Shoulder', 'Arm Length', 'Inseam', 'Neck', 'Wrist'])
      label: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Fills the form with the set saved last time. A new customer starts empty.
  Future<void> _load() async {
    try {
      final saved = await CustomerService().getMeasurements();
      if (!mounted) return;
      if (saved != null) {
        _isCm = saved.unit == 'cm';
        final values = {
          'Height': saved.height, _weight: saved.weight, 'Chest': saved.chest,
          'Waist': saved.waist, 'Hips': saved.hips, 'Shoulder': saved.shoulder,
          'Arm Length': saved.armLength, 'Inseam': saved.inseam,
          'Neck': saved.neck, 'Wrist': saved.wrist,
        };
        values.forEach((label, value) => _ctrls[label]!.text = _format(value));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _format(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble() ? rounded.toInt().toString() : rounded.toStringAsFixed(1);
  }

  double _value(String label) => double.parse(_ctrls[label]!.text.trim());

  // Switches the unit and converts every length, so 91 cm becomes 35.8 in.
  void _setUnit(bool toCm) {
    if (toCm == _isCm) return;
    setState(() {
      _isCm = toCm;
      for (final entry in _ctrls.entries) {
        if (entry.key == _weight) continue;
        final value = double.tryParse(entry.value.text.trim());
        if (value == null) continue;
        entry.value.text = _format(toCm ? value * 2.54 : value / 2.54);
      }
    });
  }

  final Map<String, IconData> _icons = {
    'Height': Icons.height_rounded,
    'Weight (kg)': Icons.monitor_weight_outlined,
    'Chest': Icons.radio_button_checked_rounded,
    'Waist': Icons.sync_alt_rounded,
    'Hips': Icons.circle_outlined,
    'Shoulder': Icons.horizontal_rule_rounded,
    'Arm Length': Icons.front_hand_outlined,
    'Inseam': Icons.vertical_align_bottom_rounded,
    'Neck': Icons.radio_button_unchecked_rounded,
    'Wrist': Icons.watch_later_outlined,
  };

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final missing = _ctrls.entries
        .where((e) => Validators.positiveNumber(e.value.text) == null)
        .map((e) => e.key)
        .toList();
    if (missing.isNotEmpty) {
      showMessage(context, 'Enter a number for ${missing.join(', ')}', success: false);
      return;
    }
    setState(() => _saving = true);
    try {
      await CustomerService().saveMeasurements(MeasurementModel(
        unit: _isCm ? 'cm' : 'in',
        height: _value('Height'), weight: _value(_weight), chest: _value('Chest'),
        waist: _value('Waist'), hips: _value('Hips'), shoulder: _value('Shoulder'),
        armLength: _value('Arm Length'), inseam: _value('Inseam'),
        neck: _value('Neck'), wrist: _value('Wrist'),
      ));
      if (mounted) showMessage(context, 'Measurements saved successfully!');
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        orb1: AppColors.pinkOrb,
        orb2: AppColors.tealOrb,
        orb3: AppColors.purpleOrb,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2))
                    : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildBodyCard(),
                      const SizedBox(height: 20),
                      _buildUnitToggle(),
                      const SizedBox(height: 20),
                      _buildFieldsGrid(),
                      const SizedBox(height: 20),
                      _buildTipsCard(),
                      const SizedBox(height: 24),
                      GradientButton(
                        text: 'Save Measurements',
                        loading: _saving,
                        onTap: _save,
                        colors: [AppColors.secondary, const Color(0xFFEC4899)],
                      ),
                      const SizedBox(height: 12),
                      _buildScanButton(),
                      const SizedBox(height: 40),
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

  // ── App Bar ──────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.textPrimary, size: 20),
          ),
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [AppColors.secondary, Color(0xFFEC4899)],
            ).createShader(b),
            child: const Icon(Icons.straighten_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Smart Measure',
                  style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17)),
              Text('Your body measurements',
                  style: GoogleFonts.poppins(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Body Card ────────────────────────────────────────────────────────────────
  Widget _buildBodyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Body Measurements',
                    style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'Keep these up to date for a perfect custom fit from your tailor.',
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.45),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _Pill('${_ctrls.length} Fields', AppColors.secondary),
                  const SizedBox(width: 8),
                  _Pill(_isCm ? 'cm' : 'inches', AppColors.teal),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 78,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: [AppColors.secondary, Color(0xFFEC4899)],
                ).createShader(b),
                child: const Icon(Icons.accessibility_new_rounded,
                    color: Colors.white, size: 52),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Unit Toggle ──────────────────────────────────────────────────────────────
  Widget _buildUnitToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _setUnit(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _isCm
                      ? LinearGradient(
                          colors: [AppColors.secondary, Color(0xFFEC4899)])
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('Centimeters (cm)',
                      style: GoogleFonts.poppins(
                          color: _isCm
                              ? Colors.white
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _setUnit(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: !_isCm
                      ? LinearGradient(
                          colors: [AppColors.secondary, Color(0xFFEC4899)])
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('Inches (in)',
                      style: GoogleFonts.poppins(
                          color: !_isCm
                              ? Colors.white
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Fields Grid ──────────────────────────────────────────────────────────────
  Widget _buildFieldsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.tune_rounded, color: AppColors.secondary, size: 16),
          const SizedBox(width: 6),
          Text('Measurements',
              style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const Spacer(),
          Text(_isCm ? 'in centimeters' : 'in inches',
              style: GoogleFonts.poppins(
                  color: AppColors.textMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: _ctrls.entries
              .map((entry) => _MeasureField(
                    label: entry.key,
                    ctrl: entry.value,
                    icon: _icons[entry.key] ?? Icons.straighten_rounded,
                    unit: entry.key == _weight ? 'kg' : (_isCm ? 'cm' : 'in'),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Tips Card ────────────────────────────────────────────────────────────────
  Widget _buildTipsCard() {
    const tips = [
      'Stand straight and relaxed when measuring',
      'Use a soft, flexible measuring tape',
      'Chest — measure around the fullest part',
      'Waist — measure at the narrowest point',
      'Keep the tape parallel to the floor',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb_outline_rounded,
                color: AppColors.info, size: 16),
            const SizedBox(width: 6),
            Text('Tips for Accurate Measurements',
                style: GoogleFonts.poppins(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ',
                      style: GoogleFonts.poppins(
                          color: AppColors.info, fontSize: 11)),
                  Expanded(
                    child: Text(tip,
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scan Button ──────────────────────────────────────────────────────────────
  Widget _buildScanButton() {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AR body scan coming soon!',
              style: GoogleFonts.poppins()),
          backgroundColor: AppColors.info,
          duration: const Duration(seconds: 2),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.info.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_enhance_rounded,
                color: AppColors.info, size: 20),
            const SizedBox(width: 8),
            Text('Auto-Scan with Camera (AR)',
                style: GoogleFonts.poppins(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 11)),
      );
}

class _MeasureField extends StatelessWidget {
  final String label, unit;
  final IconData icon;
  final TextEditingController ctrl;
  const _MeasureField(
      {required this.label,
      required this.unit,
      required this.icon,
      required this.ctrl});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.textMuted, size: 11),
              const SizedBox(width: 3),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.poppins(
                        color: AppColors.textMuted, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(unit,
                  style: GoogleFonts.poppins(
                      color: AppColors.textMuted, fontSize: 10)),
            ]),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      );
}

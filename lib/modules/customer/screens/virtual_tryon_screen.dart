import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/image_picking.dart';
import '../services/customer_service.dart';

class VirtualTryOnScreen extends StatefulWidget {
  const VirtualTryOnScreen({super.key});

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen>
    with SingleTickerProviderStateMixin {
  final _commandCtrl = TextEditingController();
  // The full-body photo the customer picked.
  XFile? _photo;
  // The photo of the garment to try on.
  XFile? _garment;
  bool _processing = false;
  TryOnResult? _result;
  bool _saving = false;
  bool get _hasResult => _result != null;
  String _selectedGarment = 'Bridal Lehenga';
  late AnimationController _spinCtrl;
  // How the result is shown: turned left or right around its middle, and zoomed.
  double _angle = 0;
  bool _zoomed = false;

  void _turn(double delta) => setState(() => _angle = (_angle + delta).clamp(-1.0, 1.0));

  final _garments = [
    'Bridal Lehenga',
    'Shalwar Kameez',
    'Formal Dress',
    'Anarkali',
    'Palazzo Suit',
    'Western Outfit',
  ];

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _commandCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyTryOn() async {
    if (_photo == null || _garment == null) {
      showMessage(context, _photo == null ? 'Please add your photo first' : 'Please add the dress photo', success: false);
      return;
    }
    setState(() {
      _processing = true;
      _result = null;
      _angle = 0;
      _zoomed = false;
    });
    // The server waits for the try-on service to render the image.
    try {
      final result = await CustomerService().generateTryOn(
        photo: _photo!,
        garment: _garment!,
        garmentType: _selectedGarment,
        command: _commandCtrl.text,
      );
      if (mounted) setState(() { _processing = false; _result = result; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      showError(context, e);
    }
  }

  Future<void> _pickPhoto() async {
    final photo = await pickImage(context, title: 'Your full-body photo');
    if (photo != null && mounted) setState(() { _photo = photo; _result = null; });
  }

  Future<void> _pickGarment() async {
    final garment = await pickImage(context, title: 'Photo of the dress');
    if (garment != null && mounted) setState(() { _garment = garment; _result = null; });
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null || result.isSaved || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await CustomerService().saveTryOn(result.id);
      if (!mounted) return;
      setState(() => _result = saved);
      showMessage(context, 'Try-on saved!');
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
        orb1: AppColors.tealOrb,
        orb2: AppColors.purpleOrb,
        orb3: AppColors.pinkOrb,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildViewer(),
                      const SizedBox(height: 24),
                      _buildUploadSection(),
                      const SizedBox(height: 20),
                      _buildGarmentSelector(),
                      const SizedBox(height: 20),
                      _buildCommandSection(),
                      const SizedBox(height: 28),
                      GradientButton(
                        text: _processing
                            ? 'Processing...'
                            : 'Apply Virtual Try-On',
                        loading: _processing,
                        onTap: _applyTryOn,
                        colors: [AppColors.teal, AppColors.tealLight],
                      ),
                      if (_hasResult) ...[
                        const SizedBox(height: 24),
                        _buildResultPanel(),
                      ],
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
              colors: [AppColors.teal, AppColors.tealLight],
            ).createShader(b),
            child: const Icon(Icons.view_in_ar_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Virtual Try-On',
                  style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17)),
              Text('See yourself in any outfit',
                  style: GoogleFonts.poppins(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
            ),
            child: Text('AI Try-On',
                style: GoogleFonts.poppins(
                    color: AppColors.tealLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Result viewer ────────────────────────────────────────────────────────────────
  Widget _buildViewer() {
    return Container(
      height: 270,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.teal.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          // Rotating decorative ring
          Center(
            child: RotationTransition(
              turns: _spinCtrl,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.15),
                      width: 1.5),
                ),
              ),
            ),
          ),
          Center(
            child: RotationTransition(
              turns: Tween(begin: 1.0, end: 0.0).animate(_spinCtrl),
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      width: 1),
                ),
              ),
            ),
          ),
          // Model content
          Center(
            child: _hasResult
                ? TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: _angle),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, angle, child) => Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015)
                        ..rotateY(angle),
                      child: child,
                    ),
                    child: AnimatedScale(
                      scale: _zoomed ? 1.3 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      child: _ModelResult(result: _result!),
                    ),
                  )
                : _ModelPlaceholder(),
          ),
          // Top-right badge
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.card.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('Try-On View',
                      style: GoogleFonts.poppins(
                          color: AppColors.tealLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          // Rotate controls (visible after result)
          if (_hasResult)
            Positioned(
              bottom: 14,
              right: 14,
              child: Row(
                children: [
                  _ViewBtn(Icons.rotate_left_rounded, onTap: () => _turn(-0.5)),
                  const SizedBox(width: 6),
                  _ViewBtn(Icons.rotate_right_rounded, onTap: () => _turn(0.5)),
                  const SizedBox(width: 6),
                  _ViewBtn(
                    _zoomed ? Icons.zoom_out_rounded : Icons.zoom_in_rounded,
                    onTap: () => setState(() => _zoomed = !_zoomed),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Upload Section ───────────────────────────────────────────────────────────
  Widget _buildUploadSection() {
    return Column(
      children: [
        _UploadTile(
          title: 'Your Photo',
          hint: 'A full-body photo, standing straight, in plain clothes',
          icon: Icons.person_rounded,
          file: _photo,
          onTap: _pickPhoto,
        ),
        const SizedBox(height: 12),
        _UploadTile(
          title: 'Dress Photo',
          hint: 'A clear photo of the dress on its own, on a plain background',
          icon: Icons.checkroom_rounded,
          file: _garment,
          onTap: _pickGarment,
        ),
      ],
    );
  }

  Widget _buildGarmentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.checkroom_rounded,
              color: AppColors.tealLight, size: 16),
          const SizedBox(width: 6),
          Text('Select Garment',
              style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _garments
                .map((g) => GestureDetector(
                      onTap: () => setState(() => _selectedGarment = g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedGarment == g
                              ? AppColors.teal.withValues(alpha: 0.18)
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedGarment == g
                                ? AppColors.teal
                                : AppColors.divider,
                          ),
                        ),
                        child: Text(g,
                            style: GoogleFonts.poppins(
                                color: _selectedGarment == g
                                    ? AppColors.tealLight
                                    : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: _selectedGarment == g
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ── Command Section ──────────────────────────────────────────────────────────
  // Helps the model with details the photo does not show, such as the fabric.
  Widget _buildCommandSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.edit_note_rounded, color: AppColors.primaryLight, size: 18),
          const SizedBox(width: 6),
          Text('Describe the Garment (optional)',
              style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        AppTextField(
          hint: 'E.g. Long red silk lehenga with gold embroidery',
          icon: Icons.auto_awesome_rounded,
          ctrl: _commandCtrl,
          maxLines: 2,
        ),
      ],
    );
  }

  // ── Result Panel ─────────────────────────────────────────────────────────────
  Widget _buildResultPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text('Try-On Ready!',
                style: GoogleFonts.poppins(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 8),
          Text(
            'Your virtual try-on for "${_result?.garmentType ?? _selectedGarment}" is ready. '
            'Use the buttons on the picture above to turn it and zoom in.',
            style: GoogleFonts.poppins(
                color: AppColors.textSecondary, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppColors.success, Color(0xFF16A34A)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(_result?.isSaved == true ? 'Saved ✓' : _saving ? 'Saving...' : 'Save Design',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => showComingSoon(context, 'Sharing try-on results'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text('Share',
                        style: GoogleFonts.poppins(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Model Widgets ──────────────────────────────────────────────────────────────

class _ModelPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [AppColors.teal, AppColors.primary],
            ).createShader(b),
            child: const Icon(Icons.person_outline_rounded,
                color: Colors.white, size: 82),
          ),
          const SizedBox(height: 10),
          Text('Try-On Preview',
              style: GoogleFonts.poppins(
                  color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 2),
          Text('Add your photo and the dress',
              style: GoogleFonts.poppins(
                  color: AppColors.textMuted, fontSize: 11)),
        ],
      );
}

// The image the try-on service rendered.
class _ModelResult extends StatelessWidget {
  final TryOnResult result;
  const _ModelResult({required this.result});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          result.resultUrl,
          height: 240,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : SizedBox(height: 240, width: 160, child: Center(child: CircularProgressIndicator(color: AppColors.tealLight, strokeWidth: 2))),
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );

  Widget _fallback() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.teal, AppColors.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_rounded,
                    color: Colors.white, size: 56),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(result.garmentType,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ],
      );
}

class _ViewBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ViewBtn(this.icon, {required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(icon, color: AppColors.tealLight, size: 15),
        ),
      );
}

// A photo the customer adds: a thumbnail once it is picked, and a prompt before.
class _UploadTile extends StatelessWidget {
  final String title, hint;
  final IconData icon;
  final XFile? file;
  final VoidCallback onTap;
  const _UploadTile({required this.title, required this.hint, required this.icon, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final picked = file != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: picked ? AppColors.success.withValues(alpha: 0.07) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: picked ? AppColors.success.withValues(alpha: 0.4) : AppColors.divider),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: picked
                    ? FutureBuilder<Uint8List>(
                        future: file!.readAsBytes(),
                        builder: (context, snapshot) => snapshot.hasData
                            ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                            : const SizedBox.shrink(),
                      )
                    : Container(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        child: Icon(icon, color: AppColors.primaryLight, size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(picked ? '$title added' : title,
                      style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(picked ? 'Tap to change' : hint,
                      style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Icon(picked ? Icons.check_circle_rounded : Icons.add_a_photo_rounded,
                color: picked ? AppColors.success : AppColors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

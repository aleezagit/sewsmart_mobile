import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/validators.dart';
import '../../../core/services/auth_service.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _errorMsg;
  late AnimationController _successCtrl;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _successScale = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMsg = 'Please enter your email address');
      return;
    }
    if (!Validators.isEmail(email)) {
      setState(() => _errorMsg = 'Please enter a valid email address');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await AuthService().forgotPassword(email);
      if (!mounted) return;
      setState(() { _loading = false; _sent = true; });
      _successCtrl.forward();
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 20),
                if (!_sent) _buildFormState() else _buildSuccessState(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.lock_reset_rounded, color: AppColors.primaryLight, size: 30),
        ),
        const SizedBox(height: 20),
        Text(
          'Forgot Password?',
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "No worries! Enter your email and we'll send you a reset code.",
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 32),
        AppTextField(
          ctrl: _emailCtrl,
          hint: 'Email address',
          icon: Icons.email_outlined,
          keyboard: TextInputType.emailAddress,
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_errorMsg!, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        GradientButton(
          text: 'Send Reset Link',
          onTap: _sendResetLink,
          loading: _loading,
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, color: AppColors.primaryLight, size: 16),
                const SizedBox(width: 6),
                Text('Back to Sign In', style: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Center(
          child: ScaleTransition(
            scale: _successScale,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4), width: 2),
              ),
              child: Icon(Icons.mark_email_read_rounded, color: AppColors.success, size: 46),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Check Your Email',
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a password reset code to',
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          _emailCtrl.text.trim(),
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The code expires in 15 minutes. If you did not receive it, check your spam folder.',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        GradientButton(
          text: 'Enter Reset Code',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: _emailCtrl.text.trim())),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            height: 50,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Text(
                'Back to Sign In',
                style: GoogleFonts.poppins(color: AppColors.primaryLight, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () {
              setState(() { _sent = false; _emailCtrl.clear(); _successCtrl.reset(); });
            },
            child: Text(
              'Try a different email',
              style: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/auth_service.dart';
import 'login_screen.dart';

// The second step of a password reset. The reset email sent to [email]
// carries a code, and the user types it here with the new password.
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  bool _resending = false;
  bool _done = false;
  String? _errorMsg;

  String get _email => widget.email.trim();

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // What to fix before sending, or null. The register screen asks for at least
  // 4 characters, so a new password follows the same rule.
  String? _problem() {
    if (_codeCtrl.text.trim().isEmpty) return 'Enter the reset code from the email';
    final password = _passCtrl.text.trim();
    if (password.length < 4) return 'Password must be at least 4 characters';
    if (password != _confirmCtrl.text.trim()) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _errorMsg = problem);
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await AuthService().resetPassword(_codeCtrl.text.trim(), _passCtrl.text.trim());
      if (mounted) setState(() { _loading = false; _done = true; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = e.message; });
    }
  }

  // Sends a fresh email.
  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      await AuthService().forgotPassword(_email);
      if (mounted) showMessage(context, 'A new code was sent to $_email');
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _resending = false);
  }

  void _backToSignIn() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
                  onPressed: _done ? _backToSignIn : () => Navigator.pop(context),
                ),
                const SizedBox(height: 20),
                if (_done) _buildDone() else _buildForm(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final intro = 'Enter the code we sent to $_email, then choose a new password.';
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
          child: Icon(Icons.password_rounded, color: AppColors.primaryLight, size: 30),
        ),
        const SizedBox(height: 20),
        Text(
          'Set a New Password',
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(intro, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 28),
        AppTextField(
          ctrl: _codeCtrl,
          hint: 'Reset code',
          label: 'Reset code',
          icon: Icons.key_rounded,
        ),
        const SizedBox(height: 14),
        AppTextField(
          ctrl: _passCtrl,
          hint: 'New password',
          icon: Icons.lock_outline_rounded,
          obscure: !_showPassword,
          suffix: IconButton(
            icon: Icon(
              _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textMuted,
              size: 18,
            ),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        const SizedBox(height: 14),
        AppTextField(
          ctrl: _confirmCtrl,
          hint: 'Confirm new password',
          icon: Icons.lock_reset_rounded,
          obscure: !_showPassword,
        ),
        const SizedBox(height: 8),
        Text(
          'Use at least 4 characters.',
          style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11),
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
                Expanded(
                  child: Text(_errorMsg!, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        GradientButton(text: 'Reset Password', onTap: _submit, loading: _loading),
        const SizedBox(height: 22),
        Center(
          child: GestureDetector(
            onTap: _resend,
            child: Text(
              _resending ? 'Sending a new code...' : "Didn't get the email? Send a new code",
              style: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.4), width: 2),
            ),
            child: Icon(Icons.verified_user_rounded, color: AppColors.success, size: 46),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Password Changed',
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your password has been reset. Sign in with your new password.',
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        GradientButton(text: 'Back to Sign In', onTap: _backToSignIn),
      ],
    );
  }
}

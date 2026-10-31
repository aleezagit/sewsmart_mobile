import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/validators.dart';
import '../../../navigation/app_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  UserRole _role = UserRole.customer;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _specialtiesCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  int _step = 1; // 1 = registration form, 2 = OTP (customers only)
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _errorMsg;
  String? _successMsg;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _experienceCtrl.dispose();
    _specialtiesCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = 'Please fill in all required fields');
      return;
    }
    if (!Validators.isEmail(email)) {
      setState(() => _errorMsg = 'Please enter a valid email address');
      return;
    }
    if (!Validators.isMobile(phone)) {
      setState(() => _errorMsg = 'Please enter a valid mobile number, e.g. 03001234567');
      return;
    }
    final experience = _experienceCtrl.text.trim();
    if (_role == UserRole.tailor && experience.isNotEmpty && int.tryParse(experience) == null) {
      setState(() => _errorMsg = 'Years of experience must be a whole number, e.g. 5');
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMsg = 'Passwords do not match');
      return;
    }
    if (pass.length < 4) {
      setState(() => _errorMsg = 'Password must be at least 4 characters');
      return;
    }

    setState(() { _loading = true; _errorMsg = null; });

    if (_role == UserRole.customer) {
      try {
        await AuthService().sendOtp(phone);
        if (mounted) setState(() { _loading = false; _step = 2; _successMsg = 'OTP sent to $phone'; });
      } on ApiException catch (e) {
        if (mounted) setState(() { _loading = false; _errorMsg = e.message; });
      }
    } else {
      await _completeRegistration();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) {
      setState(() => _errorMsg = 'Please enter OTP');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await AuthService().verifyOtp(_phoneCtrl.text.trim(), otp);
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = e.message; });
      return;
    }
    if (mounted) await _completeRegistration();
  }

  Future<void> _completeRegistration() async {
    final result = await AuthService().register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      role: _role,
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      experienceYears: _role == UserRole.tailor ? int.tryParse(_experienceCtrl.text.trim()) : null,
      specialties: _role == UserRole.tailor && _specialtiesCtrl.text.trim().isNotEmpty
          ? _specialtiesCtrl.text.trim()
          : null,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success && result.user != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => homeFor(result.user!.role)),
        (route) => false,
      );
    } else {
      setState(() => _errorMsg = result.error ?? 'Registration failed');
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
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
                      onPressed: () {
                        if (_step == 2) {
                          setState(() { _step = 1; _errorMsg = null; });
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _step == 2 ? 'Verify Phone' : 'Create Account',
                      style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _step == 2 ? 'Enter the OTP sent to your phone' : 'Fill in your details to get started',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
                if (_step == 1) _buildRegistrationForm(),
                if (_step == 2) _buildOtpStep(),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 14),
                  _buildErrorBanner(_errorMsg!),
                ],
                if (_successMsg != null && _step == 2) ...[
                  const SizedBox(height: 14),
                  _buildSuccessBanner(_successMsg!),
                ],
                const SizedBox(height: 24),
                GradientButton(
                  text: _step == 2 ? 'Verify & Register' : (_role == UserRole.customer ? 'Send OTP' : 'Create Account'),
                  onTap: _step == 2 ? _verifyOtp : _register,
                  loading: _loading,
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(fontSize: 13),
                        children: [
                          TextSpan(text: 'Already have an account? ', style: TextStyle(color: AppColors.textSecondary)),
                          TextSpan(text: 'Sign In', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('I am a', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Row(
          children: [
            RoleChip(label: 'Customer', icon: Icons.person_rounded, selected: _role == UserRole.customer, onTap: () => setState(() => _role = UserRole.customer), color: AppColors.customerColor),
            const SizedBox(width: 10),
            RoleChip(label: 'Tailor', icon: Icons.cut_rounded, selected: _role == UserRole.tailor, onTap: () => setState(() => _role = UserRole.tailor), color: AppColors.tailorColor),
          ],
        ),
        const SizedBox(height: 22),
        AppTextField(ctrl: _nameCtrl, hint: 'Full Name', icon: Icons.person_outline),
        const SizedBox(height: 14),
        AppTextField(ctrl: _emailCtrl, hint: 'Email address', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
        const SizedBox(height: 14),
        AppTextField(ctrl: _phoneCtrl, hint: 'Phone number (e.g. 03001234567)', icon: Icons.phone_outlined, keyboard: TextInputType.phone),
        const SizedBox(height: 14),
        AppTextField(ctrl: _cityCtrl, hint: 'City (optional)', icon: Icons.location_city_outlined),
        if (_role == UserRole.tailor) ...[
          const SizedBox(height: 14),
          AppTextField(ctrl: _experienceCtrl, hint: 'Years of experience (e.g. 5)', icon: Icons.workspace_premium_outlined, keyboard: TextInputType.number),
          const SizedBox(height: 14),
          AppTextField(ctrl: _specialtiesCtrl, hint: 'Specialties (e.g. Bridal, Formal)', icon: Icons.star_outline_rounded),
        ],
        const SizedBox(height: 14),
        AppTextField(
          ctrl: _passCtrl,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePass,
          suffix: IconButton(
            icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 18),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
        ),
        const SizedBox(height: 14),
        AppTextField(
          ctrl: _confirmPassCtrl,
          hint: 'Confirm Password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscureConfirm,
          suffix: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 18),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.sms_outlined, color: AppColors.primaryLight, size: 36),
        ),
        const SizedBox(height: 20),
        Text(
          'We sent a 4-digit OTP to',
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          _phoneCtrl.text.trim(),
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        AppTextField(
          ctrl: _otpCtrl,
          hint: 'Enter 4-digit OTP',
          icon: Icons.pin_outlined,
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            setState(() { _loading = true; _errorMsg = null; });
            try {
              await AuthService().sendOtp(_phoneCtrl.text.trim());
              if (mounted) setState(() { _loading = false; _successMsg = 'OTP resent!'; });
            } on ApiException catch (e) {
              if (mounted) setState(() { _loading = false; _errorMsg = e.message; });
            }
          },
          child: Text(
            'Resend OTP',
            style: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String msg) => Container(
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
        Expanded(child: Text(msg, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12))),
      ],
    ),
  );

  Widget _buildSuccessBanner(String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.poppins(color: AppColors.success, fontSize: 12))),
      ],
    ),
  );
}

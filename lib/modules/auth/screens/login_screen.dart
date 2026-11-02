import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/validators.dart';
import '../../../navigation/app_router.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.customer;
  bool _loading = false;
  bool _obscurePass = true;
  String? _errorMsg;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  void _onRoleChanged(UserRole role) {
    setState(() {
      _selectedRole = role;
      _errorMsg = null;
    });
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = 'Please enter your email and password');
      return;
    }
    if (!Validators.isEmail(email)) {
      setState(() => _errorMsg = 'Please enter a valid email address');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    final result = await AuthService().login(email, pass);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success && result.user != null && result.user!.role != _selectedRole) {
      // The chips choose the app to open, so they must match the account.
      await AuthService().logout();
      final role = result.user!.role.name;
      final label = role[0].toUpperCase() + role.substring(1);
      if (mounted) {
        setState(() => _errorMsg = 'This is a $role account. Select $label above to sign in.');
      }
      return;
    }
    if (result.success && result.user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => homeFor(result.user!.role)),
      );
    } else {
      setState(() => _errorMsg = result.error ?? 'Login failed');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Light or dark theme, before signing in too.
                  const Align(alignment: Alignment.centerRight, child: ThemeToggleButton()),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20)],
                      ),
                      child: const Icon(Icons.cut_rounded, color: Colors.white, size: 34),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Welcome Back',
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Sign in to your account',
                      style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'I am a',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      RoleChip(
                        label: 'Customer',
                        icon: Icons.person_rounded,
                        selected: _selectedRole == UserRole.customer,
                        onTap: () => _onRoleChanged(UserRole.customer),
                        color: AppColors.customerColor,
                      ),
                      const SizedBox(width: 10),
                      RoleChip(
                        label: 'Tailor',
                        icon: Icons.cut_rounded,
                        selected: _selectedRole == UserRole.tailor,
                        onTap: () => _onRoleChanged(UserRole.tailor),
                        color: AppColors.tailorColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    ctrl: _emailCtrl,
                    hint: 'Email address',
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    ctrl: _passCtrl,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscurePass,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 12),
                      ),
                    ),
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
                  GradientButton(
                    text: 'Sign In',
                    onTap: _login,
                    loading: _loading,
                    colors: _roleGradient(),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(fontSize: 13),
                          children: [
                            TextSpan(text: "Don't have an account? ", style: TextStyle(color: AppColors.textSecondary)),
                            TextSpan(
                              text: 'Register',
                              style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton.icon(
                      onPressed: _changeServer,
                      icon: Icon(Icons.dns_rounded, size: 15, color: AppColors.textMuted),
                      label: Text(
                        'Server: ${Uri.parse(ApiClient().baseUrl).authority}',
                        style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Lets the user point the app at their own backend, such as a laptop on the
  // same Wi-Fi. The address is checked before it is kept.
  Future<void> _changeServer() async {
    final ctrl = TextEditingController(text: ApiClient().baseUrl);
    String? error;
    bool checking = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Server address',
              style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where the SewSmart server runs, for example http://192.168.1.5:4000',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              AppTextField(hint: 'http://192.168.1.5:4000', icon: Icons.dns_rounded, ctrl: ctrl, keyboard: TextInputType.url),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await ApiClient().resetServer();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Reset', style: GoogleFonts.poppins(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: checking
                  ? null
                  : () async {
                      setDialogState(() { checking = true; error = null; });
                      try {
                        await ApiClient().useServer(ctrl.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } on ApiException catch (e) {
                        setDialogState(() { checking = false; error = e.message; });
                      }
                    },
              child: Text(checking ? 'Checking...' : 'Save',
                  style: GoogleFonts.poppins(color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (mounted) setState(() {});
  }

  List<Color> _roleGradient() {
    switch (_selectedRole) {
      case UserRole.customer:
        return [AppColors.primary, AppColors.primaryLight];
      case UserRole.tailor:
        return [AppColors.teal, AppColors.tealLight];
    }
  }
}

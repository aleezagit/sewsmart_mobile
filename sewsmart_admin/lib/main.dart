import 'package:flutter/material.dart';
import 'core/api/admin_api.dart';
import 'core/services/admin_service.dart';
import 'core/theme/admin_theme.dart';
import 'modules/auth/admin_login_screen.dart';
import 'navigation/admin_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A page reload keeps the admin signed in until the session times out.
  final signedIn = await AdminService().restoreSession();
  AdminApi.onSessionExpired = () => AdminApi.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (route) => false,
      );
  runApp(SewSmartAdminApp(signedIn: signedIn));
}

class SewSmartAdminApp extends StatelessWidget {
  final bool signedIn;
  const SewSmartAdminApp({super.key, this.signedIn = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SewSmart Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.light,
      navigatorKey: AdminApi.navigatorKey,
      scaffoldMessengerKey: AdminApi.messengerKey,
      home: signedIn ? const AdminShell() : const AdminLoginScreen(),
    );
  }
}

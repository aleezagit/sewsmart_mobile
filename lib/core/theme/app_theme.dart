import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Palettes ──────────────────────────────────────────────────────────────────
// The dark look, the app's original theme. The live stream screens always use
// it, like a video player, so they read these colours directly.
class DarkColors {
  DarkColors._();
  // Background
  static const bg       = Color(0xFF0A0812);
  static const surface  = Color(0xFF120F22);
  static const card     = Color(0xFF1C1535);
  static const cardAlt  = Color(0xFF241D42);
  static const divider  = Color(0xFF2D2550);
  // Brand
  static const primary      = Color(0xFF7C3AED);
  static const primaryLight = Color(0xFF9D5CF6);
  static const teal         = Color(0xFF0D9488);
  static const tealLight    = Color(0xFF14B8A6);
  static const secondary    = Color(0xFFBE185D);
  static const gold         = Color(0xFFEAB308);
  // Role colours, and an orange accent
  static const customerColor = Color(0xFF7C3AED);
  static const tailorColor   = Color(0xFF0D9488);
  static const orange        = Color(0xFFEA580C);
  // Status
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error   = Color(0xFFEF4444);
  static const info    = Color(0xFF3B82F6);
  // Text
  static const textPrimary   = Color(0xFFF8F7FF);
  static const textSecondary = Color(0xFFB0A8CC);
  static const textMuted     = Color(0xFF6B6088);
  // Orbs
  static const purpleOrb = Color(0x886B21A8);
  static const pinkOrb   = Color(0x88831843);
  static const tealOrb   = Color(0x880F766E);
  static const orangeOrb = Color(0x88923408);
  // The background gradient behind the orbs
  static const background = [Color(0xFF0A0812), Color(0xFF120A22), Color(0xFF0A1220)];
}

// The light look. Brand and status colours are a shade darker than in the
// dark look, so text in those colours stays readable on white.
class LightColors {
  LightColors._();
  // Background
  static const bg       = Color(0xFFF5F3FA);
  static const surface  = Color(0xFFFFFFFF);
  static const card     = Color(0xFFFFFFFF);
  static const cardAlt  = Color(0xFFF0ECF8);
  static const divider  = Color(0xFFE3DDEF);
  // Brand
  static const primary      = Color(0xFF7C3AED);
  static const primaryLight = Color(0xFF8B5CF6);
  static const teal         = Color(0xFF0F766E);
  static const tealLight    = Color(0xFF0D9488);
  static const secondary    = Color(0xFFBE185D);
  static const gold         = Color(0xFFC27803);
  // Role colours, and an orange accent
  static const customerColor = Color(0xFF7C3AED);
  static const tailorColor   = Color(0xFF0F766E);
  static const orange        = Color(0xFFEA580C);
  // Status
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const error   = Color(0xFFDC2626);
  static const info    = Color(0xFF2563EB);
  // Text
  static const textPrimary   = Color(0xFF1B1530);
  static const textSecondary = Color(0xFF5A5370);
  static const textMuted     = Color(0xFF857E9B);
  // Orbs
  static const purpleOrb = Color(0x55C4B5FD);
  static const pinkOrb   = Color(0x45F9A8D4);
  static const tealOrb   = Color(0x4599F6E4);
  static const orangeOrb = Color(0x45FED7AA);
  // The background gradient behind the orbs
  static const background = [Color(0xFFFBFAFF), Color(0xFFF4F0FD), Color(0xFFEEF3FB)];
}

// The colours of the theme in use. Screens read them while they build, so a
// theme change shows once every widget is built again, which
// ThemeController.setLight takes care of.
class AppColors {
  AppColors._();

  // The app opens in the light theme. ThemeController.load switches to the
  // saved choice before the first screen shows.
  static bool _light = true;

  // True while the light theme is on.
  static bool get isLight => _light;

  // Background
  static Color get bg      => _light ? LightColors.bg : DarkColors.bg;
  static Color get surface => _light ? LightColors.surface : DarkColors.surface;
  static Color get card    => _light ? LightColors.card : DarkColors.card;
  static Color get cardAlt => _light ? LightColors.cardAlt : DarkColors.cardAlt;
  static Color get divider => _light ? LightColors.divider : DarkColors.divider;
  // Brand
  static Color get primary      => _light ? LightColors.primary : DarkColors.primary;
  static Color get primaryLight => _light ? LightColors.primaryLight : DarkColors.primaryLight;
  static Color get teal         => _light ? LightColors.teal : DarkColors.teal;
  static Color get tealLight    => _light ? LightColors.tealLight : DarkColors.tealLight;
  static Color get secondary    => _light ? LightColors.secondary : DarkColors.secondary;
  static Color get gold         => _light ? LightColors.gold : DarkColors.gold;
  // Role colours, and an orange accent
  static Color get customerColor => _light ? LightColors.customerColor : DarkColors.customerColor;
  static Color get tailorColor   => _light ? LightColors.tailorColor : DarkColors.tailorColor;
  static Color get orange    => _light ? LightColors.orange : DarkColors.orange;
  // Status
  static Color get success => _light ? LightColors.success : DarkColors.success;
  static Color get warning => _light ? LightColors.warning : DarkColors.warning;
  static Color get error   => _light ? LightColors.error : DarkColors.error;
  static Color get info    => _light ? LightColors.info : DarkColors.info;
  // Text
  static Color get textPrimary   => _light ? LightColors.textPrimary : DarkColors.textPrimary;
  static Color get textSecondary => _light ? LightColors.textSecondary : DarkColors.textSecondary;
  static Color get textMuted     => _light ? LightColors.textMuted : DarkColors.textMuted;
  // Orbs
  static Color get purpleOrb => _light ? LightColors.purpleOrb : DarkColors.purpleOrb;
  static Color get pinkOrb   => _light ? LightColors.pinkOrb : DarkColors.pinkOrb;
  static Color get tealOrb   => _light ? LightColors.tealOrb : DarkColors.tealOrb;
  static Color get orangeOrb => _light ? LightColors.orangeOrb : DarkColors.orangeOrb;
  // The background gradient behind the orbs
  static List<Color> get background => _light ? LightColors.background : DarkColors.background;
}

class AppTheme {
  AppTheme._();

  // Built once each. They read only DarkColors and LightColors.
  static final ThemeData dark = _build(light: false);
  static final ThemeData light = _build(light: true);

  // Status bar and navigation bar icons that suit the background: light icons
  // on the dark theme, dark icons on the light theme.
  static const SystemUiOverlayStyle darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: DarkColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  );
  static const SystemUiOverlayStyle lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: LightColors.bg,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static SystemUiOverlayStyle get overlayStyle => AppColors.isLight ? lightOverlay : darkOverlay;

  static ThemeData _build({required bool light}) {
    Color pick(Color dark, Color lightColor) => light ? lightColor : dark;
    final bg = pick(DarkColors.bg, LightColors.bg);
    final surface = pick(DarkColors.surface, LightColors.surface);
    final card = pick(DarkColors.card, LightColors.card);
    final divider = pick(DarkColors.divider, LightColors.divider);
    final primary = pick(DarkColors.primary, LightColors.primary);
    final primaryLight = pick(DarkColors.primaryLight, LightColors.primaryLight);
    final teal = pick(DarkColors.teal, LightColors.teal);
    final error = pick(DarkColors.error, LightColors.error);
    final textPrimary = pick(DarkColors.textPrimary, LightColors.textPrimary);
    final textSecondary = pick(DarkColors.textSecondary, LightColors.textSecondary);
    final textMuted = pick(DarkColors.textMuted, LightColors.textMuted);
    final base = light ? ThemeData.light() : ThemeData.dark();

    return ThemeData(
      brightness: light ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: light
          ? ColorScheme.light(primary: primary, secondary: teal, surface: surface, error: error, onSurface: textPrimary)
          : ColorScheme.dark(primary: primary, secondary: teal, surface: surface, error: error),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 26),
        headlineMedium: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 17),
        titleMedium: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 15),
        bodyLarge: GoogleFonts.poppins(color: textPrimary, fontSize: 14),
        bodyMedium: GoogleFonts.poppins(color: textSecondary, fontSize: 13),
        bodySmall: GoogleFonts.poppins(color: textMuted, fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0,
        titleTextStyle: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
        iconTheme: IconThemeData(color: textPrimary),
        // The app bars are transparent, so the icons follow the theme rather
        // than the bar colour.
        systemOverlayStyle: light ? lightOverlay : darkOverlay,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.5)),
        hintStyle: GoogleFonts.poppins(color: textMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: primary, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
      )),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface, selectedItemColor: primaryLight,
        unselectedItemColor: textMuted, type: BottomNavigationBarType.fixed, elevation: 0,
      ),
    );
  }
}

// Shows its child in the dark theme while the light theme is on too. The live
// stream screens use it, like a video player: their text fields, switches,
// dialogs and status bar stay dark.
class AlwaysDark extends StatelessWidget {
  final Widget child;
  const AlwaysDark({super.key, required this.child});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.darkOverlay,
        child: Theme(data: AppTheme.dark, child: child),
      );
}

// ── Theme switch ──────────────────────────────────────────────────────────────
// Keeps the light or dark choice and saves it on the device, so the app opens
// with the theme the user picked last time. Until the user picks one, the app
// uses the light theme.
class ThemeController {
  ThemeController._();

  static const _prefsKey = 'light_theme';

  // True while the light theme is on. MaterialApp listens to it.
  static final ValueNotifier<bool> light = ValueNotifier<bool>(true);

  // Reads the saved choice. Called once, before the app starts.
  static Future<void> load() async {
    var saved = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      // Storage is not available. Start with the light theme.
    }
    _apply(saved);
  }

  static void toggle() => setLight(!light.value);

  static Future<void> setLight(bool value) async {
    if (value == light.value) return;
    _apply(value);
    _rebuildAll();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // The choice still applies until the app is closed.
    }
  }

  static void _apply(bool value) {
    AppColors._light = value;
    light.value = value;
    SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);
  }

  // Screens read AppColors while they build, and most widgets do not build
  // again on their own, so every widget on screen is marked to build again.
  // State such as the open screens and typed text is kept.
  static void _rebuildAll() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return;
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }
    root.visitChildren(mark);
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ── Aurora Background ─────────────────────────────────────────────────────────
class AuroraBackground extends StatelessWidget {
  final Widget child;
  final Color? orb1, orb2, orb3;
  // Keeps the dark look in the light theme too. The live stream screens use it.
  final bool alwaysDark;
  const AuroraBackground({super.key, required this.child, this.orb1, this.orb2, this.orb3, this.alwaysDark = false});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final light = AppColors.isLight && !alwaysDark;
    final defaultOrb = light ? LightColors.purpleOrb : DarkColors.purpleOrb;
    final background = Container(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: light ? LightColors.background : DarkColors.background,
      )),
      child: Stack(children: [
        Positioned(top: -80, left: -60, child: _Orb(color: orb1 ?? defaultOrb, size: 280, light: light)),
        Positioned(top: 200, left: 60, child: _Orb(color: orb2 ?? (light ? LightColors.pinkOrb : DarkColors.pinkOrb), size: 220, light: light)),
        Positioned(top: 80, right: -40, child: _Orb(color: orb3 ?? (light ? LightColors.tealOrb : DarkColors.tealOrb), size: 200, light: light)),
        Positioned(bottom: 100, right: 20, child: _Orb(color: defaultOrb, size: 160, light: light)),
        child,
      ]),
    );
    // Fill all the space the page gives, so the gradient reaches the bottom of
    // the screen when the content is shorter than the screen.
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) return background;
    return SizedBox(width: constraints.maxWidth, height: constraints.maxHeight, child: background);
  });
}

class _Orb extends StatelessWidget {
  final Color color; final double size;
  // On a light background the orb fades into its own colour, because fading
  // into transparent black leaves a grey ring.
  final bool light;
  const _Orb({required this.color, required this.size, this.light = false});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, light ? color.withValues(alpha: 0) : Colors.transparent])),
  );
}

// ── Gradient Button ───────────────────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool loading;
  final List<Color>? colors;
  final double? width;
  const GradientButton({super.key, required this.text, required this.onTap, this.loading = false, this.colors, this.width});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      width: width ?? double.infinity, height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors ?? [AppColors.primary, AppColors.primaryLight]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: (colors?.first ?? AppColors.primary).withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Center(child: loading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(text, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
    ),
  );
}

// ── App Text Field ────────────────────────────────────────────────────────────
class AppTextField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final bool obscure;
  final TextEditingController? ctrl;
  final TextInputType? keyboard;
  final Widget? suffix;
  final String? label;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  const AppTextField({super.key, required this.hint, this.icon, this.obscure = false, this.ctrl, this.keyboard, this.suffix, this.label, this.maxLines = 1, this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, obscureText: obscure, keyboardType: keyboard,
    maxLines: maxLines, onChanged: onChanged,
    style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint, labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted, size: 18) : null,
      suffixIcon: suffix,
    ),
  );
}

// ── Glass Card ────────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? borderColor;
  const GlassCard({super.key, required this.child, this.padding, this.onTap, this.radius = 14, this.borderColor});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.divider),
      ),
      child: child,
    ),
  );
}

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title; final String? action; final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
      if (action != null) GestureDetector(onTap: onAction, child: Text(action!, style: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 12))),
    ],
  );
}

// ── Status Badge ──────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label; final Color color;
  const StatusBadge({super.key, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Text(label, style: GoogleFonts.poppins(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

// ── Star Rating ───────────────────────────────────────────────────────────────
class StarRating extends StatelessWidget {
  final double rating; final double size;
  const StarRating({super.key, required this.rating, this.size = 13});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.star_rounded, color: AppColors.gold, size: size + 2),
    const SizedBox(width: 2),
    Text(rating.toStringAsFixed(1), style: GoogleFonts.poppins(color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: size)),
  ]);
}

// ── Metric Card ───────────────────────────────────────────────────────────────
class MetricCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color; final String? change;
  const MetricCard({super.key, required this.label, required this.value, required this.icon, required this.color, this.change});
  @override
  Widget build(BuildContext context) => GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16)),
      const Spacer(),
      if (change != null) Text(change!, style: GoogleFonts.poppins(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
    const SizedBox(height: 8),
    // The grid fixes the card height. On a small screen or with large system
    // text the value and label shrink instead of overflowing the card.
    Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 10)),
        ]),
      ),
    ),
  ]));
}

// ── Back App Bar ──────────────────────────────────────────────────────────────
class SewAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title; final String? subtitle; final List<Widget>? actions;
  const SewAppBar({super.key, required this.title, this.subtitle, this.actions});
  @override
  Size get preferredSize => const Size.fromHeight(60);
  @override
  Widget build(BuildContext context) => AppBar(
    leading: Navigator.canPop(context)
        ? IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, size: 18))
        : null,
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 17)),
      if (subtitle != null) Text(subtitle!, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11)),
    ]),
    actions: actions,
    backgroundColor: Colors.transparent,
    elevation: 0,
  );
}

// ── Role Chip ─────────────────────────────────────────────────────────────────
class RoleChip extends StatelessWidget {
  final String label; final IconData icon; final bool selected; final VoidCallback onTap; final Color color;
  const RoleChip({super.key, required this.label, required this.icon, required this.selected, required this.onTap, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.18) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? color : AppColors.divider, width: selected ? 1.5 : 1),
      ),
      child: Column(children: [
        Icon(icon, color: selected ? color : AppColors.textMuted, size: 24),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.poppins(color: selected ? color : AppColors.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, fontSize: 12)),
      ]),
    ),
  ));
}

// ── Choice Pill ───────────────────────────────────────────────────────────────
// A tappable pill for picking one of a few options, such as a reason or a label.
class ChoicePill extends StatelessWidget {
  // color defaults to AppColors.primaryLight of the theme in use.
  final String label; final bool selected; final VoidCallback onTap; final Color? color;
  const ChoicePill({super.key, required this.label, required this.selected, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primaryLight;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : AppColors.divider),
        ),
        child: Text(label, style: GoogleFonts.poppins(
          color: selected ? accent : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        )),
      ),
    );
  }
}

// ── Theme Toggle ──────────────────────────────────────────────────────────────
// A round button that switches the whole app between the light and the dark
// theme. The profile screens have the same choice as a Dark Mode switch.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});
  @override
  Widget build(BuildContext context) {
    final light = AppColors.isLight;
    return Tooltip(
      message: light ? 'Dark theme' : 'Light theme',
      child: GestureDetector(
        onTap: ThemeController.toggle,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(
            light ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: light ? AppColors.primary : AppColors.gold,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ── Coming Soon ───────────────────────────────────────────────────────────────
// For buttons whose feature is not built yet, so a tap always gives feedback.
void showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('$feature will be available soon', style: GoogleFonts.poppins()),
      backgroundColor: AppColors.info,
      duration: const Duration(seconds: 2),
    ));
}

// ── Empty State ───────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon; final String title; final String? subtitle;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: AppColors.textMuted, size: 60),
    const SizedBox(height: 12),
    Text(title, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
    if (subtitle != null) Text(subtitle!, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
  ]));
}

// ── Messages ──────────────────────────────────────────────────────────────────
// A short message at the bottom of the screen. Pass the error caught from a
// service call as [error]: an ApiException's text is written for the user.
void showMessage(BuildContext context, String message, {bool success = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.poppins()),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
}

void showError(BuildContext context, Object error) =>
    showMessage(context, '$error', success: false);

// ── Load Error ────────────────────────────────────────────────────────────────
// Shown in place of a list or page that could not be loaded.
class LoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const LoadError({super.key, required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 52),
      const SizedBox(height: 12),
      Text('$error', textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: onRetry,
        icon: Icon(Icons.refresh_rounded, color: AppColors.primaryLight),
        label: Text('Try again', style: GoogleFonts.poppins(color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
      ),
    ]),
  ));
}

// A picture from the web, with a spinner while it loads. [fallback] shows when
// there is no address or the picture cannot be loaded. AI pictures can take a
// few seconds to be drawn.
class NetworkPicture extends StatelessWidget {
  final String? url;
  final Widget fallback;
  const NetworkPicture({super.key, required this.url, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final address = url;
    if (address == null || address.isEmpty) return fallback;
    return Image.network(
      address,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Stack(fit: StackFit.expand, children: [
              fallback,
              Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2))),
            ]),
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

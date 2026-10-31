import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/admin_theme.dart';

// ─────────────────────────────────────────────────────────────
// AdminCard
// ─────────────────────────────────────────────────────────────
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const AdminCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
        boxShadow: const [
          BoxShadow(
            color: AdminColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: borderRadius ?? BorderRadius.circular(12),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(20),
                child: child,
              ),
            )
          : Padding(
              padding: padding ?? const EdgeInsets.all(20),
              child: child,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// StatCard
// ─────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? changeText;
  final bool? isPositiveChange;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.changeText,
    this.isPositiveChange,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              if (changeText != null)
                _ChangeBadge(
                  text: changeText!,
                  isPositive: isPositiveChange ?? true,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AdminColors.text,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AdminColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  final String text;
  final bool isPositive;

  const _ChangeBadge({required this.text, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AdminColors.success : AdminColors.error;
    final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AdminButton
// ─────────────────────────────────────────────────────────────
class AdminButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isLoading;
  final bool isSmall;

  const AdminButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.isLoading = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AdminColors.primary;
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: isSmall
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.poppins(
          fontSize: isSmall ? 12 : 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: isSmall ? 14 : 16),
                  const SizedBox(width: 6),
                ],
                Text(label),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// OutlineAdminButton
// ─────────────────────────────────────────────────────────────
class OutlineAdminButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isSmall;

  const OutlineAdminButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AdminColors.primary;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: c),
        padding: isSmall
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.poppins(
          fontSize: isSmall ? 12 : 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isSmall ? 14 : 16),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AdminBadge
// ─────────────────────────────────────────────────────────────
class AdminBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final AdminBadgeStyle style;

  const AdminBadge({
    super.key,
    required this.label,
    this.color,
    this.style = AdminBadgeStyle.filled,
  });

  factory AdminBadge.success(String label) =>
      AdminBadge(label: label, color: AdminColors.success);

  factory AdminBadge.error(String label) =>
      AdminBadge(label: label, color: AdminColors.error);

  factory AdminBadge.warning(String label) =>
      AdminBadge(label: label, color: AdminColors.warning);

  factory AdminBadge.info(String label) =>
      AdminBadge(label: label, color: AdminColors.info);

  factory AdminBadge.neutral(String label) =>
      AdminBadge(label: label, color: AdminColors.textSecondary);

  @override
  Widget build(BuildContext context) {
    final c = color ?? AdminColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style == AdminBadgeStyle.filled ? c.withOpacity(0.12) : Colors.transparent,
        border: style == AdminBadgeStyle.outline ? Border.all(color: c) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }
}

enum AdminBadgeStyle { filled, outline }

// ─────────────────────────────────────────────────────────────
// AdminRow — DataTable-style row
// ─────────────────────────────────────────────────────────────
class AdminRow extends StatelessWidget {
  final List<Widget> cells;
  final List<double> flexValues;
  final VoidCallback? onTap;

  const AdminRow({
    super.key,
    required this.cells,
    required this.flexValues,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AdminColors.bg,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: List.generate(cells.length, (i) {
              final flex = i < flexValues.length ? flexValues[i].toInt() : 1;
              return Expanded(flex: flex, child: cells[i]);
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SidebarItem
// ─────────────────────────────────────────────────────────────
class SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;
  final int? badgeCount;

  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isCollapsed = false,
    this.badgeCount,
  });

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 10 : 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: active
                ? AdminColors.sidebarActive
                : _hovering
                    ? AdminColors.sidebarHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.isCollapsed
              ? Center(
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: active ? Colors.white : AdminColors.sidebarText,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 18,
                      color: active ? Colors.white : AdminColors.sidebarText,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? Colors.white : AdminColors.sidebarText,
                        ),
                      ),
                    ),
                    if (widget.badgeCount != null && widget.badgeCount! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.badgeCount}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AdminTextField
// ─────────────────────────────────────────────────────────────
class AdminTextField extends StatelessWidget {
  final String? hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? label;
  final int? maxLines;
  final bool enabled;

  const AdminTextField({
    super.key,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.onChanged,
    this.obscureText = false,
    this.keyboardType,
    this.label,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AdminColors.text,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          onChanged: onChanged,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: enabled,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AdminColors.text,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: AdminColors.textSecondary)
                : null,
            suffixIcon: suffixIcon != null
                ? GestureDetector(
                    onTap: onSuffixTap,
                    child: Icon(suffixIcon,
                        size: 18, color: AdminColors.textSecondary),
                  )
                : null,
            filled: true,
            fillColor: enabled ? Colors.white : AdminColors.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AdminColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AdminColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AdminColors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            hintStyle: GoogleFonts.poppins(
              fontSize: 13,
              color: AdminColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PageHeader
// ─────────────────────────────────────────────────────────────
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget? badge;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.text,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 10),
                    badge!,
                  ],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TableHeader — column header row
// ─────────────────────────────────────────────────────────────
class TableHeader extends StatelessWidget {
  final List<String> columns;
  final List<double> flexValues;

  const TableHeader({
    super.key,
    required this.columns,
    required this.flexValues,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: List.generate(columns.length, (i) {
          final flex = i < flexValues.length ? flexValues[i].toInt() : 1;
          return Expanded(
            flex: flex,
            child: Text(
              columns[i],
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AdminColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AvatarWidget
// ─────────────────────────────────────────────────────────────
class AdminAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const AdminAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.color,
  });

  static Color _colorFromName(String name) {
    final colors = [
      AdminColors.primary,
      AdminColors.customerColor,
      AdminColors.tailorColor,
      AdminColors.orange,
      AdminColors.info,
      AdminColors.warning,
    ];
    final index = name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ?? _colorFromName(name);
    final initials = name.trim().split(' ').take(2).map((s) => s.isEmpty ? '' : s[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg.withOpacity(0.15),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
            color: bg,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SectionTitle
// ─────────────────────────────────────────────────────────────
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionTitle({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AdminColors.text,
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// StatusBadge convenience
// ─────────────────────────────────────────────────────────────
AdminBadge statusBadge(String status) {
  switch (status.toLowerCase()) {
    case 'active':
    case 'approved':
    case 'completed':
    case 'delivered':
    case 'paid':
      return AdminBadge.success(status);
    case 'suspended':
    case 'rejected':
    case 'cancelled':
    case 'refunded':
      return AdminBadge.error(status);
    case 'pending':
    case 'open':
      return AdminBadge.warning(status);
    case 'in progress':
    case 'in_progress':
    case 'verified':
    case 'processing':
      return AdminBadge.info(status);
    default:
      return AdminBadge.neutral(status);
  }
}

// ─────────────────────────────────────────────────────────────
// EmptyState
// ─────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subMessage;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AdminColors.border),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AdminColors.textSecondary,
              ),
            ),
            if (subMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                subMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AdminColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

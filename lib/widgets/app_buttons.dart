import 'package:buddy/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class AppPressable extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final BoxDecoration? decoration;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final String? semanticsLabel;
  final bool selected;
  final bool enabled;
  final bool excludeChildSemantics;
  final double minHeight;
  final double minWidth;
  final AlignmentGeometry alignment;

  const AppPressable({
    super.key,
    required this.onPressed,
    required this.child,
    this.decoration,
    this.borderRadius,
    this.padding,
    this.semanticsLabel,
    this.selected = false,
    this.enabled = true,
    this.excludeChildSemantics = false,
    this.minHeight = AppTheme.minimumTouchTarget,
    this.minWidth = AppTheme.minimumTouchTarget,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedEnabled = enabled && onPressed != null;
    final resolvedBorderRadius =
        borderRadius ??
        decoration?.borderRadius as BorderRadius? ??
        BorderRadius.circular(16);

    return Semantics(
      button: true,
      enabled: resolvedEnabled,
      selected: selected,
      label: semanticsLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight, minWidth: minWidth),
        child: Material(
          color: Colors.transparent,
          borderRadius: resolvedBorderRadius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: decoration,
            child: InkWell(
              onTap: resolvedEnabled ? onPressed : null,
              borderRadius: resolvedBorderRadius,
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: Align(
                  alignment: alignment,
                  child: excludeChildSemantics
                      ? ExcludeSemantics(child: child)
                      : child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? semanticsLabel;
  final bool isLoading;
  final double minHeight;
  final EdgeInsetsGeometry? padding;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.semanticsLabel,
    this.isLoading = false,
    this.minHeight = 56,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(minHeight),
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        child: Semantics(
          button: true,
          label: semanticsLabel ?? label,
          child: ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.actionForeground,
                        ),
                      ),
                    )
                  else ...[
                    Text(label),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, size: 18),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final double iconSize;
  final Color? color;

  const AppBackButton({
    super.key,
    required this.onPressed,
    this.icon = LucideIcons.chevron_left,
    this.iconSize = 22,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onPressed: onPressed,
      semanticsLabel: 'Go back',
      minHeight: AppTheme.minimumTouchTarget,
      minWidth: AppTheme.minimumTouchTarget,
      child: Icon(
        icon,
        color: color ?? AppTheme.textCream,
        size: iconSize,
      ),
    );
  }
}

class AppSurfaceIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  final double size;
  final double iconSize;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const AppSurfaceIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.label,
    this.size = AppTheme.minimumTouchTarget,
    this.iconSize = 18,
    this.foregroundColor,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBorderRadius = borderRadius ?? BorderRadius.circular(14);
    return Tooltip(
      message: label,
      child: AppPressable(
        onPressed: onPressed,
        semanticsLabel: label,
        minHeight: size,
        minWidth: size,
        borderRadius: resolvedBorderRadius,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppTheme.cardDark,
          borderRadius: resolvedBorderRadius,
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Icon(
          icon,
          color: foregroundColor ?? AppTheme.textCream,
          size: iconSize,
        ),
      ),
    );
  }
}

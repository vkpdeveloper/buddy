import 'package:buddy/app_theme.dart';
import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? borderColor;
  final List<Color>? colors;
  final bool withShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 14),
    this.margin,
    this.radius = 20,
    this.borderColor,
    this.colors,
    this.withShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: AppTheme.cardDecoration(
        radius: radius,
        borderColor: borderColor,
        colors: colors ?? AppTheme.cardGradient,
        withShadow: withShadow,
      ),
      child: child,
    );
  }
}

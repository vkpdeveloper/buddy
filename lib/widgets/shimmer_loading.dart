import 'package:flutter/material.dart';
import 'package:buddy/app_color_scheme.dart';
import 'package:buddy/utils/motion_preferences.dart';

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldAnimate = !prefersReducedMotion(context);
    if (shouldAnimate == _isAnimating) return;
    _isAnimating = shouldAnimate;
    if (shouldAnimate) {
      _controller.repeat();
      return;
    }
    _controller
      ..stop()
      ..value = 0.5;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final baseColor =
        widget.baseColor ?? (colors.isDark ? colors.card : colors.cardRaised);
    final highlightColor =
        widget.highlightColor ??
        (colors.isDark ? colors.cardRaised : colors.card);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final gradientCenter = _controller.value;
          final leadingStop = (gradientCenter - 0.18).clamp(0.0, 1.0);
          final trailingStop = (gradientCenter + 0.18).clamp(0.0, 1.0);
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [
                  0.0,
                  leadingStop.toDouble(),
                  gradientCenter,
                  trailingStop.toDouble(),
                  1.0,
                ],
                colors: [
                  baseColor,
                  baseColor,
                  highlightColor,
                  baseColor,
                  baseColor,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SkeletonCardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? borderColor;

  const SkeletonCardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 20,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: context.colors.cardDecoration(
        radius: radius,
        borderColor: borderColor,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

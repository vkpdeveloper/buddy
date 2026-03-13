import 'package:flutter/material.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/utils/motion_preferences.dart';

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.baseColor = AppTheme.cardDark,
    this.highlightColor = AppTheme.cardRaised,
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
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final gradientStop = _controller.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [gradientStop - 0.3, gradientStop, gradientStop + 0.3],
                colors: [
                  widget.baseColor,
                  widget.highlightColor,
                  widget.baseColor,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

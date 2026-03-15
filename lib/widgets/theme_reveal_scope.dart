import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ThemeRevealScope extends StatefulWidget {
  final Widget child;

  const ThemeRevealScope({super.key, required this.child});

  static ThemeRevealController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ThemeRevealInherited>()
        ?.controller;
  }

  @override
  State<ThemeRevealScope> createState() => _ThemeRevealScopeState();
}

class ThemeRevealController {
  final _ThemeRevealScopeState _state;

  const ThemeRevealController._(this._state);

  bool get isAnimating => _state._isAnimating;

  Future<void> revealTheme({
    required ThemeMode currentMode,
    required ThemeMode targetMode,
    required Offset globalOrigin,
    required Future<void> Function() applyThemeMode,
  }) {
    return _state._revealTheme(
      currentMode: currentMode,
      targetMode: targetMode,
      globalOrigin: globalOrigin,
      applyThemeMode: applyThemeMode,
    );
  }
}

class _ThemeRevealScopeState extends State<ThemeRevealScope>
    with SingleTickerProviderStateMixin {
  static const _revealDuration = Duration(milliseconds: 420);
  static const _maxCapturePixelRatio = 1.25;

  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _controller;
  late final Animation<double> _progress;
  late final ThemeRevealController _controllerHandle;

  ui.Image? _snapshot;
  Offset _origin = Offset.zero;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _revealDuration);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.16, 1, 0.3, 1),
    );
    _controllerHandle = ThemeRevealController._(this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _disposeSnapshot();
    super.dispose();
  }

  Future<void> _revealTheme({
    required ThemeMode currentMode,
    required ThemeMode targetMode,
    required Offset globalOrigin,
    required Future<void> Function() applyThemeMode,
  }) async {
    if (_isAnimating || currentMode == targetMode) return;

    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion =
        mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true;
    final platformBrightness =
        mediaQuery?.platformBrightness ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final currentBrightness = Theme.of(context).brightness;
    final targetBrightness = switch (targetMode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => platformBrightness,
    };

    if (reduceMotion || currentBrightness == targetBrightness) {
      await applyThemeMode();
      return;
    }

    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    final hostBox = context.findRenderObject() as RenderBox?;
    if (boundary == null || hostBox == null) {
      await applyThemeMode();
      return;
    }

    if (boundary.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    final pixelRatio = math.min(
      mediaQuery?.devicePixelRatio ??
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio,
      _maxCapturePixelRatio,
    );

    ui.Image snapshot;
    try {
      snapshot = await boundary.toImage(pixelRatio: pixelRatio);
    } catch (_) {
      await applyThemeMode();
      return;
    }

    if (!mounted) {
      snapshot.dispose();
      return;
    }

    setState(() {
      _disposeSnapshot();
      _snapshot = snapshot;
      _origin = hostBox.globalToLocal(globalOrigin);
      _isAnimating = true;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    final applyFuture = applyThemeMode();

    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _controller.forward(from: 0);
    } finally {
      if (mounted) {
        final activeSnapshot = _snapshot;
        setState(() {
          _isAnimating = false;
          _snapshot = null;
        });
        activeSnapshot?.dispose();
      }
      _controller.value = 0;
    }

    await applyFuture;
  }

  void _disposeSnapshot() {
    _snapshot?.dispose();
    _snapshot = null;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final rimColor = Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: 0.18);

    return _ThemeRevealInherited(
      controller: _controllerHandle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(key: _boundaryKey, child: widget.child),
          if (snapshot != null)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ThemeRevealPainter(
                      image: snapshot,
                      progress: _progress.value,
                      origin: _origin,
                      rimColor: rimColor,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeRevealInherited extends InheritedWidget {
  final ThemeRevealController controller;

  const _ThemeRevealInherited({required this.controller, required super.child});

  @override
  bool updateShouldNotify(_ThemeRevealInherited oldWidget) {
    return controller != oldWidget.controller;
  }
}

class _ThemeRevealPainter extends CustomPainter {
  final ui.Image image;
  final double progress;
  final Offset origin;
  final Color rimColor;

  const _ThemeRevealPainter({
    required this.image,
    required this.progress,
    required this.origin,
    required this.rimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clampedOrigin = Offset(
      origin.dx.clamp(0.0, size.width),
      origin.dy.clamp(0.0, size.height),
    );
    final radius = _maxRadius(size, clampedOrigin) * progress;
    final imageRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final canvasRect = Offset.zero & size;

    canvas.saveLayer(canvasRect, Paint());
    canvas.drawImageRect(image, imageRect, canvasRect, Paint());
    canvas.drawCircle(
      clampedOrigin,
      radius,
      Paint()
        ..blendMode = BlendMode.clear
        ..isAntiAlias = true,
    );

    final ringOpacity = (1 - (progress * 1.4)).clamp(0.0, 1.0);
    if (ringOpacity > 0) {
      canvas.drawCircle(
        clampedOrigin,
        radius,
        Paint()
          ..color = rimColor.withValues(alpha: ringOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ui.lerpDouble(18, 2, progress) ?? 2
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }

  double _maxRadius(Size size, Offset origin) {
    final distances = <double>[
      origin.distance,
      Offset(size.width - origin.dx, origin.dy).distance,
      Offset(origin.dx, size.height - origin.dy).distance,
      Offset(size.width - origin.dx, size.height - origin.dy).distance,
    ];
    return distances.reduce(math.max);
  }

  @override
  bool shouldRepaint(_ThemeRevealPainter oldDelegate) {
    return image != oldDelegate.image ||
        progress != oldDelegate.progress ||
        origin != oldDelegate.origin ||
        rimColor != oldDelegate.rimColor;
  }
}

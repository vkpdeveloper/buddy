import 'package:flutter/material.dart';

bool prefersReducedMotion(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  return (mediaQuery?.disableAnimations ?? false) ||
      (mediaQuery?.accessibleNavigation ?? false);
}

Duration motionDuration(BuildContext context, Duration duration) {
  return prefersReducedMotion(context) ? Duration.zero : duration;
}

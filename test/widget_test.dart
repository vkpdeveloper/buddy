import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buddy/app_theme.dart';
import 'package:buddy/pages/login_page.dart';

void main() {
  setUpAll(() {
    // Allows NetworkImage to silently fail in the test environment
    HttpOverrides.global = null;
  });

  testWidgets('Login page renders without crashing in dark theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const LoginPage()),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Buddy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login page keeps hero copy legible in light theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const LoginPage()),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text('Buddy'));
    expect(title.style?.color, AppTheme.textCream);

    final heroCopy = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan?.toPlainText().contains('Build meals, workouts') ==
                true,
      ),
    );
    expect(
      heroCopy.textSpan?.style?.color,
      AppTheme.textMain.withValues(alpha: 0.9),
    );

    final overlayRegion = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(overlayRegion.value.statusBarIconBrightness, Brightness.light);
    expect(tester.takeException(), isNull);
  });
}

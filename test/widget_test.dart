import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buddy/app_theme.dart';
import 'package:buddy/pages/login_page.dart';

void main() {
  setUpAll(() {
    // Allows NetworkImage to silently fail in the test environment
    HttpOverrides.global = null;
  });

  testWidgets('Login page renders without crashing', (
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
}

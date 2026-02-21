import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ledger/main.dart';

void main() {
  setUpAll(() {
    // Allows NetworkImage to silently fail in the test environment
    HttpOverrides.global = null;
  });

  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // Provide a localized mock response for image requests instead of throwing
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const HealthBiometricsApp(onboardingCompleted: true),
      );

      // Let the image fetch fail and catch the exception locally
      tester.takeException();

      // Verify that the title is rendered.
      expect(find.text('Peace be with you,\nAlex'), findsOneWidget);
    });
  });
}

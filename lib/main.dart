import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:buddy/config/env.dart';
import 'package:buddy/services/notification_service.dart';
import 'app_theme.dart';
import 'pages/splash_screen.dart';
import 'pages/login_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Load & validate environment ──────────────────────────────────────────
  await EnvLoader.load();

  // ── Initialize Firebase ──────────────────────────────────────────────────
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Pre-warm fonts to avoid flash of unstyled text on first render
  await GoogleFonts.pendingFonts([
    GoogleFonts.sora(),
    GoogleFonts.plusJakartaSans(),
  ]);

  await SoLoud.instance.init();
  await NotificationService.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppTheme.transparent,
      systemNavigationBarColor: AppTheme.transparent,
      systemNavigationBarDividerColor: AppTheme.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(ProviderScope(child: const HealthBiometricsApp()));
}

class HealthBiometricsApp extends StatelessWidget {
  const HealthBiometricsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buddy',
      theme: AppTheme.darkTheme,
      home: const _AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Listens to Firebase auth state and routes to [LoginPage] or [SplashScreen].
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.oledBlack,
            body: SizedBox.shrink(),
          );
        }
        final isSignedIn = snapshot.hasData && snapshot.data != null;
        return isSignedIn ? const SplashScreen() : const LoginPage();
      },
    );
  }
}

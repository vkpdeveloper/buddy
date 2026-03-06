import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clerk_flutter/clerk_flutter.dart' as clerk;
import 'package:buddy/config/env.dart';
import 'package:buddy/providers/clerk_auth_provider.dart';
import 'package:buddy/services/notification_service.dart';
import 'app_theme.dart';
import 'pages/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Load & validate environment ──────────────────────────────────────────
  // This will throw EnvValidationError and halt the app if any required
  // env var is missing or malformed. Pass --dart-define=APP_FLAVOR=production
  // to load .env.production instead of the default .env.development.
  await EnvLoader.load();

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

  static final _clerkConfig = clerk.ClerkAuthConfig(
    publishableKey: EnvInstance.instance.clerkPublishableKey,
    loading: null, // splash screen handles loading UI — disable Clerk's overlay
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buddy',
      theme: AppTheme.darkTheme,
      // ClerkAuth wraps the entire app via builder. _ClerkAuthRegistrar sits
      // inside that tree so ClerkAuth.of(context) is valid when it runs.
      home: const _ClerkAuthRegistrar(child: SplashScreen()),
      debugShowCheckedModeBanner: false,
      builder: clerk.ClerkAuth.materialAppBuilder(config: _clerkConfig),
    );
  }
}

/// Sits inside the ClerkAuth widget tree and registers the [ClerkAuthState]
/// with [ClerkAuthProvider] so [ApiClient] can get tokens without a context.
class _ClerkAuthRegistrar extends StatefulWidget {
  const _ClerkAuthRegistrar({required this.child});
  final Widget child;

  @override
  State<_ClerkAuthRegistrar> createState() => _ClerkAuthRegistrarState();
}

class _ClerkAuthRegistrarState extends State<_ClerkAuthRegistrar> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ClerkAuthProvider.instance.setAuthState(clerk.ClerkAuth.of(context));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clerk_flutter/clerk_flutter.dart' as clerk;
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/pages/home_page.dart';
import 'package:buddy/pages/login_page.dart';
import 'package:buddy/pages/onboarding_screen.dart';
import 'package:buddy/services/api_client.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  Timer? _dotsTimer;
  int _dotsCount = 0;
  bool _resolveCalled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    _startDotsLoop();

    // Logging out Automatically for testing
    // Future.delayed(
    //   const Duration(seconds: 1),
    //   () => {clerk.ClerkAuth.of(context).signOut()},
    // );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_resolveCalled) {
      _resolveCalled = true;
      _resolveDestination();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _dotsTimer?.cancel();
    super.dispose();
  }

  void _startDotsLoop() {
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _dotsCount = (_dotsCount + 1) % 4);
    });
  }

  Future<void> _resolveDestination() async {
    final start = DateTime.now();

    final user = clerk.ClerkAuth.userOf(context);
    final bool isSignedIn = user != null;

    Widget destination;

    if (!isSignedIn) {
      destination = const LoginPage();
    } else {
      bool hasProfile = false;
      try {
        final res = await ApiClient.getProfile();
        hasProfile = res['data'] != null;
      } catch (_) {
        hasProfile = false;
      }
      destination = hasProfile ? const HomePage() : const OnboardingScreen();
    }

    final elapsed = DateTime.now().difference(start);
    const minDuration = Duration(milliseconds: 1400);
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Stack(
            children: [
              // Subtle radial gradient behind centre
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.75,
                      colors: [AppTheme.cardDark, AppTheme.oledBlack],
                    ),
                  ),
                ),
              ),

              // Centre content
              Center(
                child: Semantics(
                  label: 'Buddy — Your personal fitness companion',
                  child: ExcludeSemantics(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.cardRaised,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: const Icon(
                        LucideIcons.activity,
                        color: AppTheme.textCream,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Wordmark
                    Text(
                      'Buddy',
                      style: GoogleFonts.sora(
                        color: AppTheme.textCream,
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Tagline
                    Text(
                      'Your personal fitness companion',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                  ),
                ),
              ),

              // Bottom loading indicator
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ExcludeSemantics(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Column(
                      children: [
                        Text(
                          'Loading${'.' * _dotsCount}',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted.withValues(
                              alpha: 0.45,
                            ),
                            fontSize: 11,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 100,
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor: AppTheme.borderDark,
                            color: AppTheme.textSageMuted.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

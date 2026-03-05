import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/pages/home_page.dart';
import 'package:buddy/pages/onboarding_screen.dart';
import 'package:buddy/services/api_client.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  Timer? _phraseTimer;
  Timer? _dotsTimer;

  int _phraseIndex = 0;
  int _dotsCount = 0;

  final List<String> _phrases = const [
    'Loading your workouts',
    'Pulling in your health data',
    'Getting your plan ready',
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _startPhraseLoop();
    _startDotsLoop();
    _resolveDestination();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _fadeController.dispose();
    _phraseTimer?.cancel();
    _dotsTimer?.cancel();
    super.dispose();
  }

  void _startPhraseLoop() {
    _phraseTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() => _phraseIndex = (_phraseIndex + 1) % _phrases.length);
    });
  }

  void _startDotsLoop() {
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() => _dotsCount = (_dotsCount + 1) % 4);
    });
  }

  Future<void> _resolveDestination() async {
    final start = DateTime.now();
    bool hasProfile = false;

    try {
      final res = await ApiClient.getProfile();
      hasProfile = res['exists'] == true && res['data'] != null;
    } catch (_) {
      hasProfile = false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', hasProfile);

    final elapsed = DateTime.now().difference(start);
    const minDuration = Duration(milliseconds: 1200);
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            hasProfile ? const HomePage() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.backgroundDark,
                      AppTheme.cardDark,
                      AppTheme.backgroundDark,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBadgeRow(),
                    const SizedBox(height: 32),
                    Text(
                      'Buddy',
                      style: GoogleFonts.crimsonPro(
                        color: AppTheme.textCream,
                        fontSize: 42,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your personal fitness companion',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: Text(
                        _phrases[_phraseIndex],
                        key: ValueKey(_phraseIndex),
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Checking your profile${'.' * _dotsCount}',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 180,
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: AppTheme.borderDark,
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeRow() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final t = _floatController.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge('💪', -6 * (1 - t)),
            const SizedBox(width: 16),
            _buildBadge('🥗', 8 * (t - 0.5)),
            const SizedBox(width: 16),
            _buildBadge('🧘', -5 * (t - 0.2)),
          ],
        );
      },
    );
  }

  Widget _buildBadge(String emoji, double offsetY) {
    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderDark),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
      ),
    );
  }
}

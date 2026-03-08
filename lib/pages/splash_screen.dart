import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/pages/home_page.dart';
import 'package:buddy/pages/onboarding_screen.dart';
import 'package:buddy/services/api_client.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resolveDestination();
    });
  }

  Future<void> _resolveDestination() async {
    bool isOnboarded = false;
    try {
      final res = await ApiClient.getMe();
      final data = res['data'] as Map<String, dynamic>?;
      isOnboarded = data?['onboarded'] == true;
    } catch (_) {
      isOnboarded = false;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            isOnboarded ? const HomePage() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                'Buddy',
                style: GoogleFonts.sora(
                  color: AppTheme.textCream,
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: AppTheme.borderDark,
                color: AppTheme.textSageMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

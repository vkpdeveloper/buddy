import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/app_color_scheme.dart';
import 'package:buddy/pages/home_page.dart';
import 'package:buddy/pages/onboarding_screen.dart';
import 'package:buddy/services/auth_service.dart';
import 'package:buddy/services/home_dashboard_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _errorMessage;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled
        setState(() => _loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user!;

      await AuthService.register(
        email: user.email ?? '',
        name: user.displayName ?? '',
        photoUrl: user.photoURL,
      );

      if (!mounted) return;

      bool isOnboarded = false;
      try {
        final res = await AuthService.getMe();
        final data = res['data'] as Map<String, dynamic>?;
        isOnboarded = data?['onboarded'] == true;
      } catch (_) {
        isOnboarded = false;
      }

      if (!mounted) return;
      if (isOnboarded) {
        try {
          await HomeDashboardPreferences.preload();
        } catch (_) {
          // Fall back to defaults if local prefs are unavailable.
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              isOnboarded ? const HomePage() : const OnboardingScreen(),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign-in failed. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed background image
          ExcludeSemantics(
            child: Image.asset(
              'assets/images/login_background.png',
              fit: BoxFit.cover,
            ),
          ),

          // Multi-stop gradient overlay — preserves image at top,
          // creates a solid readable base for the CTA at the bottom
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.transparent,
                    context.colors.scrimSoft,
                    context.colors.scrimHeavy,
                    context.colors.scrimDense,
                    context.colors.background,
                  ],
                  stops: const [0.0, 0.3, 0.55, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),

                      // App name
                      Text(
                        'Buddy',
                        style: GoogleFonts.sora(
                          color: context.colors.textPrimary,
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tagline
                      Text.rich(
                        TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            color: context.colors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.6,
                            letterSpacing: 0.2,
                          ),
                          children: [
                            const TextSpan(
                              text:
                                  'Build meals, workouts, and progress targets that fit your real life.\nBuddy helps you stay ',
                            ),
                            TextSpan(
                              text: 'clear and consistent',
                              style: GoogleFonts.plusJakartaSans(
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Google sign-in button
                      _buildGoogleButton(context),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            color: context.colors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Terms
                      Center(
                        child: Text(
                          'By continuing you agree to our Terms & Privacy Policy',
                          style: GoogleFonts.plusJakartaSans(
                            color: context.colors.textMuted,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !_loading,
      label: _loading ? 'Signing in, please wait' : 'Continue with Google',
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: context.colors.actionSurface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _loading ? null : _signInWithGoogle,
            borderRadius: BorderRadius.circular(14),
            splashColor: context.colors.actionForeground.withValues(alpha: 0.06),
            highlightColor: context.colors.actionForeground.withValues(alpha: 0.03),
            child: Center(
              child: _loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colors.actionForeground,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(child: _GoogleLogo()),
                        const SizedBox(width: 12),
                        Text(
                          'Continue with Google',
                          style: GoogleFonts.plusJakartaSans(
                            color: context.colors.actionForeground,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/icons/google.png', width: 22, height: 22);
  }
}

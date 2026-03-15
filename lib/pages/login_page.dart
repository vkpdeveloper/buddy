import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
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
  static const List<double> _overlayStops = [0.0, 0.38, 0.62, 0.82, 1.0];
  static const List<double> _glowStops = [0.0, 0.32, 1.0];
  static const List<Shadow> _heroTextShadows = [
    Shadow(color: Color(0xA6000000), blurRadius: 24, offset: Offset(0, 8)),
    Shadow(color: Color(0x52000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

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
    final colors = context.colors;
    final palette = _LoginVisualPalette.fromColors(colors);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUiOverlayStyle(palette),
      child: Scaffold(
        backgroundColor: colors.background,
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

            // Keep the hero image readable and fade into a darker stage so the
            // CTA area feels intentional without adding a separate container.
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _overlayColors(colors),
                    stops: _overlayStops,
                  ),
                ),
              ),
            ),
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, 1.08),
                    radius: 0.92,
                    colors: palette.bottomGlowColors,
                    stops: _glowStops,
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
                            color: palette.heroPrimary,
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.0,
                            shadows: _heroTextShadows,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Tagline
                        Text.rich(
                          TextSpan(
                            style: GoogleFonts.plusJakartaSans(
                              color: palette.heroSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.6,
                              letterSpacing: 0.2,
                              shadows: _heroTextShadows,
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    'Build meals, workouts, and progress targets that fit your real life.\nBuddy helps you stay ',
                              ),
                              TextSpan(
                                text: 'clear and consistent',
                                style: GoogleFonts.plusJakartaSans(
                                  color: palette.heroPrimary,
                                  fontWeight: FontWeight.w700,
                                  shadows: _heroTextShadows,
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildGoogleButton(context, palette),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage!,
                            style: GoogleFonts.plusJakartaSans(
                              color: colors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'By continuing you agree to our Terms & Privacy Policy',
                            style: GoogleFonts.plusJakartaSans(
                              color: palette.termsColor,
                              fontSize: 11,
                              letterSpacing: 0.25,
                              height: 1.5,
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
      ),
    );
  }

  Widget _buildGoogleButton(BuildContext context, _LoginVisualPalette palette) {
    final splashColor = palette.buttonForeground.withValues(alpha: 0.08);
    final highlightColor = palette.buttonForeground.withValues(alpha: 0.04);

    return Semantics(
      button: true,
      enabled: !_loading,
      label: _loading ? 'Signing in, please wait' : 'Continue with Google',
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: palette.buttonSurface,
          elevation: palette.buttonElevation,
          shadowColor: palette.buttonShadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: palette.buttonBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _loading ? null : _signInWithGoogle,
            borderRadius: BorderRadius.circular(14),
            splashColor: splashColor,
            highlightColor: highlightColor,
            child: Center(
              child: _loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          palette.buttonForeground,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ExcludeSemantics(child: _GoogleLogo()),
                        const SizedBox(width: 12),
                        Text(
                          'Continue with Google',
                          style: GoogleFonts.plusJakartaSans(
                            color: palette.buttonForeground,
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

  List<Color> _overlayColors(AppColorScheme colors) {
    if (colors.isDark) {
      return [
        AppTheme.transparent,
        const Color(0x12000000),
        const Color(0x68040506),
        const Color(0xD20A0909),
        const Color(0xFF090807),
      ];
    }

    return [
      AppTheme.transparent,
      const Color(0x14000000),
      const Color(0x54070505),
      const Color(0xBF1B120E),
      const Color(0xFF201611),
    ];
  }

  SystemUiOverlayStyle _systemUiOverlayStyle(_LoginVisualPalette palette) {
    return SystemUiOverlayStyle.light.copyWith(
      statusBarColor: AppTheme.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.transparent,
      systemNavigationBarDividerColor: AppTheme.transparent,
      systemNavigationBarIconBrightness: palette.navigationIconBrightness,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/icons/google.png', width: 22, height: 22);
  }
}

class _LoginVisualPalette {
  const _LoginVisualPalette({
    required this.heroPrimary,
    required this.heroSecondary,
    required this.termsColor,
    required this.bottomGlowColors,
    required this.buttonSurface,
    required this.buttonForeground,
    required this.buttonBorder,
    required this.buttonShadow,
    required this.buttonElevation,
    required this.navigationIconBrightness,
  });

  final Color heroPrimary;
  final Color heroSecondary;
  final Color termsColor;
  final List<Color> bottomGlowColors;
  final Color buttonSurface;
  final Color buttonForeground;
  final Color buttonBorder;
  final Color buttonShadow;
  final double buttonElevation;
  final Brightness navigationIconBrightness;

  factory _LoginVisualPalette.fromColors(AppColorScheme colors) {
    if (colors.isDark) {
      return _LoginVisualPalette(
        heroPrimary: AppTheme.textCream,
        heroSecondary: AppTheme.textMain.withValues(alpha: 0.94),
        termsColor: const Color(0xFFB2A59A),
        bottomGlowColors: const [
          Color(0x26D4A853),
          Color(0x126D927A),
          Color(0x00000000),
        ],
        buttonSurface: const Color(0xFF090807),
        buttonForeground: const Color(0xFFF3ECE2),
        buttonBorder: const Color(0x29FFFFFF),
        buttonShadow: const Color(0x55000000),
        buttonElevation: 2,
        navigationIconBrightness: Brightness.light,
      );
    }

    return _LoginVisualPalette(
      heroPrimary: AppTheme.textCream,
      heroSecondary: AppTheme.textMain.withValues(alpha: 0.9),
      termsColor: const Color(0xFFD2C0AB),
      bottomGlowColors: const [
        Color(0x2CB08F58),
        Color(0x18B36A6A),
        Color(0x00000000),
      ],
      buttonSurface: const Color(0xFFF0E2D3),
      buttonForeground: const Color(0xFF1B1410),
      buttonBorder: const Color(0x1FFFFFFF),
      buttonShadow: const Color(0x42000000),
      buttonElevation: 2,
      navigationIconBrightness: Brightness.light,
    );
  }
}

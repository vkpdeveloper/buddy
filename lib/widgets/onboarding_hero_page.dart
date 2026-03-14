import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/app_color_scheme.dart';
import 'package:buddy/widgets/app_buttons.dart';

/// The welcome screen.
class OnboardingHeroPage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSignOut;

  const OnboardingHeroPage({
    super.key,
    required this.onNext,
    required this.onSignOut,
  });

  @override
  State<OnboardingHeroPage> createState() => _OnboardingHeroPageState();
}

class _OnboardingHeroPageState extends State<OnboardingHeroPage>
    with TickerProviderStateMixin {
  late final AnimationController _headlineController;
  late final AnimationController _ctaController;

  @override
  void initState() {
    super.initState();

    _headlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _runEntrySequence();
  }

  Future<void> _runEntrySequence() async {
    await _headlineController.forward();
    await Future.delayed(const Duration(milliseconds: 60));
    if (mounted) _ctaController.forward();
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _ctaController.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          _buildHeadline(context),
          const Spacer(),
          _buildCTABlock(context),
        ],
      ),
    );
  }

  // ─── Headline ─────────────────────────────────────────────────────────────

  Widget _buildHeadline(BuildContext context) {
    return _SlideUp(
      controller: _headlineController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eat better.\nTrain smarter.\nSee real results.',
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Answer a few quick questions and Buddy will build your custom plan.',
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── CTA block ────────────────────────────────────────────────────────────

  Widget _buildCTABlock(BuildContext context) {
    return FadeTransition(
      opacity: _ctaController,
      child: Column(
        children: [
          AppPrimaryButton(
            label: 'BUILD MY CUSTOM PLAN',
            onPressed: widget.onNext,
            icon: LucideIcons.arrow_right,
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: widget.onSignOut,
            style: TextButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                AppTheme.minimumTouchTarget,
              ),
              foregroundColor: context.colors.textMuted,
            ),
            icon: const Icon(LucideIcons.log_out, size: 14),
            label: Text(
              'Not you? Sign out',
              style: GoogleFonts.plusJakartaSans(
                color: context.colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: context.colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable slide-up transition ─────────────────────────────────────────────

class _SlideUp extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _SlideUp({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

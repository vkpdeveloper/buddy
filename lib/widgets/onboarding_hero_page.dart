import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';

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
          _buildHeadline(),
          const Spacer(),
          _buildCTABlock(),
        ],
      ),
    );
  }

  // ─── Headline ─────────────────────────────────────────────────────────────

  Widget _buildHeadline() {
    return _SlideUp(
      controller: _headlineController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eat better.\nTrain smarter.\nSee real results.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Answer a few quick questions and Buddy will build your custom plan.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
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

  Widget _buildCTABlock() {
    return FadeTransition(
      opacity: _ctaController,
      child: Column(
        children: [
          GestureDetector(
            onTap: widget.onNext,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.actionSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'BUILD MY CUSTOM PLAN',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.actionForeground,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.arrow_right,
                    color: AppTheme.actionForeground,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: widget.onSignOut,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.log_out,
                    size: 12,
                    color: AppTheme.textSageMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Not you? Sign out',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted.withValues(alpha: 0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.textSageMuted.withValues(
                        alpha: 0.25,
                      ),
                    ),
                  ),
                ],
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

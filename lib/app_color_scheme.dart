import 'package:flutter/material.dart';

/// Semantic colour tokens that adapt between dark and light mode.
///
/// Registered via [ThemeData.extensions] in both [AppTheme.darkTheme] and
/// [AppTheme.lightTheme]. Access at any widget site via [BuildContext.colors].
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.background,
    required this.backgroundSecondary,
    required this.card,
    required this.cardRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.primary,
    required this.accent,
    required this.actionSurface,
    required this.actionForeground,
    required this.cardGradientStart,
    required this.cardGradientMid,
    required this.cardGradientEnd,
    required this.shadowColor,
    required this.shadowStrong,
    required this.scrimSoft,
    required this.scrimHeavy,
    required this.scrimDense,
    required this.xpGold,
    required this.levelArc,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.errorBg,
    required this.dangerBg,
    required this.sleepDeep,
    required this.sleepRem,
    required this.phaseRest,
    required this.phaseCompleted,
    required this.phaseExercise,
    required this.macroCarbs,
    required this.swapAction,
    required this.deleteAction,
    required this.chartDuration,
    required this.muscleChest,
    required this.muscleBack,
    required this.muscleLegs,
    required this.muscleShoulders,
    required this.muscleArms,
  });

  // ── Surfaces ──────────────────────────────────────────────────────────────
  final Color background;           // oledBlack / scaffold
  final Color backgroundSecondary;  // backgroundDark / secondary surface
  final Color card;                 // cardDark / base card
  final Color cardRaised;           // elevated card layer

  // ── Card gradient (three stops; broken apart to allow const) ──────────────
  final Color cardGradientStart;
  final Color cardGradientMid;
  final Color cardGradientEnd;

  /// Full three-stop card gradient for use in [LinearGradient.colors].
  List<Color> get cardGradient =>
      [cardGradientStart, cardGradientMid, cardGradientEnd];

  /// True when this is the dark colour scheme.
  bool get isDark => background.computeLuminance() < 0.5;

  /// In dark mode: returns [darkColors] (your accent-tinted stops).
  /// In light mode: falls back to the warm-white [cardGradient] so tinted
  /// dark-mode gradients don't look flat/grey on a white card.
  List<Color> tintedCardGradient(List<Color> darkColors) =>
      isDark ? darkColors : cardGradient;

  // ── Text ──────────────────────────────────────────────────────────────────
  final Color textPrimary;    // textCream
  final Color textSecondary;  // textMain
  final Color textMuted;      // textSageMuted
  final Color border;         // borderDark

  // ── Interactive / primary ─────────────────────────────────────────────────
  final Color primary;
  final Color accent;
  final Color actionSurface;
  final Color actionForeground;

  // ── Depth / shadow ────────────────────────────────────────────────────────
  final Color shadowColor;
  final Color shadowStrong;
  final Color scrimSoft;
  final Color scrimHeavy;
  final Color scrimDense;

  // ── Gamification ──────────────────────────────────────────────────────────
  final Color xpGold;
  final Color levelArc;

  // ── Semantic feedback ─────────────────────────────────────────────────────
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color errorBg;
  final Color dangerBg;

  // ── Sleep stages ──────────────────────────────────────────────────────────
  final Color sleepDeep;
  final Color sleepRem;

  // ── Workout phase fills ───────────────────────────────────────────────────
  final Color phaseRest;
  final Color phaseCompleted;
  final Color phaseExercise;

  // ── Domain accents ────────────────────────────────────────────────────────
  final Color macroCarbs;
  final Color swapAction;
  final Color deleteAction;
  final Color chartDuration;

  // ── Muscle group accents ──────────────────────────────────────────────────
  final Color muscleChest;
  final Color muscleBack;
  final Color muscleLegs;
  final Color muscleShoulders;
  final Color muscleArms;

  // ── Card decoration helper ────────────────────────────────────────────────

  BoxDecoration cardDecoration({
    double radius = 20,
    Color? borderColor,
    List<Color>? gradientColors,
    bool withShadow = true,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? border.withValues(alpha: 0.95),
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors ?? cardGradient,
      ),
      boxShadow: withShadow
          ? [
              BoxShadow(
                color: shadowColor,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
    );
  }

  // ── Static instances ───────────────────────────────────────────────────────

  /// Dark token set — matches the original AppTheme constants exactly.
  static const AppColorScheme dark = AppColorScheme(
    background: Color(0xFF000000),
    backgroundSecondary: Color(0xFF0A0B0D),
    card: Color(0xFF0F1012),
    cardRaised: Color(0xFF15171A),
    textPrimary: Color(0xFFE3E6EA),
    textSecondary: Color(0xFFC9CED5),
    textMuted: Color(0xFF939DAA),
    border: Color(0xFF23262B),
    primary: Color(0xFF7B8188),
    accent: Color(0xFF4F545A),
    actionSurface: Color(0xFFC9CED5),
    actionForeground: Color(0xFF000000),
    cardGradientStart: Color(0xFF1A151B),
    cardGradientMid: Color(0xFF14161A),
    cardGradientEnd: Color(0xFF0F1012),
    shadowColor: Color(0x47000000),
    shadowStrong: Color(0xAA000000),
    scrimSoft: Color(0x33000000),
    scrimHeavy: Color(0xCC000000),
    scrimDense: Color(0xF5000000),
    xpGold: Color(0xFFD4A853),
    levelArc: Color(0xFF7A838E),
    success: Color(0xFF6D927A),
    warning: Color(0xFFB08F58),
    error: Color(0xFFB36A6A),
    info: Color(0xFF7B8FA5),
    errorBg: Color(0xFF7E2E2E),
    dangerBg: Color(0xFF8F2E2E),
    sleepDeep: Color(0xFF5D6E82),
    sleepRem: Color(0xFF77708A),
    phaseRest: Color(0xFF1B2320),
    phaseCompleted: Color(0xFF18201B),
    phaseExercise: Color(0xFF171C20),
    macroCarbs: Color(0xFF7A8076),
    swapAction: Color(0xFF1E2535),
    deleteAction: Color(0xFF5C2020),
    chartDuration: Color(0xFF7B8FA5),
    muscleChest: Color(0xFFB08A56),
    muscleBack: Color(0xFF7B8FA5),
    muscleLegs: Color(0xFF5F8C75),
    muscleShoulders: Color(0xFF8F879E),
    muscleArms: Color(0xFFA37A83),
  );

  /// Light token set — warm earthy palette, AA/AAA contrast throughout.
  static const AppColorScheme light = AppColorScheme(
    background: Color(0xFFF5F2EE),
    backgroundSecondary: Color(0xFFEDE9E4),
    card: Color(0xFFFFFFFF),
    cardRaised: Color(0xFFF7F4F0),
    textPrimary: Color(0xFF1C1917),
    textSecondary: Color(0xFF302C28),
    textMuted: Color(0xFF6B6560),
    border: Color(0xFFDDD8D2),
    primary: Color(0xFF5E6470),
    accent: Color(0xFF8A9098),
    actionSurface: Color(0xFF000000),
    actionForeground: Color(0xFFFFFFFF),
    cardGradientStart: Color(0xFFFFFFFF),
    cardGradientMid: Color(0xFFFAF8F5),
    cardGradientEnd: Color(0xFFF4F1ED),
    shadowColor: Color(0x14000000),
    shadowStrong: Color(0x29000000),
    scrimSoft: Color(0x1A000000),
    scrimHeavy: Color(0x80000000),
    scrimDense: Color(0xCC000000),
    xpGold: Color(0xFF9B7A2E),
    levelArc: Color(0xFF8A939E),
    success: Color(0xFF3D7056),
    warning: Color(0xFF7A6030),
    error: Color(0xFF8B3636),
    info: Color(0xFF4A6A85),
    errorBg: Color(0xFFFDECEA),
    dangerBg: Color(0xFFFDE8E8),
    sleepDeep: Color(0xFF3D5A72),
    sleepRem: Color(0xFF4E4868),
    phaseRest: Color(0xFFEDF5F1),
    phaseCompleted: Color(0xFFECF4EE),
    phaseExercise: Color(0xFFEDF2F7),
    macroCarbs: Color(0xFF5A6056),
    swapAction: Color(0xFFD8E0F0),
    deleteAction: Color(0xFFFFEBEB),
    chartDuration: Color(0xFF4A6A85),
    muscleChest: Color(0xFF8C6A35),
    muscleBack: Color(0xFF4A6A85),
    muscleLegs: Color(0xFF3D7056),
    muscleShoulders: Color(0xFF6A6280),
    muscleArms: Color(0xFF7A5060),
  );

  // ── ThemeExtension overrides ───────────────────────────────────────────────

  @override
  AppColorScheme copyWith({
    Color? background,
    Color? backgroundSecondary,
    Color? card,
    Color? cardRaised,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? primary,
    Color? accent,
    Color? actionSurface,
    Color? actionForeground,
    Color? cardGradientStart,
    Color? cardGradientMid,
    Color? cardGradientEnd,
    Color? shadowColor,
    Color? shadowStrong,
    Color? scrimSoft,
    Color? scrimHeavy,
    Color? scrimDense,
    Color? xpGold,
    Color? levelArc,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? errorBg,
    Color? dangerBg,
    Color? sleepDeep,
    Color? sleepRem,
    Color? phaseRest,
    Color? phaseCompleted,
    Color? phaseExercise,
    Color? macroCarbs,
    Color? swapAction,
    Color? deleteAction,
    Color? chartDuration,
    Color? muscleChest,
    Color? muscleBack,
    Color? muscleLegs,
    Color? muscleShoulders,
    Color? muscleArms,
  }) {
    return AppColorScheme(
      background: background ?? this.background,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      card: card ?? this.card,
      cardRaised: cardRaised ?? this.cardRaised,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      actionSurface: actionSurface ?? this.actionSurface,
      actionForeground: actionForeground ?? this.actionForeground,
      cardGradientStart: cardGradientStart ?? this.cardGradientStart,
      cardGradientMid: cardGradientMid ?? this.cardGradientMid,
      cardGradientEnd: cardGradientEnd ?? this.cardGradientEnd,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowStrong: shadowStrong ?? this.shadowStrong,
      scrimSoft: scrimSoft ?? this.scrimSoft,
      scrimHeavy: scrimHeavy ?? this.scrimHeavy,
      scrimDense: scrimDense ?? this.scrimDense,
      xpGold: xpGold ?? this.xpGold,
      levelArc: levelArc ?? this.levelArc,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      errorBg: errorBg ?? this.errorBg,
      dangerBg: dangerBg ?? this.dangerBg,
      sleepDeep: sleepDeep ?? this.sleepDeep,
      sleepRem: sleepRem ?? this.sleepRem,
      phaseRest: phaseRest ?? this.phaseRest,
      phaseCompleted: phaseCompleted ?? this.phaseCompleted,
      phaseExercise: phaseExercise ?? this.phaseExercise,
      macroCarbs: macroCarbs ?? this.macroCarbs,
      swapAction: swapAction ?? this.swapAction,
      deleteAction: deleteAction ?? this.deleteAction,
      chartDuration: chartDuration ?? this.chartDuration,
      muscleChest: muscleChest ?? this.muscleChest,
      muscleBack: muscleBack ?? this.muscleBack,
      muscleLegs: muscleLegs ?? this.muscleLegs,
      muscleShoulders: muscleShoulders ?? this.muscleShoulders,
      muscleArms: muscleArms ?? this.muscleArms,
    );
  }

  @override
  AppColorScheme lerp(ThemeExtension<AppColorScheme>? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      background: Color.lerp(background, other.background, t)!,
      backgroundSecondary:
          Color.lerp(backgroundSecondary, other.backgroundSecondary, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardRaised: Color.lerp(cardRaised, other.cardRaised, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      actionSurface: Color.lerp(actionSurface, other.actionSurface, t)!,
      actionForeground:
          Color.lerp(actionForeground, other.actionForeground, t)!,
      cardGradientStart:
          Color.lerp(cardGradientStart, other.cardGradientStart, t)!,
      cardGradientMid: Color.lerp(cardGradientMid, other.cardGradientMid, t)!,
      cardGradientEnd: Color.lerp(cardGradientEnd, other.cardGradientEnd, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      shadowStrong: Color.lerp(shadowStrong, other.shadowStrong, t)!,
      scrimSoft: Color.lerp(scrimSoft, other.scrimSoft, t)!,
      scrimHeavy: Color.lerp(scrimHeavy, other.scrimHeavy, t)!,
      scrimDense: Color.lerp(scrimDense, other.scrimDense, t)!,
      xpGold: Color.lerp(xpGold, other.xpGold, t)!,
      levelArc: Color.lerp(levelArc, other.levelArc, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      sleepDeep: Color.lerp(sleepDeep, other.sleepDeep, t)!,
      sleepRem: Color.lerp(sleepRem, other.sleepRem, t)!,
      phaseRest: Color.lerp(phaseRest, other.phaseRest, t)!,
      phaseCompleted: Color.lerp(phaseCompleted, other.phaseCompleted, t)!,
      phaseExercise: Color.lerp(phaseExercise, other.phaseExercise, t)!,
      macroCarbs: Color.lerp(macroCarbs, other.macroCarbs, t)!,
      swapAction: Color.lerp(swapAction, other.swapAction, t)!,
      deleteAction: Color.lerp(deleteAction, other.deleteAction, t)!,
      chartDuration: Color.lerp(chartDuration, other.chartDuration, t)!,
      muscleChest: Color.lerp(muscleChest, other.muscleChest, t)!,
      muscleBack: Color.lerp(muscleBack, other.muscleBack, t)!,
      muscleLegs: Color.lerp(muscleLegs, other.muscleLegs, t)!,
      muscleShoulders: Color.lerp(muscleShoulders, other.muscleShoulders, t)!,
      muscleArms: Color.lerp(muscleArms, other.muscleArms, t)!,
    );
  }
}

/// Convenience accessor — `context.colors.textPrimary` etc.
extension AppColorSchemeX on BuildContext {
  AppColorScheme get colors =>
      Theme.of(this).extension<AppColorScheme>()!;
}

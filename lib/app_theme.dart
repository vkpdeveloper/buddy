import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// WCAG contrast ratios (against oledBlack #000000 unless noted):
///   AA  normal text ≥ 4.5:1 | large text / non-text UI ≥ 3.0:1
///   AAA normal text ≥ 7.0:1 | large text                ≥ 4.5:1
class AppTheme {
  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const Color oledBlack = Color(0xFF000000); // OLED base
  static const Color backgroundDark = Color(0xFF0A0B0D); // fallback surface
  static const Color cardDark = Color(0xFF0F1012); // base card
  static const Color cardRaised = Color(0xFF15171A); // elevated card
  static const Color transparent = Color(0x00000000);

  // ── Interactive / primary ─────────────────────────────────────────────────
  // accent: surface / container fill ONLY — 2.75:1, never use as text
  static const Color accent = Color(0xFF4F545A);
  // primary: AA on all surfaces (5.34:1 on oledBlack)
  static const Color primary = Color(0xFF7B8188);
  // actionSurface/actionForeground: AAA pair for high-emphasis CTA controls
  static const Color actionSurface = textMain;
  static const Color actionForeground = oledBlack;

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textCream = Color(0xFFE3E6EA); // AAA  16.8:1
  static const Color textMain = Color(0xFFC9CED5); // AAA  13.3:1
  static const Color textSageMuted = Color(
    0xFF939DAA,
  ); // AAA   7.6:1  (was #878E97 → 6.4:1)
  static const Color borderDark = Color(
    0xFF23262B,
  ); // structural edge, not text

  // ── Gamification ──────────────────────────────────────────────────────────
  static const Color xpGold = Color(0xFFD4A853); // AAA   9.5:1
  // levelArc: progress arcs / bars — non-text UI (≥3:1 required; 5.5:1 achieved)
  static const Color levelArc = Color(
    0xFF7A838E,
  ); // AA    5.5:1  (was #6A7178 → 4.2:1)

  // ── Semantic feedback / status ────────────────────────────────────────────
  static const Color success = Color(0xFF6D927A); // AA    6.0:1
  static const Color warning = Color(0xFFB08F58); // AA    6.9:1
  static const Color error = Color(
    0xFFB36A6A,
  ); // AA    5.1:1  (was #A05C5C → 4.2:1 ✗)
  static const Color info = Color(
    0xFF7B8FA5,
  ); // AA    6.4:1  (was #6C7E92 → fails cardRaised)
  static const Color errorBg = Color(0xFF7E2E2E); // background fill, not text
  static const Color dangerBg = Color(0xFF8F2E2E); // background fill, not text

  // ── Sleep stages ──────────────────────────────────────────────────────────
  static const Color sleepDeep = Color(0xFF5D6E82);
  static const Color sleepRem = Color(0xFF77708A);

  // ── Workout phase fills (backgrounds, not text) ───────────────────────────
  static const Color phaseRest = Color(0xFF1B2320);
  static const Color phaseCompleted = Color(0xFF18201B);
  static const Color phaseExercise = Color(0xFF171C20);

  // ── Domain accents ────────────────────────────────────────────────────────
  static const Color macroCarbs = Color(0xFF7A8076);
  static const Color swapAction = Color(0xFF1E2535);
  static const Color deleteAction = Color(0xFF5C2020);
  static const Color chartDuration = Color(0xFF7B8FA5); // aligned with info

  // ── Muscle group accents ──────────────────────────────────────────────────
  static const Color muscleChest = Color(0xFFB08A56); // AA  6.6:1
  static const Color muscleBack = Color(
    0xFF7B8FA5,
  ); // AA  6.4:1  (was #6C7E92 → fails cardRaised)
  static const Color muscleLegs = Color(0xFF5F8C75); // AA  5.5:1
  static const Color muscleShoulders = Color(
    0xFF8F879E,
  ); // AA  6.1:1  (was #7C7390 → fails cardDark)
  static const Color muscleArms = Color(0xFFA37A83); // AA  5.7:1

  // ── Depth / shadow ────────────────────────────────────────────────────────
  static const Color shadowSoft = Color(0x66000000);
  static const Color shadowStrong = Color(0xAA000000);
  static const Color glowPrimary = Color(0x00000000);
  static const Color scrimSoft = Color(0x33000000);
  static const Color scrimHeavy = Color(0xCC000000);
  static const Color scrimDense = Color(0xF5000000);

  /// Display/heading font (Sora). Use for large titles and section headers.
  static TextStyle displayStyle({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textCream,
    double? letterSpacing,
  }) {
    return GoogleFonts.sora(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: oledBlack,
      primaryColor: primary,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: cardDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionSurface,
          foregroundColor: actionForeground,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: actionSurface,
          foregroundColor: actionForeground,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: actionSurface,
        foregroundColor: actionForeground,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: oledBlack, elevation: 0),
    );
  }
}

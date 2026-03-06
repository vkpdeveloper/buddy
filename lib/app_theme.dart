import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // AMOLED-first palette using limited, desaturated accents.
  static const Color primary = Color(0xFF7B8188); // Subtle slate highlight
  static const Color accent = Color(0xFF4F545A); // Deep slate secondary
  static const Color backgroundDark = Color(
    0xFF0A0B0D,
  ); // Fallback dark surface
  static const Color oledBlack = Color(0xFF000000); // OLED-optimized surfaces
  static const Color transparent = Color(0x00000000);
  static const Color cardDark = Color(0xFF0F1012); // Base card
  static const Color cardRaised = Color(0xFF15171A); // Elevated card

  static const Color textCream = Color(0xFFE3E6EA); // Primary text
  static const Color textMain = Color(0xFFC9CED5); // Body text
  static const Color textSageMuted = Color(0xFF878E97); // Muted support text
  static const Color borderDark = Color(0xFF23262B); // Edge definition

  // Gamification
  static const Color xpGold = Color(0xFFD4A853); // muted amber for XP/streak
  static const Color levelArc = Color(0xFF6A7178); // progress bars

  // Semantic feedback/status
  static const Color success = Color(0xFF6D927A);
  static const Color warning = Color(0xFFB08F58);
  static const Color info = Color(0xFF6C7E92);
  static const Color error = Color(0xFFA05C5C);
  static const Color errorBg = Color(0xFF7E2E2E);
  static const Color dangerBg = Color(0xFF8F2E2E);

  // Sleep stages
  static const Color sleepDeep = Color(0xFF5D6E82);
  static const Color sleepRem = Color(0xFF77708A);

  // Workout phase gradients
  static const Color phaseRest = Color(0xFF1B2320);
  static const Color phaseCompleted = Color(0xFF18201B);
  static const Color phaseExercise = Color(0xFF171C20);

  // Domain accents
  static const Color macroCarbs = Color(0xFF7A8076);
  static const Color swapAction = Color(0xFF1E2535);
  static const Color deleteAction = Color(0xFF5C2020);
  static const Color chartDuration = Color(0xFF6C7E92);

  // Muscle group accents
  static const Color muscleChest = Color(0xFFB08A56);
  static const Color muscleBack = Color(0xFF6C7E92);
  static const Color muscleLegs = Color(0xFF5F8C75);
  static const Color muscleShoulders = Color(0xFF7C7390);
  static const Color muscleArms = Color(0xFFA37A83);

  // Depth tokens
  static const Color shadowSoft = Color(0x66000000);
  static const Color shadowStrong = Color(0xAA000000);
  static const Color glowPrimary = Color(0x00000000);

  // Re-map the old generic text names to the new theme for easier migration
  static const Color textGray888 = textSageMuted;
  static const Color textGray666 = textSageMuted;
  static const Color textGray333 = accent;

  /// Display/heading font style (Sora). Use for large titles and section headers.
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
      appBarTheme: const AppBarTheme(backgroundColor: oledBlack, elevation: 0),
    );
  }
}

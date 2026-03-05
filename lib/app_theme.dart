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
  static const Color cardDark = Color(0xFF0F1012); // Base card
  static const Color cardRaised = Color(0xFF15171A); // Elevated card

  static const Color textCream = Color(0xFFE3E6EA); // Primary text
  static const Color textMain = Color(0xFFC9CED5); // Body text
  static const Color textSageMuted = Color(0xFF878E97); // Muted support text
  static const Color borderDark = Color(0xFF23262B); // Edge definition

  // Gamification
  static const Color xpGold = Color(0xFFD4A853); // muted amber for XP/streak
  static const Color levelArc = Color(0xFF6A7178); // progress bars

  // Depth tokens
  static const Color shadowSoft = Color(0x66000000);
  static const Color shadowStrong = Color(0xAA000000);
  static const Color glowPrimary = Color(0x00000000);

  // Re-map the old generic text names to the new theme for easier migration
  static const Color textGray888 = textSageMuted;
  static const Color textGray666 = textSageMuted;
  static const Color textGray333 = accent;

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

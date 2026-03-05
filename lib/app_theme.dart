import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // AMOLED-first palette with grayscale-only accents.
  static const Color primary = Color(0xFF9A9A9A); // Neutral highlight
  static const Color accent = Color(0xFF7C776F); // Secondary neutral (refined)
  static const Color backgroundDark = Color(
    0xFF0B1016,
  ); // Fallback dark surface
  static const Color oledBlack = Color(0xFF000000); // OLED-optimized surfaces
  static const Color cardDark = Color(0xFF101010); // Base card
  static const Color cardRaised = Color(0xFF161616); // Elevated card

  static const Color textCream = Color(0xFFE4E4E4); // Primary text
  static const Color textMain = Color(0xFFC8C8C8); // Body text
  static const Color textSageMuted = Color(0xFF868686); // Muted support text
  static const Color borderDark = Color(0xFF262522); // Edge definition

  // Gamification
  static const Color xpGold = Color(0xFFD4A853); // muted amber for XP/streak
  static const Color levelArc = Color(0xFF8A8A8A); // progress bars

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

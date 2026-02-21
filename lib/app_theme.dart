import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Top-level design constants from the new theme
  static const Color primary = Color(0xFFA8C3A9); // Desaturated Muted Sage
  static const Color accent = Color(0xFFB5C9AD); // Desaturated Pale Green
  static const Color backgroundDark = Color(0xFF0F1419); // Deep Charcoal
  static const Color cardDark = Color(
    0xFF181E24,
  ); // Slightly lighter charcoal for cards

  static const Color textCream = Color(
    0xFFE8E2D2,
  ); // Muted Cream for text/accents
  static const Color textMain = Color(0xFFE5E7EB); // Light grey
  static const Color textSageMuted = Color(0xFF8A949E); // Muted slate
  static const Color borderDark = Color(
    0xFF1F2933,
  ); // Implicitly inferred for borders

  // Re-map the old generic text names to the new theme for easier migration
  static const Color textGray888 = textSageMuted;
  static const Color textGray666 = textSageMuted;
  static const Color textGray333 = accent;

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primary,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: cardDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        elevation: 0,
      ),
    );
  }
}

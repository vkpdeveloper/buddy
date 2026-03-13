import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:buddy/app_theme.dart';

/// Shared text-field widget used across diet and workout forms.
/// Replaces the duplicate _EditField (diet_plan_page) and _Field (workout_page).
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType:
          keyboardType ?? (maxLines > 1 ? TextInputType.multiline : null),
      style: GoogleFonts.plusJakartaSans(
        color: AppTheme.textCream,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppTheme.textSageMuted,
          fontSize: 12,
        ),
        filled: true,
        fillColor: AppTheme.backgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
      ),
    );
  }
}

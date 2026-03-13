import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:buddy/app_theme.dart';

/// Shared text-field widget used across diet and workout forms.
/// Replaces the duplicate _EditField (diet_plan_page) and _Field (workout_page).
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final String? hintText;
  final String? semanticLabel;
  final String? suffixText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final FontWeight fontWeight;
  final double fontSize;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.hintText,
    this.semanticLabel,
    this.suffixText,
    this.inputFormatters,
    this.onChanged,
    this.fontWeight = FontWeight.w500,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel ?? label,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType:
            keyboardType ?? (maxLines > 1 ? TextInputType.multiline : null),
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.textCream,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          suffixText: suffixText,
          labelStyle: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSageMuted,
            fontSize: 12,
          ),
          hintStyle: GoogleFonts.plusJakartaSans(
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
      ),
    );
  }
}

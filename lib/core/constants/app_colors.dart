import 'package:flutter/material.dart';

/// Exact brand colors from the Lainted product document.
class AppColors {
  AppColors._();

  // TESTING a monochrome theme to match the new black logo mark
  // (assets/branding/splash-no-bg.jpeg, sampled at true #000000). Original
  // warm palette from the product doc, for revert:
  //   primary   = Color(0xFFA0522D); // Cinnamon
  //   secondary = Color(0xFFC9857A); // Dusty Rose
  //   accent    = Color(0xFFE8D5B7); // Warm Sand
  static const Color primary = Color(0xFF141414); // Ink (from logo black)
  static const Color secondary = Color(0xFF6B6B6B); // Slate Grey
  static const Color accent = Color(0xFFE5E5E5); // Pale Grey
  static const Color background = Color(0xFFFFFFFF); // White
  static const Color surface = Color(0xFFFFFFFF); // Pure White
  static const Color textPrimary = Color(0xFF1C1007); // Dark Brown
  static const Color textMuted = Color(0xFF7A6C65); // Warm Grey
  static const Color success = Color(0xFF7DAF7D); // Muted Sage
  static const Color error = Color(0xFFC0392B); // Muted Red

  /// Item grading colors from the product document's grading system:
  /// A++/A+ -> green, A/B -> blue, C -> orange, D/X -> red.
  static Color gradeColor(String grade) {
    switch (grade) {
      case 'A++':
      case 'A+':
        return success;
      case 'A':
      case 'B':
        return const Color(0xFF4A6FA5);
      case 'C':
        return const Color(0xFFE08E31);
      case 'D':
      case 'X':
        return error;
      default:
        return textMuted;
    }
  }
}

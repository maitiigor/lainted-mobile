import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// Headings use Fraunces (a warm, characterful serif - a deliberate move
/// away from the product document's original DM Serif Display, which read
/// as thin/formal rather than warm), body text uses DM Sans.
class AppTextTheme {
  AppTextTheme._();

  static TextTheme get textTheme {
    // `dmSansTextTheme` applies DM Sans to every field of the theme it's
    // given, so the Fraunces display/headline/title styles below must be
    // layered on AFTER it, not before - otherwise they're silently
    // overwritten back to DM Sans.
    return GoogleFonts.dmSansTextTheme(
      TextTheme(
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.textMuted),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    ).copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.fraunces(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.fraunces(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.fraunces(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.fraunces(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

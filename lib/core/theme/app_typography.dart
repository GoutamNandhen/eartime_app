import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme get textTheme {
    return TextTheme(
      // displayXl (Manrope, 96px, 700, -0.04em) -> displayLarge
      displayLarge: GoogleFonts.manrope(
        fontSize: 96,
        fontWeight: FontWeight.w700,
        height: 100 / 96,
        letterSpacing: 96 * -0.04,
      ),
      // displayLg (Manrope, 64px, 600, -0.02em) -> displayMedium
      displayMedium: GoogleFonts.manrope(
        fontSize: 64,
        fontWeight: FontWeight.w600,
        height: 72 / 64,
        letterSpacing: 64 * -0.02,
      ),
      // headlineLg (Manrope, 32px, 500) -> headlineLarge
      headlineLarge: GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        height: 40 / 32,
      ),
      // headlineLgMobile (Manrope, 24px, 600) -> headlineMedium
      headlineMedium: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
      ),
      // bodyMd (DM Sans, 16px, 400) -> bodyLarge
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      ),
      // bodySm (DM Sans, 14px, 400) -> bodyMedium
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
      ),
      // technicalMd (JetBrains Mono, 14px, 500, 0.05em) -> labelLarge
      labelLarge: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 16 / 14,
        letterSpacing: 14 * 0.05,
      ),
      // technicalSm (JetBrains Mono, 11px, 400, 0.1em) -> labelMedium
      labelMedium: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 14 / 11,
        letterSpacing: 11 * 0.1,
      ),
    );
  }
}

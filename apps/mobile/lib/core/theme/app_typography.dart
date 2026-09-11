import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme buildTextTheme(ColorScheme colorScheme) {
  return GoogleFonts.spaceGroteskTextTheme().copyWith(
    displayLarge: GoogleFonts.spaceGrotesk(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
    ),
    headlineLarge: GoogleFonts.spaceGrotesk(
      fontSize: 32,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: GoogleFonts.spaceGrotesk(
      fontSize: 28,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: GoogleFonts.spaceGrotesk(
      fontSize: 22,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.spaceGrotesk(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
    ),
    bodyLarge:
        GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium:
        GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w400),
    labelLarge: GoogleFonts.spaceGrotesk(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  );
}

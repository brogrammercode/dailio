import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

TextTheme buildTextTheme(ColorScheme colorScheme) {
  return GoogleFonts.spaceGroteskTextTheme().copyWith(
    displayLarge: GoogleFonts.spaceGrotesk(
      fontSize: 57.r,
      fontWeight: FontWeight.w400,
      letterSpacing: (-0.25).r,
    ),
    headlineLarge: GoogleFonts.spaceGrotesk(
      fontSize: 32.r,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: GoogleFonts.spaceGrotesk(
      fontSize: 28.r,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: GoogleFonts.spaceGrotesk(
      fontSize: 22.r,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.spaceGrotesk(
      fontSize: 16.r,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15.r,
    ),
    bodyLarge:
        GoogleFonts.spaceGrotesk(fontSize: 16.r, fontWeight: FontWeight.w400),
    bodyMedium:
        GoogleFonts.spaceGrotesk(fontSize: 14.r, fontWeight: FontWeight.w400),
    labelLarge: GoogleFonts.spaceGrotesk(
      fontSize: 14.r,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1.r,
    ),
  );
}

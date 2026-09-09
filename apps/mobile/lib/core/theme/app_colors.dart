import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color seed = Color(0xFFB45309);        // warm amber-brown
  static const Color brandDark = Color(0xFF3D1F00);   // deep brown
  static const Color brandAccent = Color(0xFFB45309); // CTA buttons
  static const Color background = Color(0xFFF0F2F5);  // page bg

  // Semantic
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Status
  static const Color statusPresent = Color(0xFF22C55E);
  static const Color statusLate = Color(0xFFF59E0B);
  static const Color statusAbsent = Color(0xFFDC2626);
  static const Color statusOnLeave = Color(0xFF3B82F6);
  static const Color statusOverdue = Color(0xFFDC2626);
  static const Color statusExpiring = Color(0xFFF59E0B);
  static const Color statusActive = Color(0xFF22C55E);
}

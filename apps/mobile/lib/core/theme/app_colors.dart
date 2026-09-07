import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color seed = Color(0xFF1A56DB); // Primary brand blue
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57F17);
  static const Color info = Color(0xFF0277BD);

  // Status semantic colors
  static const Color statusPresent = Color(0xFF2E7D32);
  static const Color statusLate = Color(0xFFF57F17);
  static const Color statusAbsent = Color(0xFFD32F2F);
  static const Color statusOnLeave = Color(0xFF0277BD);
  static const Color statusOverdue = Color(0xFFD32F2F);
  static const Color statusExpiring = Color(0xFFF57F17);
  static const Color statusActive = Color(0xFF2E7D32);
}

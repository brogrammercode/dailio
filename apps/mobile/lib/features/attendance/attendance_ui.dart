import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Visual primitives for the attendance workspace.
///
/// This intentionally stays local to attendance so the existing Dailio
/// branding, typography, scale, and bottom navigation remain unchanged while
/// the attendance flow gets one calm, conversation-like visual language.
class AttendanceUi {
  AttendanceUi._();

  static const accent = AppColors.brandAccent;
  static const accentTint = Color(0xFFFFF7ED);
  static const canvas = Colors.white;
  static const text = Colors.black;
  static const muted = Color(0xFF6B6B6B);
  static const divider = Color(0xFFE7E7E7);
  static const softBlack = Color(0xFF242424);

  static BoxDecoration cardDecoration({Color color = Colors.white}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: divider),
    );
  }

  static ButtonStyle primaryButton() {
    return FilledButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  static ButtonStyle outlinedButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: text,
      side: const BorderSide(color: accent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: accent, width: 1.4),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  static Color timelineColor(String type) {
    if (type.contains('CLOCK_IN') || type.contains('CORRECTION')) {
      return accent;
    }
    return softBlack;
  }
}

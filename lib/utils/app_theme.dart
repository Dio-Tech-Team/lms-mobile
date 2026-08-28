import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single source of truth for the employee app's palette.
///
/// Before this existed, each screen declared its own private `_navy`,
/// `_navyDark`, `_hairline` etc. and they had already drifted apart:
/// Profile's "navy" was History's "navyDark", and Home carried a third
/// deep navy (0xFF0D1B3A) that no other screen used. Those are
/// reconciled here into two navies and one hairline.
class AppColors {
  AppColors._();

  /// Primary brand navy. Headings, active nav, primary icons.
  static const Color navy = Color(0xFF1B3B63);

  /// Deeper navy. Header backgrounds and the dark end of gradients.
  static const Color navyDark = Color(0xFF13224A);

  /// Action accent. Apply button, pending badges.
  static const Color amber = Color(0xFFD98F32);

  /// Quieter accent for section markers and rules.
  static const Color gold = Color(0xFFC9A24B);

  /// Secondary text.
  static const Color muted = Color(0xFF8A97A8);

  /// App background behind cards.
  static const Color bg = Color(0xFFF3F5F9);

  /// Card surfaces.
  static const Color surface = Colors.white;

  /// Card borders and dividers.
  static const Color hairline = Color(0xFFEDEFF4);

  // Status colors.
  static const Color green = Color(0xFF3A8C5C);
  static const Color red = Color(0xFFD94F70);
  static const Color teal = Color(0xFF2AABB8);

  /// Destructive actions (log out).
  static const Color danger = Color(0xFFC0394B);

  /// Rotating accents for leave-type cards and list dots.
  static const List<Color> accents = [
    Color(0xFF1E3A5F),
    Color(0xFF7B5EA7),
    Color(0xFFE07B39),
    Color(0xFF2AABB8),
    Color(0xFF3A8C5C),
    Color(0xFFD94F70),
  ];

  /// The header gradient used across Home, History and Profile.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDark, navy],
  );
}

/// Type scale. Two roles only:
///   [display] — Fraunces, for screen titles and numbers that carry weight.
///   [body]    — Nunito, for everything else.
///
/// Keeping it to two roles is what stops a third face from creeping in
/// the next time a screen gets built.
class AppText {
  AppText._();

  static TextStyle display({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.navy,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.fraunces(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle body({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.navy,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.nunito(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// All-caps section eyebrow ("WORK INFORMATION", "SEP 2026").
  static TextStyle eyebrow({double size = 11, Color color = AppColors.muted}) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 1.2,
      );
}

import 'package:flutter/material.dart';

/// Semantic color tokens for HeyOra Dual-Theme System
class AppColorScheme {
  final Color background;
  final Color surface;
  final Color surfaceCard;
  final Color textPrimary;
  final Color textSecondary;
  final Color primaryCTA;
  final Color secondaryAccent;
  final Color premiumGold;
  final Color divider;
  final Brightness brightness;

  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.surfaceCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.primaryCTA,
    required this.secondaryAccent,
    required this.premiumGold,
    required this.divider,
    required this.brightness,
  });

  bool get isDark => brightness == Brightness.dark;
}

class AppColors {
  /// Dark Theme: Premium, immersive, comfortable at night
  static const dark = AppColorScheme(
    background: Color(0xFF080811),
    surface: Color(0xFF12131D),
    surfaceCard: Color(0xFF181A26),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA1A1AA),
    primaryCTA: Color(0xFFFF553E),      // Solar Coral
    secondaryAccent: Color(0xFF8B3DFF), // Ultraviolet
    premiumGold: Color(0xFFFFD166),     // Champagne Gold
    divider: Color(0x14FFFFFF),         // #FFFFFF14
    brightness: Brightness.dark,
  );

  /// Light Theme: Clean, accessible, trustworthy during daytime
  static const light = AppColorScheme(
    background: Color(0xFFF8F9FB),
    surface: Color(0xFFFFFFFF),
    surfaceCard: Color(0xFFF1F3F7),
    textPrimary: Color(0xFF111318),
    textSecondary: Color(0xFF64748B),
    primaryCTA: Color(0xFFE94732),      // Darker Coral for light surface contrast
    secondaryAccent: Color(0xFF7040D5), // Deep Violet
    premiumGold: Color(0xFFA96800),     // Warm Amber Gold for white contrast
    divider: Color(0xFFE2E8F0),
    brightness: Brightness.light,
  );

  /// Cinema Mode: Exclusively for Video Call screens (Always Dark & Neutral)
  /// Keeps users' faces naturally lit without screen glare regardless of system theme
  static const cinema = AppColorScheme(
    background: Color(0xFF080811),
    surface: Color(0xFF12131D),
    surfaceCard: Color(0xFF181A26),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA1A1AA),
    primaryCTA: Color(0xFFFF553E),
    secondaryAccent: Color(0xFF8B3DFF),
    premiumGold: Color(0xFFFFD166),
    divider: Color(0x14FFFFFF),
    brightness: Brightness.dark,
  );

  /// Resolves the current semantic colors based on context
  static AppColorScheme of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
  }
}

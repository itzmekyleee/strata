import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Each variant defines the full palette for the current theme, including
/// surfaces, foreground text colors, hairlines and the ambient glow tint.
class VariantPalette {
  const VariantPalette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.onBackground,
    required this.onSurfaceMuted,
    required this.onSurfaceDim,
    required this.glow,
    required this.outline,
    required this.outlineStrong,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHighest;

  /// Primary foreground text on [background].
  final Color onBackground;

  /// Secondary/quiet foreground text.
  final Color onSurfaceMuted;

  /// Quietest foreground (hints, disabled).
  final Color onSurfaceDim;

  /// Tint used for the ambient radial glow behind content.
  final Color glow;

  /// Hairline borders & dividers.
  final Color outline;

  /// Slightly stronger hairline (active separators, selection borders).
  final Color outlineStrong;
}

enum ThemeVariant {
  light,
  pitchBlack,
  amoledBlack,
  midnightBlue,
  warmDark;

  String get label => switch (this) {
        light => 'Light',
        pitchBlack => 'Pitch Black',
        amoledBlack => 'AMOLED Black',
        midnightBlue => 'Midnight Blue',
        warmDark => 'Warm Dark',
      };

  String get description => switch (this) {
        light => 'Clean white, bright and clear',
        pitchBlack => 'The original Strata look',
        amoledBlack => 'True black for OLED screens',
        midnightBlue => 'Deep navy, premium feel',
        warmDark => 'Warm brown tones, cozy',
      };

  bool get isDark => this != light;

  VariantPalette get palette => switch (this) {
        light => const VariantPalette(
          background: Color(0xFFFFFFFF),
          surface: Color(0xFFF7F7F8),
          surfaceHigh: Color(0xFFFFFFFF),
          surfaceHighest: Color(0xFFEFEFF1),
          onBackground: Color(0xFF1A1A1C),
          onSurfaceMuted: Color(0xFF6C6C72),
          onSurfaceDim: Color(0xFF9A9AA0),
          glow: Color(0x0A5B5BD6),
          outline: Color(0x14000000),
          outlineStrong: Color(0x22000000),
        ),
        pitchBlack => const VariantPalette(
          background: Color(0xFF000000),
          surface: Color(0xFF0E0E0E),
          surfaceHigh: Color(0xFF181614),
          surfaceHighest: Color(0xFF22201C),
          onBackground: Color(0xFFF2EDE4),
          onSurfaceMuted: Color(0xFF8A8478),
          onSurfaceDim: Color(0xFF5B574F),
          glow: Color(0x0A6B5BD6),
          outline: Color(0x12FFFFFF),
          outlineStrong: Color(0x1FFFFFFF),
        ),
        amoledBlack => const VariantPalette(
          background: Color(0xFF000000),
          surface: Color(0xFF0A0A0A),
          surfaceHigh: Color(0xFF121212),
          surfaceHighest: Color(0xFF1C1C1C),
          onBackground: Color(0xFFF2F2F2),
          onSurfaceMuted: Color(0xFF8A8A8A),
          onSurfaceDim: Color(0xFF555555),
          glow: Color(0x0A6B5BD6),
          outline: Color(0x12FFFFFF),
          outlineStrong: Color(0x1FFFFFFF),
        ),
        midnightBlue => const VariantPalette(
          background: Color(0xFF06080E),
          surface: Color(0xFF0C1018),
          surfaceHigh: Color(0xFF141A24),
          surfaceHighest: Color(0xFF1C2430),
          onBackground: Color(0xFFE8ECF5),
          onSurfaceMuted: Color(0xFF7C879E),
          onSurfaceDim: Color(0xFF4E5666),
          glow: Color(0x107B7BF0),
          outline: Color(0x12FFFFFF),
          outlineStrong: Color(0x1FFFFFFF),
        ),
        warmDark => const VariantPalette(
          background: Color(0xFF0A0806),
          surface: Color(0xFF12100C),
          surfaceHigh: Color(0xFF1C1814),
          surfaceHighest: Color(0xFF262018),
          onBackground: Color(0xFFF0E9DE),
          onSurfaceMuted: Color(0xFF8A7F6F),
          onSurfaceDim: Color(0xFF5C5344),
          glow: Color(0x0A8A7050),
          outline: Color(0x12FFFFFF),
          outlineStrong: Color(0x1FFFFFFF),
        ),
      };
}

const _prefKey = 'strata_theme_variant';

class _ThemeVariantNotifier extends Notifier<ThemeVariant> {
  @override
  ThemeVariant build() => ThemeVariant.light;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_prefKey) ?? 0;
    state = ThemeVariant.values[index.clamp(0, ThemeVariant.values.length - 1)];
  }

  Future<void> set(ThemeVariant variant) async {
    state = variant;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, variant.index);
  }
}

final themeVariantProvider =
    NotifierProvider<_ThemeVariantNotifier, ThemeVariant>(
  _ThemeVariantNotifier.new,
);
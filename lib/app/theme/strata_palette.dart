import 'package:flutter/material.dart';

import 'theme_variant.dart';

abstract final class StrataPalette {
  static VariantPalette _variant = ThemeVariant.light.palette;

  static void applyVariant(ThemeVariant v) => _variant = v.palette;

  static Color get background => _variant.background;
  static Color get surface => _variant.surface;
  static Color get surfaceHigh => _variant.surfaceHigh;
  static Color get surfaceHighest => _variant.surfaceHighest;
  static Color get onBackground => _variant.onBackground;
  static Color get onSurfaceMuted => _variant.onSurfaceMuted;
  static Color get onSurfaceDim => _variant.onSurfaceDim;
  static Color get glow => _variant.glow;
  static Color get outline => _variant.outline;
  static Color get outlineStrong => _variant.outlineStrong;

  // Brand & semantic colors — fixed across every theme.
  static const Color accent = Color(0xFF5B5BD6);
  static const Color accentSoft = Color(0xB35B5BD6);
  static const Color mint = Color(0xFF2FB779);
  static const Color coral = Color(0xFFFF5A6A);
  static const Color amber = Color(0xFFDEA133);

  static const List<int> tagSwatches = [
    0xFFC9A24B,
    0xFF2FB779,
    0xFFFF5A6A,
    0xFFA87EF0,
    0xFF4FC3D6,
    0xFFF277B8,
    0xFFE8A94F,
    0xFF7E97F0,
  ];
}
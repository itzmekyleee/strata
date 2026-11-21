import 'package:flutter/material.dart';

import 'strata_palette.dart';

abstract final class StrataTheme {
  static ThemeData build(Brightness brightness) => brightness == Brightness.dark
      ? _build(_darkScheme())
      : _build(_lightScheme());

  static ColorScheme _lightScheme() => ColorScheme(
        brightness: Brightness.light,
        primary: StrataPalette.accent,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE6E5FA),
        onPrimaryContainer: const Color(0xFF2A2A7A),
        secondary: StrataPalette.mint,
        onSecondary: const Color(0xFF06301B),
        secondaryContainer: const Color(0xFFCBEEDD),
        onSecondaryContainer: const Color(0xFF0A3B22),
        error: StrataPalette.coral,
        onError: Colors.white,
        errorContainer: const Color(0xFFFFE0E4),
        onErrorContainer: const Color(0xFF6E0E19),
        surface: StrataPalette.surface,
        onSurface: StrataPalette.onBackground,
        onSurfaceVariant: StrataPalette.onSurfaceMuted,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF5F5F7),
        surfaceContainer: StrataPalette.surface,
        surfaceContainerHigh: StrataPalette.surfaceHigh,
        surfaceContainerHighest: StrataPalette.surfaceHighest,
        outline: StrataPalette.outlineStrong,
        outlineVariant: StrataPalette.outline,
        shadow: const Color(0x33000000),
        scrim: const Color(0x40000000),
        inverseSurface: const Color(0xFF2B2923),
        onInverseSurface: const Color(0xFFF5F4F1),
        inversePrimary: const Color(0xFFBDBDF8),
        surfaceTint: StrataPalette.accent,
      );

  static ColorScheme _darkScheme() => ColorScheme(
        brightness: Brightness.dark,
        primary: StrataPalette.accent,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF3E3E9C),
        onPrimaryContainer: const Color(0xFFE6E5FA),
        secondary: StrataPalette.mint,
        onSecondary: const Color(0xFF06301B),
        secondaryContainer: const Color(0xFF14593A),
        onSecondaryContainer: const Color(0xFFCBEEDD),
        error: StrataPalette.coral,
        onError: Colors.white,
        errorContainer: const Color(0xFF57212A),
        onErrorContainer: const Color(0xFFFFE0E4),
        surface: StrataPalette.surface,
        onSurface: StrataPalette.onBackground,
        onSurfaceVariant: StrataPalette.onSurfaceMuted,
        surfaceContainerLowest: const Color(0xFF060606),
        surfaceContainerLow: StrataPalette.surface,
        surfaceContainer: StrataPalette.surfaceHigh,
        surfaceContainerHigh: StrataPalette.surfaceHighest,
        surfaceContainerHighest: StrataPalette.surfaceHighest,
        outline: StrataPalette.outlineStrong,
        outlineVariant: StrataPalette.outline,
        shadow: const Color(0xCC000000),
        scrim: const Color(0x99000000),
        inverseSurface: const Color(0xFFF0EDE4),
        onInverseSurface: const Color(0xFF1D1B16),
        inversePrimary: StrataPalette.accent,
        surfaceTint: StrataPalette.accent,
      );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: StrataPalette.background,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: _textTheme(base),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
          color: StrataPalette.onBackground,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: StrataPalette.surface.withValues(alpha: .9),
        indicatorColor: StrataPalette.accent.withValues(alpha: .16),
        height: 64,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: StrataPalette.onSurfaceMuted,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: StrataPalette.onSurfaceMuted),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: StrataPalette.background,
        indicatorColor: StrataPalette.accent.withValues(alpha: .14),
        selectedIconTheme: const IconThemeData(color: StrataPalette.accent),
        unselectedIconTheme: IconThemeData(
          color: StrataPalette.onSurfaceMuted,
        ),
        selectedLabelTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: StrataPalette.accent,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: StrataPalette.onSurfaceMuted,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: StrataPalette.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: StrataPalette.onSurfaceDim.withValues(
            alpha: .25,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          minimumSize: const Size(48, 46),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: StrataPalette.onBackground,
          side: BorderSide(color: StrataPalette.outlineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(48, 46),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: StrataPalette.accent,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: StrataPalette.onBackground,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StrataPalette.surfaceHigh.withValues(alpha: .7),
        hintStyle: TextStyle(color: StrataPalette.onSurfaceMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: StrataPalette.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: StrataPalette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StrataPalette.accent, width: 1.4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: StrataPalette.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: .35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: StrataPalette.onBackground,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: StrataPalette.surfaceHigh,
        modalBackgroundColor: StrataPalette.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: StrataPalette.onSurfaceMuted.withValues(alpha: .4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: StrataPalette.surfaceHighest,
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          color: StrataPalette.onBackground,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: StrataPalette.outline,
      dividerTheme: DividerThemeData(
        color: StrataPalette.outline,
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: StrataPalette.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: .35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: StrataPalette.outline),
        ),
        textStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: StrataPalette.onBackground,
        ),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: StrataPalette.surfaceHigh,
        selectedColor: StrataPalette.accent.withValues(alpha: .2),
        side: BorderSide(color: StrataPalette.outline),
        labelStyle: TextStyle(color: StrataPalette.onBackground),
        secondaryLabelStyle: TextStyle(color: StrataPalette.onSurfaceMuted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : StrataPalette.onSurfaceDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? StrataPalette.accent
              : StrataPalette.surfaceHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: StrataPalette.accent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: StrataPalette.surfaceHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: StrataPalette.onBackground),
      ),
    );
  }

  static TextTheme _textTheme(ThemeData base) {
    final display = base.textTheme.apply(
      bodyColor: StrataPalette.onBackground,
      displayColor: StrataPalette.onBackground,
      fontFamily: 'Inter',
    );
    return display.copyWith(
      displaySmall: display.displaySmall?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -.6,
        height: 1.15,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -.5,
        height: 1.2,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -.4,
        height: 1.2,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -.3,
        height: 1.25,
      ),
      titleLarge: display.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -.2,
        height: 1.3,
      ),
      titleMedium: display.titleMedium?.copyWith(
        fontSize: 16.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -.1,
        height: 1.3,
      ),
      titleSmall: display.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      bodyLarge: display.bodyLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: display.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodySmall: display.bodySmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: StrataPalette.onSurfaceMuted,
      ),
      labelLarge: display.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: display.labelMedium?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: display.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: .3,
        color: StrataPalette.onSurfaceMuted,
      ),
    );
  }
}
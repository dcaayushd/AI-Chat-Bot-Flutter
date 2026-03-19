import 'package:flutter/material.dart';

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF1B6664),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFBFE0DE),
  onPrimaryContainer: Color(0xFF163D3C),
  secondary: Color(0xFF4E7690),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFD6E9F2),
  onSecondaryContainer: Color(0xFF203844),
  tertiary: Color(0xFF6A8472),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFD6E3DA),
  onTertiaryContainer: Color(0xFF26382E),
  error: Color(0xFFBA1A1A),
  onError: Colors.white,
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface: Color(0xFFE7EEF2),
  onSurface: Color(0xFF1A242A),
  surfaceContainerLowest: Color(0xFFF4F8FA),
  surfaceContainerLow: Color(0xFFEDF4F7),
  surfaceContainer: Color(0xFFE2EAEE),
  surfaceContainerHigh: Color(0xFFD7E2E8),
  surfaceContainerHighest: Color(0xFFCBD8E0),
  onSurfaceVariant: Color(0xFF576973),
  outline: Color(0xFF7F919B),
  outlineVariant: Color(0xFFC9D6DE),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFF213139),
  onInverseSurface: Color(0xFFEEF5F7),
  inversePrimary: Color(0xFF8ECFCD),
  surfaceTint: Color(0xFF1B6664),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF9DB6FF),
  onPrimary: Color(0xFF172C69),
  primaryContainer: Color(0xFF3B4E95),
  onPrimaryContainer: Color(0xFFE6EBFF),
  secondary: Color(0xFF93C8C6),
  onSecondary: Color(0xFF143734),
  secondaryContainer: Color(0xFF214846),
  onSecondaryContainer: Color(0xFFD6E9E8),
  tertiary: Color(0xFFB4D0BC),
  onTertiary: Color(0xFF24382D),
  tertiaryContainer: Color(0xFF355146),
  onTertiaryContainer: Color(0xFFD7E6DC),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF0D1620),
  onSurface: Color(0xFFEAF2F8),
  surfaceContainerLowest: Color(0xFF081019),
  surfaceContainerLow: Color(0xFF101B25),
  surfaceContainer: Color(0xFF15222C),
  surfaceContainerHigh: Color(0xFF1D2B36),
  surfaceContainerHighest: Color(0xFF243540),
  onSurfaceVariant: Color(0xFFA3B3C2),
  outline: Color(0xFF738493),
  outlineVariant: Color(0xFF30414D),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFFEAF2F8),
  onInverseSurface: Color(0xFF1C2730),
  inversePrimary: Color(0xFF4259A8),
  surfaceTint: Color(0xFF9DB6FF),
);

ThemeData _buildTheme(ColorScheme colorScheme) {
  final textTheme = ThemeData(brightness: colorScheme.brightness).textTheme;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: colorScheme.brightness,
  );

  return base.copyWith(
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        height: 1.35,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLow.withValues(
        alpha: colorScheme.brightness == Brightness.dark ? 0.78 : 0.86,
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      side:
          BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.7)),
      labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      backgroundColor: colorScheme.surfaceContainer,
      selectedColor: colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow.withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 1.15,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      space: 1,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(
        colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
    ),
  );
}

ThemeData lightTheme = _buildTheme(_lightScheme);

ThemeData darkTheme = _buildTheme(_darkScheme);

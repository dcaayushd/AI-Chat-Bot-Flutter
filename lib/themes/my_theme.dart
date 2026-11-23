import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF275F53),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFDDEFE6),
  onPrimaryContainer: Color(0xFF163D32),
  secondary: Color(0xFF526B7D),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFE1EAF2),
  onSecondaryContainer: Color(0xFF253D4B),
  tertiary: Color(0xFF865A3B),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFF4E1D0),
  onTertiaryContainer: Color(0xFF492B17),
  error: Color(0xFFBA1A1A),
  onError: Colors.white,
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface: Color(0xFFF8F7F3),
  onSurface: Color(0xFF202823),
  surfaceContainerLowest: Color(0xFFFFFEFB),
  surfaceContainerLow: Color(0xFFF0EFE9),
  surfaceContainer: Color(0xFFEAE9E2),
  surfaceContainerHigh: Color(0xFFE2E4DB),
  surfaceContainerHighest: Color(0xFFD7DBD2),
  onSurfaceVariant: Color(0xFF535E56),
  outline: Color(0xFF76837A),
  outlineVariant: Color(0xFFD4DBD2),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFF26352D),
  onInverseSurface: Color(0xFFF0F6F1),
  inversePrimary: Color(0xFFA6D7C3),
  surfaceTint: Color(0xFF275F53),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFA6D7C3),
  onPrimary: Color(0xFF103C32),
  primaryContainer: Color(0xFF234D41),
  onPrimaryContainer: Color(0xFFDFEFE6),
  secondary: Color(0xFFABCADE),
  onSecondary: Color(0xFF203B4D),
  secondaryContainer: Color(0xFF314A5B),
  onSecondaryContainer: Color(0xFFDEEBF4),
  tertiary: Color(0xFFE5B996),
  onTertiary: Color(0xFF492B17),
  tertiaryContainer: Color(0xFF60402A),
  onTertiaryContainer: Color(0xFFF5E1D3),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF131A17),
  onSurface: Color(0xFFECF1ED),
  surfaceContainerLowest: Color(0xFF101613),
  surfaceContainerLow: Color(0xFF19211D),
  surfaceContainer: Color(0xFF202B25),
  surfaceContainerHigh: Color(0xFF29362F),
  surfaceContainerHighest: Color(0xFF34423A),
  onSurfaceVariant: Color(0xFFADBDB3),
  outline: Color(0xFF829589),
  outlineVariant: Color(0xFF36473E),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFFECF1ED),
  onInverseSurface: Color(0xFF26352D),
  inversePrimary: Color(0xFF275F53),
  surfaceTint: Color(0xFFA6D7C3),
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
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.35),
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
      side: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.7),
      ),
      labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      backgroundColor: colorScheme.surfaceContainer,
      selectedColor: colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLowest,
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
        borderSide: BorderSide(color: colorScheme.primary, width: 1.15),
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

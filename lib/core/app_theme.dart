import 'package:flutter/material.dart';

/// Flat by construction: no elevation, no shadow, no ripple, one hairline
/// rule as the only separator. Colours travel through [ColorScheme] so
/// widgets stay idiomatic.
abstract final class AppTheme {
  static const textFamily = 'CupertinoSystemText';
  static const displayFamily = 'CupertinoSystemDisplay';

  static ThemeData light() => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF000000),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF8A8A8E),
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFD7263D),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0B0B0C),
      onSurfaceVariant: Color(0xFF8A8A8E),
      outlineVariant: Color(0xFFE6E6E9),
      surfaceContainerHighest: Color(0xFFF3F3F5),
    ),
  );

  static ThemeData dark() => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFF8A8A8E),
      onSecondary: Color(0xFF000000),
      error: Color(0xFFFF6B7A),
      onError: Color(0xFF000000),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFF5F5F7),
      onSurfaceVariant: Color(0xFF8A8A8E),
      outlineVariant: Color(0xFF2C2C31),
      surfaceContainerHighest: Color(0xFF131315),
    ),
  );

  static ThemeData _build(ColorScheme scheme) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: textFamily,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.5,
      space: 0.5,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    ),
  );
}

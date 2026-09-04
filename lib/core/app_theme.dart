import 'package:flutter/material.dart';

/// The looks a person can pick from. Each one carries a light and a dark
/// palette, and the system decides which of the two is showing.
enum AppThemeChoice {
  ink('Ink'),
  ocean('Ocean'),
  forest('Forest'),
  blossom('Blossom');

  const AppThemeChoice(this.label);

  /// What the settings screen calls it.
  final String label;

  /// The look the app ships in, and the one it falls back to.
  static const fallback = AppThemeChoice.blossom;

  /// The choice written under this name, or [fallback] for a name it does
  /// not know, so a stale or missing setting never leaves the app without a
  /// look.
  static AppThemeChoice fromName(String? name) => values.firstWhere(
    (choice) => choice.name == name,
    orElse: () => fallback,
  );
}

/// Flat by construction: no elevation, no shadow, no ripple, one hairline
/// rule as the only separator. Colours travel through [ColorScheme] so
/// widgets stay idiomatic.
abstract final class AppTheme {
  static const textFamily = 'CupertinoSystemText';
  static const displayFamily = 'CupertinoSystemDisplay';

  static ThemeData light(AppThemeChoice choice) =>
      _build(schemeFor(choice, Brightness.light));

  static ThemeData dark(AppThemeChoice choice) =>
      _build(schemeFor(choice, Brightness.dark));

  /// Every colour in the app, by look and by brightness. Nothing else defines
  /// one.
  static ColorScheme schemeFor(AppThemeChoice choice, Brightness brightness) =>
      switch ((choice, brightness)) {
        (AppThemeChoice.ink, Brightness.light) => const ColorScheme(
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
        (AppThemeChoice.ink, Brightness.dark) => const ColorScheme(
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
        (AppThemeChoice.ocean, Brightness.light) => const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF1F5FBF),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF6B7A90),
          onSecondary: Color(0xFFFFFFFF),
          error: Color(0xFFD7263D),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFF4F7FB),
          onSurface: Color(0xFF0E1B2E),
          onSurfaceVariant: Color(0xFF6B7A90),
          outlineVariant: Color(0xFFD3DCE8),
          surfaceContainerHighest: Color(0xFFE6EDF6),
        ),
        (AppThemeChoice.ocean, Brightness.dark) => const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF7FB2FF),
          onPrimary: Color(0xFF06152B),
          secondary: Color(0xFF8A9AB4),
          onSecondary: Color(0xFF06152B),
          error: Color(0xFFFF6B7A),
          onError: Color(0xFF000000),
          surface: Color(0xFF0A1220),
          onSurface: Color(0xFFE8EEF8),
          onSurfaceVariant: Color(0xFF8A9AB4),
          outlineVariant: Color(0xFF22304A),
          surfaceContainerHighest: Color(0xFF131E31),
        ),
        (AppThemeChoice.forest, Brightness.light) => const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF2E6B3F),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF6F7F6A),
          onSecondary: Color(0xFFFFFFFF),
          error: Color(0xFFD7263D),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFF5F8F3),
          onSurface: Color(0xFF10200F),
          onSurfaceVariant: Color(0xFF6F7F6A),
          outlineVariant: Color(0xFFD5E0CF),
          surfaceContainerHighest: Color(0xFFE7EFE2),
        ),
        (AppThemeChoice.forest, Brightness.dark) => const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF8CD19A),
          onPrimary: Color(0xFF07150A),
          secondary: Color(0xFF8FA089),
          onSecondary: Color(0xFF07150A),
          error: Color(0xFFFF6B7A),
          onError: Color(0xFF000000),
          surface: Color(0xFF0B140C),
          onSurface: Color(0xFFE9F2E6),
          onSurfaceVariant: Color(0xFF8FA089),
          outlineVariant: Color(0xFF243527),
          surfaceContainerHighest: Color(0xFF142016),
        ),
        (AppThemeChoice.blossom, Brightness.light) => const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFFC2427A),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF8E6F7C),
          onSecondary: Color(0xFFFFFFFF),
          error: Color(0xFFD7263D),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFFCF5F8),
          onSurface: Color(0xFF2A101B),
          onSurfaceVariant: Color(0xFF8E6F7C),
          outlineVariant: Color(0xFFEBD5DF),
          surfaceContainerHighest: Color(0xFFF6E6ED),
        ),
        (AppThemeChoice.blossom, Brightness.dark) => const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFF49AC1),
          onPrimary: Color(0xFF2A0A19),
          secondary: Color(0xFFA88A97),
          onSecondary: Color(0xFF2A0A19),
          error: Color(0xFFFF6B7A),
          onError: Color(0xFF000000),
          surface: Color(0xFF170A11),
          onSurface: Color(0xFFF8EAF0),
          onSurfaceVariant: Color(0xFFA88A97),
          outlineVariant: Color(0xFF3A2430),
          surfaceContainerHighest: Color(0xFF231219),
        ),
      };

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

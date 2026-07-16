import 'package:flutter/material.dart';

/// Theme-aware semantic feedback colors that Material's [ColorScheme] does not
/// provide out of the box. [ColorScheme.error] already covers error states, so
/// only success and warning need their own tokens here.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;

  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
  });

  static const AppSemanticColors light = AppSemanticColors(
    success: Color(0xFF2E7D32),
    onSuccess: Colors.white,
    warning: Color(0xFFE65100),
    onWarning: Colors.white,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF81C784),
    onSuccess: Colors.black,
    warning: Color(0xFFFFB74D),
    onWarning: Colors.black,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    );
  }
}

/// Ergonomic access to the app's semantic colors from any [BuildContext].
extension AppThemeContext on BuildContext {
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;

  /// Monospace text style for fixed-width data (hashes, byte counts, etc.).
  TextStyle get monospace =>
      (Theme.of(this).textTheme.bodyMedium ?? const TextStyle())
          .copyWith(fontFamily: 'IBM Plex Mono');
}

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light, null, Colors.blueAccent);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark, null, Colors.blueAccent);

  static ThemeData buildThemeWithColor(Brightness brightness, ColorScheme? colorScheme, Color seedColor) {
    return _buildTheme(brightness, colorScheme, seedColor);
  }

  static ThemeData _buildTheme(Brightness brightness, ColorScheme? scheme, Color seedColor) {
    final baseScheme = scheme ?? ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    final baseTextTheme = ThemeData(brightness: brightness, colorScheme: baseScheme).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: baseScheme,
      fontFamily: 'IBM Plex Sans',
      textTheme: baseTextTheme.apply(fontFamily: 'IBM Plex Sans'),
      extensions: [
        brightness == Brightness.dark
            ? AppSemanticColors.dark
            : AppSemanticColors.light,
      ],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

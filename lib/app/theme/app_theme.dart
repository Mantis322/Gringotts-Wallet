import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';

/// Premium Stellar Wallet Theme System
/// Material 3 Design with Custom Stellar Branding
class AppTheme {
  AppTheme._();
  
  // Base Color Schemes
  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryPurple,
    onPrimary: AppColors.textPrimary,
    secondary: AppColors.secondaryBlue,
    onSecondary: AppColors.textPrimary,
    tertiary: AppColors.secondaryTeal,
    onTertiary: AppColors.textPrimary,
    error: AppColors.errorRed,
    onError: AppColors.textPrimary,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceCard,
    outline: AppColors.borderMedium,
    outlineVariant: AppColors.borderLight,
  );
  
  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primaryPurple,
    onPrimary: AppColors.textPrimary,
    secondary: AppColors.secondaryBlue,
    onSecondary: AppColors.textPrimary,
    tertiary: AppColors.secondaryTeal,
    onTertiary: AppColors.textPrimary,
    error: AppColors.errorRed,
    onError: AppColors.textPrimary,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.textDark,
    surfaceContainerHighest: Colors.white,
    outline: AppColors.borderMedium,
    outlineVariant: AppColors.borderLight,
  );
  
  // Typography - Premium & Modern
  static const String _fontFamily = 'SF Pro Display';
  
  static TextTheme get _textTheme => const TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w300,
      letterSpacing: -0.25,
      height: 1.12,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w300,
      letterSpacing: 0,
      height: 1.16,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.22,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.29,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.33,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.27,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      height: 1.50,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.10,
      height: 1.43,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      height: 1.50,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.43,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.40,
      height: 1.33,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.10,
      height: 1.43,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.50,
      height: 1.33,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.50,
      height: 1.45,
    ),
  );

  // Premium Button Styles
  static ButtonStyle get _elevatedButtonStyle => ElevatedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    backgroundColor: AppColors.primaryPurple,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    minimumSize: const Size(double.infinity, 56),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
  
  static ButtonStyle get _outlinedButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.primaryPurple,
    side: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    minimumSize: const Size(double.infinity, 56),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
  
  static ButtonStyle get _textButtonStyle => TextButton.styleFrom(
    foregroundColor: AppColors.primaryPurple,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.25,
    ),
  );

  // Card Styles
  static CardThemeData get _cardTheme => CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    clipBehavior: Clip.antiAlias,
    color: AppColors.surfaceCard,
  );

  // Input Decoration
  static InputDecorationTheme get _inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceCard,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.errorRed),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.errorRed, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    hintStyle: const TextStyle(color: AppColors.textTertiary),
    labelStyle: const TextStyle(color: AppColors.textSecondary),
  );

  // AppBar Theme
  static AppBarTheme get _appBarTheme => const AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.textPrimary,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      letterSpacing: 0.15,
    ),
    iconTheme: IconThemeData(color: AppColors.textPrimary),
    actionsIconTheme: IconThemeData(color: AppColors.textPrimary),
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.primaryDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Bottom Navigation Theme
  static BottomNavigationBarThemeData get _bottomNavTheme => const BottomNavigationBarThemeData(
    backgroundColor: AppColors.surfaceCard,
    selectedItemColor: AppColors.primaryPurple,
    unselectedItemColor: AppColors.textTertiary,
    elevation: 0,
    type: BottomNavigationBarType.fixed,
    selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  );

  // FloatingActionButton Theme
  static FloatingActionButtonThemeData get _fabTheme => FloatingActionButtonThemeData(
    backgroundColor: AppColors.primaryPurple,
    foregroundColor: AppColors.textPrimary,
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );

  // Main Theme Data
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: _darkColorScheme,
    textTheme: _textTheme,
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: AppColors.primaryDark,
    appBarTheme: _appBarTheme,
    cardTheme: _cardTheme,
    elevatedButtonTheme: ElevatedButtonThemeData(style: _elevatedButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedButtonStyle),
    textButtonTheme: TextButtonThemeData(style: _textButtonStyle),
    inputDecorationTheme: _inputDecorationTheme,
    bottomNavigationBarTheme: _bottomNavTheme,
    floatingActionButtonTheme: _fabTheme,
    dividerTheme: const DividerThemeData(
      color: AppColors.borderLight,
      thickness: 1,
      space: 24,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceCard,
      selectedColor: AppColors.primaryPurple,
      disabledColor: AppColors.textTertiary,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      side: const BorderSide(color: AppColors.borderLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryPurple,
      linearTrackColor: AppColors.surfaceCard,
      circularTrackColor: AppColors.surfaceCard,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryPurple;
        }
        return AppColors.textTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryPurple.withOpacity(0.3);
        }
        return AppColors.surfaceCard;
      }),
    ),
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    textTheme: _textTheme.apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    ),
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: AppColors.surfaceLight,
    appBarTheme: _appBarTheme.copyWith(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textDark,
      titleTextStyle: _appBarTheme.titleTextStyle?.copyWith(
        color: AppColors.textDark,
      ),
      iconTheme: const IconThemeData(color: AppColors.textDark),
      actionsIconTheme: const IconThemeData(color: AppColors.textDark),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.surfaceLight,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    cardTheme: _cardTheme.copyWith(color: Colors.white),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _elevatedButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedButtonStyle),
    textButtonTheme: TextButtonThemeData(style: _textButtonStyle),
    inputDecorationTheme: _inputDecorationTheme.copyWith(
      fillColor: Colors.white,
      hintStyle: TextStyle(color: AppColors.textDark.withOpacity(0.6)),
      labelStyle: TextStyle(color: AppColors.textDark.withOpacity(0.8)),
    ),
    bottomNavigationBarTheme: _bottomNavTheme.copyWith(
      backgroundColor: Colors.white,
      unselectedItemColor: AppColors.textDark.withOpacity(0.6),
    ),
    floatingActionButtonTheme: _fabTheme,
    dividerTheme: DividerThemeData(
      color: AppColors.textDark.withOpacity(0.12),
      thickness: 1,
      space: 24,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.primaryPurple,
      disabledColor: AppColors.textDark.withOpacity(0.38),
      labelStyle: TextStyle(color: AppColors.textDark.withOpacity(0.87)),
      side: BorderSide(color: AppColors.textDark.withOpacity(0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryPurple,
      linearTrackColor: Colors.white,
      circularTrackColor: Colors.white,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryPurple;
        }
        return AppColors.textDark.withOpacity(0.38);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryPurple.withOpacity(0.3);
        }
        return AppColors.textDark.withOpacity(0.12);
      }),
    ),
  );
}
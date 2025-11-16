import 'package:flutter/material.dart';

/// Application color palette for Gringotts Wallet
/// Inspired by magical themes with premium glass morphism effects
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFFD4AF37); // Golden
  static const Color primaryLight = Color(0xFFE6C866);
  static const Color primaryDark = Color(0xFFB8941F);
  static const Color primaryPurple = Color(0xFF6C63FF); // For compatibility
  
  // Background colors
  static const Color background = Color(0xFF0F0F23);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceVariant = Color(0xFF2D2D44);
  static const Color surfaceCard = Color(0xFF1F1F35);
  static const Color surfaceElevated = Color(0xFF252540);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFBBBBBB);
  static const Color textTertiary = Color(0xFF888888);
  
  // Border and divider colors
  static const Color border = Color(0xFF333355);
  static const Color borderLight = Color(0xFF444466);
  static const Color borderMedium = Color(0xFF555577);
  static const Color divider = Color(0xFF2A2A40);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successGreen = Color(0xFF4CAF50); // Alias
  static const Color warning = Color(0xFFFF9800);
  static const Color warningOrange = Color(0xFFFF9800); // Alias
  static const Color error = Color(0xFFFF5252);
  static const Color errorRed = Color(0xFFFF5252); // Alias
  static const Color info = Color(0xFF2196F3);
  static const Color secondaryBlue = Color(0xFF2196F3); // Alias
  
  // Card and container colors
  static const Color cardBackground = Color(0xFF1F1F35);
  static const Color inputBackground = Color(0xFF252540);
  
  // Shadow colors
  static Color shadowMedium = Colors.black.withOpacity(0.3);
  
  // Additional colors for compatibility
  static const Color accentGold = Color(0xFFFFD700);
  static const Color secondary = Color(0xFF2196F3); // Blue secondary
  static const Color accent = Color(0xFFFFD700); // Gold accent
  
  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [info, primaryPurple],
  );
  
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentGold, primary],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, surface],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A2E),
      Color(0xFF16213E),
    ],
  );
  
  // Glass morphism effect
  static Color get glassBackground => Colors.white.withOpacity(0.1);
  static Color get glassLight => Colors.white.withOpacity(0.1);
  static Color get glassBorder => Colors.white.withOpacity(0.2);
  
  // Wallet specific colors
  static const Color balancePositive = success;
  static const Color balanceNegative = error;
  static const Color transactionIncoming = success;
  static const Color transactionOutgoing = warning;
  
  // Button colors
  static const Color buttonPrimary = primary;
  static const Color buttonSecondary = surface;
  static const Color buttonDisabled = Color(0xFF444444);
  
  // Overlay colors
  static Color get overlay => Colors.black.withOpacity(0.5);
  static Color get modalBackground => background.withOpacity(0.95);
}
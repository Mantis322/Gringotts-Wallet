import 'package:flutter/material.dart';

/// App Color Palette - Premium Stellar Wallet Design
/// Inspired by Phantom, Apple Wallet & Revolut
class AppColors {
  AppColors._();

  // Primary Brand Colors - Deep Space Navy & Stellar Purple
  static const Color primaryDark = Color(0xFF0A0E27);
  static const Color primaryNavy = Color(0xFF1A1B3A);
  static const Color primaryPurple = Color(0xFF6366F1);
  static const Color primaryViolet = Color(0xFF8B5CF6);
  
  // Secondary Colors - Electric Blue & Stellar Glow
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color secondaryTeal = Color(0xFF06B6D4);
  static const Color secondaryCyan = Color(0xFF22D3EE);
  
  // Accent Colors - Gold & Success
  static const Color accentGold = Color(0xFFFBBF24);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF97316);
  static const Color warningYellow = Color(0xFFFBBF24);
  static const Color errorRed = Color(0xFFEF4444);
  
  // Background Colors
  static const Color backgroundDark = primaryDark;
  
  // Neutral Colors - Premium Glass & Shadows
  static const Color surfaceDark = Color(0xFF111827);
  static const Color surfaceCard = Color(0xFF1F2937);
  static const Color surfaceElevated = Color(0xFF374151);
  static const Color surfaceLight = Color(0xFFF9FAFB);
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFD1D5DB);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textDark = Color(0xFF111827);
  
  // Glass Effect Colors
  static const Color glassLight = Color(0x1AFFFFFF);
  static const Color glassMedium = Color(0x2DFFFFFF);
  static const Color glassDark = Color(0x0D000000);
  
  // Gradient Collections
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryPurple,
      primaryViolet,
    ],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      primaryDark,
      primaryNavy,
    ],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      surfaceCard,
      surfaceElevated,
    ],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      secondaryBlue,
      secondaryTeal,
    ],
  );
  
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accentGold,
      accentAmber,
    ],
  );
  
  // Shadow Colors
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color shadowHeavy = Color(0x4D000000);
  
  // Border Colors
  static const Color borderLight = Color(0x1AFFFFFF);
  static const Color borderMedium = Color(0x33FFFFFF);
  static const Color borderAccent = primaryPurple;
}
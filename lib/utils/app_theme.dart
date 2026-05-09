import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized color palette extracted from the reference design.
class AppColors {
  AppColors._();

  // Core backgrounds
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceLight = Color(0xFF1E293B);
  static const Color surfaceBorder = Color(0xFF1E293B);

  // Accents
  static const Color primary = Color(0xFF06B6D4); // Cyan/teal
  static const Color primaryDark = Color(0xFF0891B2);
  static const Color primaryGlow = Color(0x3306B6D4); // Cyan with opacity
  static const Color accent = Color(0xFF8B5CF6); // Purple accent

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Brand icon colors
  static const Color amazonOrange = Color(0xFFFF9900);
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color netflixRed = Color(0xFFE50914);
  static const Color gmailRed = Color(0xFFEA4335);
  static const Color twitterBlue = Color(0xFF1DA1F2);
  static const Color facebookBlue = Color(0xFF1877F2);
  static const Color githubDark = Color(0xFF333333);
  static const Color spotifyGreen = Color(0xFF1DB954);
  static const Color discordPurple = Color(0xFF5865F2);
  static const Color linkedinBlue = Color(0xFF0A66C2);
  static const Color appleSilver = Color(0xFFA2AAAD);
  static const Color microsoftBlue = Color(0xFF00A4EF);
  static const Color redditOrange = Color(0xFFFF4500);
  static const Color youtubeRed = Color(0xFFFF0000);
  static const Color slackPurple = Color(0xFF4A154B);
  static const Color instagramPink = Color(0xFFE1306C);

  // Gradient
  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Centralized text styles.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get heading1 => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: 2.0,
      );

  static TextStyle get heading2 => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 1.5,
      );

  static TextStyle get heading3 => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
        letterSpacing: 1.0,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );
}

/// Reusable decoration builders.
class AppDecorations {
  AppDecorations._();

  /// Standard glassmorphism card.
  static BoxDecoration get card => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder, width: 1),
      );

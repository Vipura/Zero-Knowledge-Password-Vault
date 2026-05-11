import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppIconMapper {
  static const Map<String, IconData> _iconMap = {
    'google': Icons.g_mobiledata,
    'facebook': Icons.facebook,
    'apple': Icons.apple,
    'amazon': Icons.shopping_cart,
    'twitter': Icons.alternate_email,
    'x': Icons.close,
    'instagram': Icons.camera_alt,
    'linkedin': Icons.work,
    'github': Icons.code,
    'microsoft': Icons.window,
    'netflix': Icons.movie,
    'spotify': Icons.play_circle_filled,
    'youtube': Icons.play_arrow,
    'reddit': Icons.forum,
    'discord': Icons.headset_mic,
    'slack': Icons.tag,
    'gmail': Icons.mail,
  };

  static const Map<String, Color> _brandColors = {
    'google': AppColors.googleBlue,
    'facebook': AppColors.facebookBlue,
    'apple': AppColors.appleSilver,
    'amazon': AppColors.amazonOrange,
    'twitter': AppColors.twitterBlue,
    'x': AppColors.textPrimary,
    'instagram': AppColors.instagramPink,
    'linkedin': AppColors.linkedinBlue,
    'github': AppColors.githubDark,
    'microsoft': AppColors.microsoftBlue,
    'netflix': AppColors.netflixRed,
    'spotify': AppColors.spotifyGreen,
    'youtube': AppColors.youtubeRed,
    'reddit': AppColors.redditOrange,
    'discord': AppColors.discordPurple,
    'slack': AppColors.slackPurple,
    'gmail': AppColors.gmailRed,

  static IconData getIconFor(String title) {
    final lower = title.toLowerCase().trim();
    for (final key in _iconMap.keys) {
      if (lower.contains(key)) return _iconMap[key]!;
    }
    return Icons.vpn_key;
  }
}

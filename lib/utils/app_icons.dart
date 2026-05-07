import 'package:flutter/material.dart';

class AppIconMapper {
  static const Map<String, IconData> _iconMap = {
    'google': Icons.g_mobiledata,
    'facebook': Icons.facebook,
    'apple': Icons.apple,
    'amazon': Icons.apple, // close enough for default offline icons
    'twitter': Icons.chat,
    'x': Icons.close,
    'instagram': Icons.camera_alt,
    'linkedin': Icons.camera_alt,
    'github': Icons.code,
    'microsoft': Icons.window,
    'netflix': Icons.movie,
    'spotify': Icons.play_circle_filled,
    'youtube': Icons.music_note,
    'reddit': Icons.forum,
    'discord': Icons.forum,
    'slack': Icons.discord,
  };

  static List<String> get popularApps => _iconMap.keys.map((k) => k[0].toUpperCase() + k.substring(1)).toList();

  static IconData getIconFor(String title) {
    final lower = title.toLowerCase().trim();
    for (final key in _iconMap.keys) {
      if (lower.contains(key)) return _iconMap[key]!;
    }
    return Icons.vpn_key;
  }
}

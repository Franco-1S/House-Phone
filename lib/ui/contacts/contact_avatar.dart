import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Runder Verlaufs-Avatar mit Initialen. Die Farbe ergibt sich stabil aus
/// dem Namen – jeder Kontakt behält "seine" Farbe.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    super.key,
    required this.name,
    required this.initials,
    this.size = 44,
    this.glow = false,
  });

  final String name;
  final String initials;
  final double size;
  final bool glow;

  static const _palettes = [
    [AppColors.violet, AppColors.cyan],
    [AppColors.pink, AppColors.violet],
    [AppColors.green, AppColors.cyan],
    [AppColors.amber, AppColors.pink],
    [AppColors.cyan, Color(0xFF3B5BFF)],
    [Color(0xFFFF7A59), AppColors.amber],
  ];

  static List<Color> colorsFor(String name) {
    var h = 0;
    for (final c in name.toLowerCase().codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palettes[h % _palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.5),
                  blurRadius: size * 0.5,
                ),
              ]
            : const [],
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

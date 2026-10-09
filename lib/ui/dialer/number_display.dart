import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Zeigt die gewählte Nummer. Jede neue Ziffer "ploppt" federnd herein,
/// die Schrift schrumpft bei langen Nummern automatisch.
/// [shake] erhöhen → kurzes Wackeln (z. B. beim Löschen).
class NumberDisplay extends StatelessWidget {
  const NumberDisplay({
    super.key,
    required this.number,
    this.placeholder = '',
    this.shake = 0,
  });

  final String number;
  final String placeholder;
  final int shake;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(shake),
        tween: Tween(begin: shake == 0 ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 520),
        builder: (context, v, child) => Transform.translate(
          offset: Offset(math.sin(v * math.pi * 6) * 14 * (1 - v), 0),
          child: child,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: number.isEmpty
              ? Center(
                  key: const ValueKey('placeholder'),
                  child: Text(
                    placeholder,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textFaint,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              : FittedBox(
                  key: const ValueKey('number'),
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < number.length; i++)
                          _PopChar(
                            key: ValueKey('$i:${number[i]}'),
                            char: number[i],
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PopChar extends StatelessWidget {
  const _PopChar({super.key, required this.char});
  final String char;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutBack,
      builder: (context, v, child) {
        final o = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: o,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - v)),
            child: Transform.scale(scale: 0.4 + 0.6 * v, child: child),
          ),
        );
      },
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          colors: [Colors.white, Color(0xFFCFE9FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(r),
        child: Text(
          char,
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.5,
            color: Colors.white,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

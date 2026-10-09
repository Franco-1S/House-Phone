import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/reveal_route.dart';
import '../../core/theme.dart';

/// Der große grüne Anruf-Button: atmet sanft, wenn er bereit ist, und merkt
/// sich seine Position als Startpunkt für den Reveal-Übergang.
class CallFab extends StatefulWidget {
  const CallFab({
    super.key,
    required this.enabled,
    required this.onTap,
    this.size = 78,
  });

  final bool enabled;
  final VoidCallback onTap;
  final double size;

  @override
  State<CallFab> createState() => _CallFabState();
}

class _CallFabState extends State<CallFab> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 380),
  );
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _breath.dispose();
    _press.dispose();
    _orbit.dispose();
    super.dispose();
  }

  void _tap() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      RevealOrigin.value = box.localToGlobal(box.size.center(Offset.zero));
    }
    widget.enabled ? Haptics.press() : Haptics.error();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      onTap: _tap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _press, _orbit]),
        builder: (context, _) {
          final b = Curves.easeInOut.transform(_breath.value);
          final p = Curves.easeOut.transform(_press.value);
          final on = widget.enabled;
          return SizedBox.square(
            dimension: s * 1.5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (on)
                  // Rotierender Lichtkranz.
                  Transform.rotate(
                    angle: _orbit.value * math.pi * 2,
                    child: Container(
                      width: s * (1.18 + 0.06 * b),
                      height: s * (1.18 + 0.06 * b),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            AppColors.green.withValues(alpha: 0),
                            AppColors.green.withValues(alpha: 0.55),
                            AppColors.cyan.withValues(alpha: 0.6),
                            AppColors.green.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.35, 0.6, 1],
                        ),
                      ),
                    ),
                  ),
                Transform.scale(
                  scale: 1 - 0.08 * p,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: on
                            ? const [AppColors.green, AppColors.greenDeep]
                            : [
                                Colors.white.withValues(alpha: 0.12),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                      ),
                      boxShadow: on
                          ? [
                              BoxShadow(
                                color: AppColors.green.withValues(
                                  alpha: 0.25 + 0.3 * b,
                                ),
                                blurRadius: 24 + 22 * b,
                                spreadRadius: 1 + 3 * b,
                              ),
                            ]
                          : const [],
                    ),
                    child: Transform.rotate(
                      angle: -0.35 * p,
                      child: Icon(
                        Icons.call_rounded,
                        size: s * 0.42,
                        color: on
                            ? const Color(0xFF02150D)
                            : AppColors.textFaint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

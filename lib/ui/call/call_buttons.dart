import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';

/// Große runde Umschalt-Taste (Stumm, Lautsprecher, Halten, Tastatur).
/// Aktiv = leuchtend weiß gefüllt, Icon wechselt mit Dreh-Animation.
class CallToggleButton extends StatefulWidget {
  const CallToggleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeIcon,
    this.enabled = true,
    this.size = 80,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final double size;

  @override
  State<CallToggleButton> createState() => _CallToggleButtonState();
}

class _CallToggleButtonState extends State<CallToggleButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final active = widget.active;
    final icon = active ? (widget.activeIcon ?? widget.icon) : widget.icon;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: widget.enabled ? 1 : 0.35,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.enabled
            ? () {
                Haptics.press();
                widget.onTap();
              }
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _down ? 0.88 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.09),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: active ? 0 : 0.14),
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.35),
                            blurRadius: 26,
                          ),
                        ]
                      : const [],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  transitionBuilder: (child, a) => RotationTransition(
                    turns: Tween(begin: -0.25, end: 0.0).animate(
                      CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                    ),
                    child: ScaleTransition(scale: a, child: child),
                  ),
                  child: Icon(
                    icon,
                    key: ValueKey('$icon$active'),
                    size: s * 0.4,
                    color: active ? const Color(0xFF0B0C14) : AppColors.text,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: active ? AppColors.text : AppColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Runder Aktions-Button (Auflegen/Annehmen) mit Glow und optionalem
/// "Wackeln", das zum Annehmen einlädt.
class CallActionButton extends StatefulWidget {
  const CallActionButton({
    super.key,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.label,
    this.size = 84,
    this.wiggle = false,
  });

  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final String? label;
  final double size;
  final bool wiggle;

  @override
  State<CallActionButton> createState() => _CallActionButtonState();
}

class _CallActionButtonState extends State<CallActionButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    reverseDuration: const Duration(milliseconds: 350),
  );

  @override
  void dispose() {
    _pulse.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final glow = widget.colors.first;
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      onTap: () {
        Haptics.heavy();
        widget.onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_pulse, _press]),
            builder: (context, _) {
              final p = _pulse.value;
              final press = Curves.easeOut.transform(_press.value);
              // Kurzes Wackeln in den ersten 30 % jedes Zyklus.
              final wig = widget.wiggle && p < 0.3
                  ? math.sin(p / 0.3 * math.pi * 6) * 0.22 * (1 - p / 0.3)
                  : 0.0;
              return SizedBox.square(
                dimension: (widget.wiggle || widget.label != null)
                    ? s * 1.6
                    : s * 1.2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.wiggle)
                      Container(
                        width: s * (1 + 0.6 * p),
                        height: s * (1 + 0.6 * p),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: glow.withValues(alpha: 0.6 * (1 - p)),
                            width: 2,
                          ),
                        ),
                      ),
                    Transform.scale(
                      scale: 1 - 0.1 * press,
                      child: Container(
                        width: s,
                        height: s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: widget.colors,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: glow.withValues(alpha: 0.45 + 0.2 * press),
                              blurRadius: 30 + 10 * press,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Transform.rotate(
                          angle: wig,
                          child: Icon(
                            widget.icon,
                            size: s * 0.42,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (widget.label != null)
            Text(
              widget.label!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textDim,
              ),
            ),
        ],
      ),
    );
  }
}

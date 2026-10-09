import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';

const _keys = <(String, String)>[
  ('1', ''),
  ('2', 'ABC'),
  ('3', 'DEF'),
  ('4', 'GHI'),
  ('5', 'JKL'),
  ('6', 'MNO'),
  ('7', 'PQRS'),
  ('8', 'TUV'),
  ('9', 'WXYZ'),
  ('*', ''),
  ('0', '+'),
  ('#', ''),
];

/// 4×3-Tastenfeld. Die Tasten fliegen beim ersten Anzeigen gestaffelt ein.
class DialPad extends StatelessWidget {
  const DialPad({
    super.key,
    required this.onKey,
    this.onLongPressZero,
    this.maxKeySize = 84,
    this.compact = false,
  });

  final ValueChanged<String> onKey;
  final VoidCallback? onLongPressZero;
  final double maxKeySize;

  /// Kompakte Variante für die Tonwahl im Gespräch (ohne Buchstaben).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final gap = compact ? 14.0 : 20.0;
        final size = math.min((c.maxWidth - gap * 2) / 3, maxKeySize);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < 4; row++) ...[
              if (row > 0) SizedBox(height: compact ? 12 : 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var col = 0; col < 3; col++) ...[
                    if (col > 0) SizedBox(width: gap),
                    _buildKey(row * 3 + col, size),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildKey(int index, double size) {
    final (digit, letters) = _keys[index];
    return DialKey(
      digit: digit,
      letters: compact ? '' : letters,
      size: size,
      // Diagonale Welle: oben links zuerst, unten rechts zuletzt.
      entranceDelay: Duration(milliseconds: 40 * (index ~/ 3 + index % 3)),
      onTap: () => onKey(digit),
      onLongPress: digit == '0' ? onLongPressZero : null,
    );
  }
}

/// Eine einzelne Taste: Glas, Federung beim Drücken, Licht-Ripple, Haptik.
class DialKey extends StatefulWidget {
  const DialKey({
    super.key,
    required this.digit,
    required this.letters,
    required this.onTap,
    this.onLongPress,
    this.size = 80,
    this.entranceDelay = Duration.zero,
  });

  final String digit;
  final String letters;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double size;
  final Duration entranceDelay;

  @override
  State<DialKey> createState() => _DialKeyState();
}

class _DialKeyState extends State<DialKey> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 420),
  );
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.entranceDelay, () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _press.dispose();
    _ripple.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _down() {
    Haptics.key();
    _press.forward();
    _ripple.forward(from: 0);
    // Sofort beim Aufsetzen auslösen – fühlt sich viel direkter an.
    widget.onTap();
  }

  void _up() => _press.reverse();

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final isSymbol = widget.digit == '*' || widget.digit == '#';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              Haptics.press();
              widget.onLongPress!();
            },
      child: AnimatedBuilder(
        animation: Listenable.merge([_press, _ripple, _entrance]),
        builder: (context, _) {
          final e = Curves.easeOutBack.transform(_entrance.value);
          final p = Curves.easeOut.transform(_press.value);
          final rp = _ripple.value;
          final glow = Color.lerp(AppColors.violet, AppColors.cyan, rp)!;

          return Opacity(
            opacity: _entrance.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 40 * (1 - e)),
              child: Transform.scale(
                scale: (0.55 + 0.45 * e) * (1 - 0.1 * p),
                child: SizedBox.square(
                  dimension: s,
                  child: CustomPaint(
                    painter: _RipplePainter(progress: rp, color: glow),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.4),
                          radius: 1.1,
                          colors: [
                            Color.lerp(
                              Colors.white.withValues(alpha: 0.13),
                              glow.withValues(alpha: 0.55),
                              p,
                            )!,
                            Color.lerp(
                              Colors.white.withValues(alpha: 0.03),
                              glow.withValues(alpha: 0.18),
                              p,
                            )!,
                          ],
                        ),
                        border: Border.all(
                          color: Color.lerp(
                            Colors.white.withValues(alpha: 0.1),
                            glow.withValues(alpha: 0.8),
                            p,
                          )!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withValues(alpha: 0.45 * p),
                            blurRadius: 28 * p,
                            spreadRadius: 2 * p,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.digit,
                            style: TextStyle(
                              fontSize: s * (isSymbol ? 0.44 : 0.4),
                              fontWeight: FontWeight.w300,
                              height: 1.05,
                              color: AppColors.text,
                            ),
                          ),
                          if (widget.letters.isNotEmpty)
                            Text(
                              widget.letters,
                              style: TextStyle(
                                fontSize: s * 0.12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.2,
                                color: AppColors.textDim,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ein Lichtring, der sich beim Antippen nach außen ausbreitet.
class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final c = size.center(Offset.zero);
    final base = size.width / 2;
    final t = Curves.easeOutCubic.transform(progress);
    for (var i = 0; i < 2; i++) {
      final tt = (t - i * 0.18).clamp(0.0, 1.0);
      if (tt == 0) continue;
      canvas.drawCircle(
        c,
        base * (1 + 0.55 * tt),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * (1 - tt)
          ..color = color.withValues(alpha: 0.7 * (1 - tt)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.color != color;
}

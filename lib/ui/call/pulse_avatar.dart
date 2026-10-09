import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../state/call_controller.dart';

/// Der Avatar im Call-Screen.
///
/// * Klingeln/Wählen: konzentrische Schockwellen-Ringe.
/// * Im Gespräch: eine organische "Voice-Aura", die mit den echten
///   WebRTC-Pegeln (remote = cyan, lokal = grün) atmet.
/// * Halten/Beendet: Bewegung friert ein und entsättigt.
class PulseAvatar extends StatefulWidget {
  const PulseAvatar({
    super.key,
    required this.label,
    required this.phase,
    required this.levels,
    this.paused = false,
    this.size = 150,
  });

  final String label;
  final CallPhase phase;
  final AudioLevels levels;
  final bool paused;
  final double size;

  @override
  State<PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<PulseAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _rings = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // Geglättete Pegel, damit die Aura weich statt zappelig reagiert.
  double _remote = 0;
  double _local = 0;

  @override
  void didUpdateWidget(PulseAvatar old) {
    super.didUpdateWidget(old);
    final still = widget.paused || widget.phase == CallPhase.ended;
    if (still && _wobble.isAnimating) {
      _wobble.stop();
      _rings.stop();
    } else if (!still && !_wobble.isAnimating) {
      _wobble.repeat();
      _rings.repeat();
    }
  }

  @override
  void dispose() {
    _rings.dispose();
    _wobble.dispose();
    super.dispose();
  }

  String get _initials {
    final l = widget.label.trim();
    if (l.isEmpty) return '?';
    if (RegExp(r'^[0-9*#+]+$').hasMatch(l)) return '';
    final parts = l.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final ringing =
        widget.phase == CallPhase.incoming ||
        widget.phase == CallPhase.dialing ||
        widget.phase == CallPhase.ringing;
    final live = widget.phase == CallPhase.active && !widget.paused;
    final ended = widget.phase == CallPhase.ended;

    return SizedBox.square(
      // Ringe/Aura dürfen über den Rahmen hinaus malen (kein Clipping).
      dimension: s * 1.55,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rings, _wobble]),
        builder: (context, _) {
          final t = _wobble.value;
          // Wenn keine echten Pegel kommen: synthetische, "sprechende" Kurve.
          final synthR =
              0.25 +
              0.25 *
                  math.sin(t * math.pi * 2 * 7).abs() *
                  (0.5 + 0.5 * math.sin(t * math.pi * 2 * 3));
          final synthL = 0.18 + 0.2 * math.cos(t * math.pi * 2 * 5).abs();
          final targetR = widget.levels.live
              ? widget.levels.remote * 2.2
              : synthR;
          final targetL = widget.levels.live
              ? widget.levels.local * 2.2
              : synthL;
          _remote += (targetR.clamp(0.0, 1.0) - _remote) * 0.18;
          _local += (targetL.clamp(0.0, 1.0) - _local) * 0.18;

          return Stack(
            alignment: Alignment.center,
            children: [
              if (ringing)
                CustomPaint(
                  size: Size.square(s * 1.55),
                  painter: _RingsPainter(
                    progress: _rings.value,
                    radius: s / 2,
                    color: widget.phase == CallPhase.incoming
                        ? AppColors.pink
                        : AppColors.cyan,
                  ),
                ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: live ? 1 : 0,
                child: CustomPaint(
                  size: Size.square(s * 1.55),
                  painter: _AuraPainter(
                    t: t,
                    radius: s / 2,
                    remote: _remote,
                    local: _local,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: ended
                        ? const [Color(0xFF3A3F55), Color(0xFF1C2033)]
                        : widget.paused
                        ? const [Color(0xFF5B5F7A), Color(0xFF2A2D40)]
                        : const [AppColors.violet, AppColors.cyan],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (ended ? Colors.black : AppColors.violet)
                          .withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: -4,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: _initials.isEmpty
                      ? Icon(
                          Icons.person_rounded,
                          size: s * 0.5,
                          color: Colors.white.withValues(alpha: 0.92),
                        )
                      : Text(
                          _initials,
                          style: TextStyle(
                            fontSize: s * 0.34,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.progress,
    required this.radius,
    required this.color,
  });

  final double progress;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (progress + i / 3) % 1.0;
      final e = Curves.easeOutCubic.transform(p);
      final r = radius * (1 + e * 0.95);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - p) + 0.5
          ..color = color.withValues(alpha: 0.65 * (1 - p)),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()..color = color.withValues(alpha: 0.06 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.progress != progress;
}

/// Zwei überlagerte, sich verformende Blobs – wie ein Oszilloskop aus Licht.
class _AuraPainter extends CustomPainter {
  _AuraPainter({
    required this.t,
    required this.radius,
    required this.remote,
    required this.local,
  });

  final double t;
  final double radius;
  final double remote;
  final double local;

  Path _blob(Offset c, double base, double amp, double phase, int lobes) {
    final path = Path();
    const steps = 96;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * math.pi * 2;
      final wave =
          math.sin(a * lobes + phase) * 0.6 +
          math.sin(a * (lobes + 2) - phase * 1.7) * 0.4;
      final r = base + amp * wave;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final phase = t * math.pi * 2;

    void layer(Color color, double level, double ph, int lobes, double grow) {
      final base = radius * (1.08 + grow * level);
      final amp = radius * (0.04 + 0.16 * level);
      final path = _blob(c, base, amp, ph, lobes);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.18 + 0.25 * level)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: 0.5 + 0.4 * level),
      );
    }

    layer(AppColors.green, local, -phase * 2, 4, 0.22);
    layer(AppColors.cyan, remote, phase * 3, 5, 0.38);
  }

  @override
  bool shouldRepaint(_AuraPainter old) => true;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Lebendiger Hintergrund: weiche, wandernde Farbnebel ("Aurora") plus ein
/// feines, aufsteigendes Partikelfeld. Farbwechsel werden weich überblendet.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    required this.colors,
    required this.child,
    this.intensity = 1,
    this.speed = 1,
  });

  final List<Color> colors;
  final Widget child;

  /// 0..1.5 – wie kräftig die Nebel leuchten.
  final double intensity;

  /// Multiplikator für die Bewegung (z. B. beim Klingeln schneller).
  final double speed;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  late final AnimationController _blend = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: 1,
  );

  late List<Color> _from = widget.colors;
  late List<Color> _to = widget.colors;
  late double _fromIntensity = widget.intensity;

  /// Phase akkumuliert, damit Geschwindigkeitswechsel nicht "springen".
  double _phase = 0;
  double _lastLoop = 0;

  @override
  void didUpdateWidget(AuroraBackground old) {
    super.didUpdateWidget(old);
    if (!_sameColors(old.colors, widget.colors) ||
        old.intensity != widget.intensity) {
      _from = _currentColors();
      _fromIntensity = _currentIntensity(old.intensity);
      _to = widget.colors;
      _blend.forward(from: 0);
    }
  }

  bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<Color> _currentColors() {
    final t = Curves.easeInOut.transform(_blend.value);
    return List.generate(_to.length, (i) {
      final from = _from[i % _from.length];
      return Color.lerp(from, _to[i], t)!;
    });
  }

  double _currentIntensity(double target) {
    final t = Curves.easeInOut.transform(_blend.value);
    return _fromIntensity + (target - _fromIntensity) * t;
  }

  @override
  void dispose() {
    _loop.dispose();
    _blend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_loop, _blend]),
            builder: (context, _) {
              var d = _loop.value - _lastLoop;
              if (d < 0) d += 1;
              _lastLoop = _loop.value;
              _phase = (_phase + d * widget.speed) % 1.0;
              return CustomPaint(
                painter: _AuroraPainter(
                  t: _phase,
                  colors: _currentColors(),
                  intensity: _currentIntensity(widget.intensity),
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.colors,
    required this.intensity,
  });

  final double t;
  final List<Color> colors;
  final double intensity;

  static const _tau = math.pi * 2;

  // Pro Nebel: Frequenzen (ganzzahlig → nahtloser Loop), Phasen, Größe.
  static const _blobs = <List<double>>[
    [1, 2, 0.0, 1.3, 0.62],
    [2, 1, 2.1, 0.4, 0.55],
    [1, 1, 4.2, 2.7, 0.70],
    [3, 2, 1.0, 5.1, 0.45],
    [2, 3, 3.3, 0.9, 0.50],
  ];

  static final _particles = List.generate(46, (i) {
    final r = math.Random(i * 7919 + 13);
    return [
      r.nextDouble(),
      r.nextDouble(),
      r.nextDouble(),
      (r.nextInt(3) + 1).toDouble(),
    ];
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg);

    for (var i = 0; i < _blobs.length; i++) {
      final b = _blobs[i];
      final color = colors[i % colors.length];
      final cx = w * (0.5 + 0.42 * math.sin(_tau * t * b[0] + b[2]));
      final cy = h * (0.42 + 0.36 * math.cos(_tau * t * b[1] + b[3]));
      final r = w * b[4] * (1 + 0.18 * math.sin(_tau * t * 2 + i));
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      final alpha = (0.42 * intensity).clamp(0.0, 0.9);
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.35),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(rect),
      );
    }

    // Partikel steigen langsam auf und funkeln.
    final dot = Paint();
    for (final p in _particles) {
      final y = ((p[1] - t * p[3]) % 1.0) * h;
      final x = p[0] * w + math.sin(_tau * (t * 2 + p[2])) * 8;
      final twinkle = 0.5 + 0.5 * math.sin(_tau * (t * 6 * p[3] + p[2]));
      dot.color = Colors.white.withValues(alpha: 0.05 + 0.22 * twinkle);
      canvas.drawCircle(Offset(x, y), 0.6 + p[2] * 1.1, dot);
    }

    // Vignette für Tiefe und Lesbarkeit.
    final full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          radius: 1.05,
          colors: [Colors.transparent, AppColors.bg.withValues(alpha: 0.78)],
          stops: const [0.45, 1],
        ).createShader(full),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => true;
}

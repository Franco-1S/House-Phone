import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Merkt sich, wo zuletzt der Anruf-Button gedrückt wurde, damit der
/// Call-Screen genau von dort aus "aufplatzt".
abstract final class RevealOrigin {
  static Offset? value;
}

/// Kreisförmiger Reveal-Übergang (wie ein Tropfen, der sich ausbreitet).
class RevealRoute<T> extends PageRouteBuilder<T> {
  RevealRoute({required WidgetBuilder builder, Offset? origin})
    : super(
        transitionDuration: const Duration(milliseconds: 720),
        reverseTransitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubicEmphasized,
            reverseCurve: Curves.easeInCubic,
          );
          return AnimatedBuilder(
            animation: curved,
            child: child,
            builder: (context, child) {
              final size = MediaQuery.sizeOf(context);
              final center =
                  origin ?? Offset(size.width / 2, size.height * 0.85);
              return ClipPath(
                clipper: _CircleClipper(center, curved.value),
                child: Opacity(
                  opacity: Curves.easeOut.transform(curved.value),
                  child: child,
                ),
              );
            },
          );
        },
      );
}

class _CircleClipper extends CustomClipper<Path> {
  _CircleClipper(this.center, this.fraction);
  final Offset center;
  final double fraction;

  @override
  Path getClip(Size size) {
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    final maxR =
        corners.map((c) => (c - center).distance).reduce(math.max) * 1.05;
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: maxR * fraction));
  }

  @override
  bool shouldReclip(_CircleClipper old) =>
      old.fraction != fraction || old.center != center;
}

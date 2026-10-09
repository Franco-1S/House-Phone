import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../state/connection_controller.dart';
import 'glass.dart';

Color linkColor(LinkPhase phase) => switch (phase) {
  LinkPhase.registered => AppColors.green,
  LinkPhase.connecting => AppColors.amber,
  LinkPhase.failed || LinkPhase.offline => AppColors.red,
  LinkPhase.unconfigured => AppColors.textDim,
};

/// Dezenter Verbindungsstatus: pulsierender Punkt + Text.
/// Tippen öffnet Details mit "Neu verbinden".
class StatusPill extends ConsumerWidget {
  const StatusPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionProvider);
    final color = linkColor(status.phase);
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () {
        Haptics.tick();
        _showDetails(context, ref);
      },
      child: Glass(
        radius: 40,
        padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
        borderColor: color.withValues(alpha: 0.35),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulsingDot(
                color: color,
                fast: status.phase == LinkPhase.connecting,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey('${status.phase}${status.identity}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.linkTitle(status.phase),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color == AppColors.textDim
                              ? AppColors.text
                              : color,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (status.identity != null)
                        Text(
                          status.identity!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(connectionProvider);
          final color = linkColor(s.phase);
          final l10n = context.l10n;
          final detail = l10n.linkDetail(s);
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: Glass(
              radius: 28,
              padding: const EdgeInsets.all(22),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PulsingDot(color: color, size: 12),
                        const SizedBox(width: 12),
                        Text(
                          l10n.linkTitle(s.phase),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (s.identity != null)
                      Text(
                        s.identity!,
                        style: const TextStyle(color: AppColors.text),
                      ),
                    if (detail != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        style: const TextStyle(color: AppColors.textDim),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (s.phase != LinkPhase.unconfigured)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            foregroundColor: AppColors.text,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Haptics.press();
                            ref.read(connectionProvider.notifier).reconnect();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(l10n.reconnect),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Punkt mit pulsierendem Halo. [fast] = Blinken beim Verbinden.
class PulsingDot extends StatefulWidget {
  const PulsingDot({
    super.key,
    required this.color,
    this.size = 9,
    this.fast = false,
  });

  final Color color;
  final double size;
  final bool fast;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.fast ? 900 : 1800),
  )..repeat();

  @override
  void didUpdateWidget(PulsingDot old) {
    super.didUpdateWidget(old);
    if (old.fast != widget.fast) {
      _c.duration = Duration(milliseconds: widget.fast ? 900 : 1800);
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.size * 2.6;
    return SizedBox.square(
      dimension: box,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          final blink = widget.fast
              ? 0.55 + 0.45 * math.cos(v * math.pi * 2)
              : 1.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size + (box - widget.size) * v,
                height: widget.size + (box - widget.size) * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.45 * (1 - v)),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: blink),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.7),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

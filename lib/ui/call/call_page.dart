import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme.dart';
import '../../state/call_controller.dart';
import '../dialer/dial_pad.dart';
import '../settings/audio_settings_page.dart';
import '../widgets/aurora_background.dart';
import 'call_buttons.dart';
import 'pulse_avatar.dart';

/// Vollbild für eingehende, ausgehende und laufende Anrufe.
class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key});

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  bool _showKeypad = false;
  Timer? _ringHaptics;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _ringHaptics?.cancel();
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent e) {
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    return _onKey(e) == KeyEventResult.handled;
  }

  /// Vibriert rhythmisch, solange ein Anruf eingeht.
  /// PC-Tastatur im Gespräch: Enter = annehmen, Esc = auflegen/ablehnen,
  /// Ziffern = Tonwahl (DTMF), M = stumm, H = halten.
  KeyEventResult _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final call = ref.read(callProvider);
    if (call == null) return KeyEventResult.ignored;
    final ctrl = ref.read(callProvider.notifier);
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      ctrl.hangup();
      return KeyEventResult.handled;
    }
    if ((k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter) &&
        call.phase == CallPhase.incoming) {
      ctrl.answer();
      return KeyEventResult.handled;
    }
    if (!call.isLive) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.keyM) {
      ctrl.toggleMute();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyH) {
      ctrl.toggleHold();
      return KeyEventResult.handled;
    }
    final ch = e.character;
    if (ch != null && RegExp(r'^[0-9*#]$').hasMatch(ch)) {
      ctrl.sendDtmf(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _syncRingHaptics(ActiveCall? call) {
    final ringing = call?.phase == CallPhase.incoming;
    if (ringing && _ringHaptics == null) {
      Haptics.ring();
      _ringHaptics = Timer.periodic(
        const Duration(milliseconds: 1800),
        (_) => Haptics.ring(),
      );
    } else if (!ringing && _ringHaptics != null) {
      _ringHaptics!.cancel();
      _ringHaptics = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callProvider);
    final levels = ref.watch(audioLevelProvider);
    final ctrl = ref.read(callProvider.notifier);
    _syncRingHaptics(call);

    // Der Screen bleibt noch kurz sichtbar, während die Route sich schließt.
    if (call == null) {
      return const Scaffold(backgroundColor: AppColors.bg);
    }

    final held = call.onHold || call.remoteHold;
    final (aurora, intensity, speed) = switch (call.phase) {
      CallPhase.incoming => (AppColors.auroraRinging, 1.25, 2.6),
      CallPhase.dialing ||
      CallPhase.ringing => (AppColors.auroraIdle, 1.0, 1.8),
      CallPhase.active when held => (AppColors.auroraWarn, 0.55, 0.4),
      CallPhase.active => (
        AppColors.auroraLive,
        0.9 + levels.remote * 0.6,
        1.0,
      ),
      CallPhase.ended => (AppColors.auroraEnded, 0.45, 0.3),
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AuroraBackground(
          colors: aurora,
          intensity: intensity,
          speed: speed,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final small = c.maxHeight < 700;
                return Column(
                  children: [
                    SizedBox(height: small ? 12 : 28),
                    _StatusLine(call: call),
                    SizedBox(height: small ? 4 : 12),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.92, end: 1.0).animate(a),
                            child: child,
                          ),
                        ),
                        child: _showKeypad && call.isLive
                            ? _InCallKeypad(
                                key: const ValueKey('keypad'),
                                dtmf: call.dtmf,
                                onKey: ctrl.sendDtmf,
                              )
                            : _Hero(
                                key: const ValueKey('hero'),
                                call: call,
                                levels: levels,
                                held: held,
                                avatarSize: small ? 120 : 150,
                              ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position:
                              Tween(
                                begin: const Offset(0, 0.25),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: a,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                          child: child,
                        ),
                      ),
                      child: switch (call.phase) {
                        CallPhase.incoming => _IncomingActions(
                          key: const ValueKey('incoming'),
                          onAccept: ctrl.answer,
                          onDecline: ctrl.hangup,
                        ),
                        CallPhase.ended => const SizedBox(
                          key: ValueKey('ended'),
                          height: 150,
                        ),
                        _ => _InCallControls(
                          key: const ValueKey('controls'),
                          call: call,
                          keypadOpen: _showKeypad,
                          compact: small,
                          onKeypad: () =>
                              setState(() => _showKeypad = !_showKeypad),
                          onMute: ctrl.toggleMute,
                          onSpeaker: ctrl.toggleSpeaker,
                          onHold: ctrl.toggleHold,
                          onHangup: ctrl.hangup,
                        ),
                      },
                    ),
                    SizedBox(height: small ? 12 : 28),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.call});
  final ActiveCall call;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget text = switch (call.phase) {
      CallPhase.incoming => Text(l10n.callIncoming),
      CallPhase.dialing => _Dots(prefix: l10n.callDialing),
      CallPhase.ringing => _Dots(prefix: l10n.callRinging),
      CallPhase.active when call.remoteHold => Text(l10n.callRemoteHold),
      CallPhase.active when call.onHold => Text(l10n.callOnHold),
      CallPhase.active => CallTimer(since: call.connectedAt!),
      CallPhase.ended => Text(
        l10n.endReason(
          call.endReason,
          code: call.endCode,
          incoming: call.incoming,
        ),
      ),
    };
    final color = switch (call.phase) {
      CallPhase.active when call.onHold || call.remoteHold => AppColors.amber,
      CallPhase.active => AppColors.green,
      CallPhase.ended => AppColors.red,
      _ => AppColors.textDim,
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: DefaultTextStyle.merge(
        key: ValueKey('${call.phase}${call.onHold}${call.remoteHold}'),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        child: text,
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    super.key,
    required this.call,
    required this.levels,
    required this.held,
    required this.avatarSize,
  });

  final ActiveCall call;
  final AudioLevels levels;
  final bool held;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final showNumberLine =
        call.displayName != null &&
        call.displayName!.trim().isNotEmpty &&
        call.displayName!.trim() != call.number;
    // FittedBox: Auf kleinen Displays skaliert der ganze Block mit,
    // statt in die Buttons hineinzuragen.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulseAvatar(
                label: call.title.isEmpty
                    ? context.l10n.unknownCaller
                    : call.title,
                phase: call.phase,
                levels: levels,
                paused: held,
                size: avatarSize,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - v)),
                      child: child,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      call.title.isEmpty
                          ? context.l10n.unknownCaller
                          : call.title,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              if (showNumberLine) ...[
                const SizedBox(height: 4),
                Text(
                  call.number,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textDim,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                [
                  call.incoming
                      ? context.l10n.directionIncoming
                      : context.l10n.directionOutgoing,
                  if (call.line != null)
                    call.incoming
                        ? context.l10n.onLine(call.line!)
                        : context.l10n.viaLine(call.line!),
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InCallControls extends StatelessWidget {
  const _InCallControls({
    super.key,
    required this.call,
    required this.keypadOpen,
    required this.compact,
    required this.onKeypad,
    required this.onMute,
    required this.onSpeaker,
    required this.onHold,
    required this.onHangup,
  });

  final ActiveCall call;
  final bool keypadOpen;
  final bool compact;
  final VoidCallback onKeypad;
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback onHold;
  final VoidCallback onHangup;

  @override
  Widget build(BuildContext context) {
    final live = call.isLive;
    final size = compact ? 68.0 : 80.0;
    final gap = compact ? 28.0 : 44.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CallToggleButton(
              icon: Icons.mic_none_rounded,
              activeIcon: Icons.mic_off_rounded,
              label: context.l10n.btnMute,
              active: call.muted,
              enabled: live,
              size: size,
              onTap: onMute,
            ),
            SizedBox(width: gap),
            CallToggleButton(
              icon: Icons.dialpad_rounded,
              activeIcon: Icons.close_rounded,
              label: context.l10n.btnKeypad,
              active: keypadOpen,
              enabled: live,
              size: size,
              onTap: onKeypad,
            ),
          ],
        ),
        SizedBox(height: compact ? 14 : 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Am PC gibt es keine Hörmuschel → stattdessen Audio-Einstellungen.
            if (isDesktop)
              CallToggleButton(
                icon: Icons.headset_mic_rounded,
                label: context.l10n.btnAudio,
                active: false,
                size: size,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AudioSettingsPage(),
                  ),
                ),
              )
            else
              CallToggleButton(
                icon: Icons.volume_down_rounded,
                activeIcon: Icons.volume_up_rounded,
                label: context.l10n.btnSpeaker,
                active: call.speaker,
                size: size,
                onTap: onSpeaker,
              ),
            SizedBox(width: gap),
            CallToggleButton(
              icon: Icons.pause_rounded,
              activeIcon: Icons.play_arrow_rounded,
              label: call.onHold
                  ? context.l10n.btnResume
                  : context.l10n.btnHold,
              active: call.onHold,
              enabled: live,
              size: size,
              onTap: onHold,
            ),
          ],
        ),
        SizedBox(height: compact ? 8 : 16),
        CallActionButton(
          icon: Icons.call_end_rounded,
          colors: const [AppColors.red, AppColors.redDeep],
          size: compact ? 72 : 84,
          onTap: onHangup,
        ),
      ],
    );
  }
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CallActionButton(
            icon: Icons.call_end_rounded,
            colors: const [AppColors.red, AppColors.redDeep],
            label: context.l10n.btnDecline,
            onTap: onDecline,
          ),
          CallActionButton(
            icon: Icons.call_rounded,
            colors: const [AppColors.green, AppColors.greenDeep],
            label: context.l10n.btnAnswer,
            wiggle: true,
            onTap: onAccept,
          ),
        ],
      ),
    );
  }
}

class _InCallKeypad extends StatelessWidget {
  const _InCallKeypad({super.key, required this.dtmf, required this.onKey});
  final String dtmf;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 44,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              dtmf.isEmpty ? ' ' : dtmf,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56),
          child: DialPad(onKey: onKey, compact: true, maxKeySize: 66),
        ),
      ],
    );
  }
}

/// mm:ss bzw. h:mm:ss seit [since], tickt jede Sekunde.
class CallTimer extends StatefulWidget {
  const CallTimer({super.key, required this.since});
  final DateTime since;

  @override
  State<CallTimer> createState() => _CallTimerState();
}

class _CallTimerState extends State<CallTimer> {
  late final Timer _t = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.since);
    String two(int n) => n.toString().padLeft(2, '0');
    final text = d.inHours > 0
        ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
    return Text(text);
  }
}

/// "Wählt" mit animierten Punkten.
class _Dots extends StatefulWidget {
  const _Dots({required this.prefix});
  final String prefix;

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final n = (_c.value * 4).floor() % 4;
        return Text('${widget.prefix}${'.' * n}${' ' * (3 - n)}');
      },
    );
  }
}

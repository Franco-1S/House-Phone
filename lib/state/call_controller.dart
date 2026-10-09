import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
import 'package:sip_ua/sip_ua.dart';

import '../data/call_log.dart';
import 'audio_settings_controller.dart';
import '../services/sip_service.dart';
import 'call_log_controller.dart';
import 'contacts_controller.dart';
import 'desktop_controller.dart';
import 'locale_controller.dart';
import 'provisioning_controller.dart';
import 'providers.dart';

enum CallPhase { incoming, dialing, ringing, active, ended }

/// Warum ein Anruf endete – die Oberfläche übersetzt das.
enum CallEndReason {
  ended,
  canceled,
  missed,
  rejected,
  busy,
  noAnswer,
  notFound,
  unavailable,
  incomplete,
  incompatible,
  noMicrophone,
  notConnected,
  connectionLost,
  rtpTimeout,
  unauthorized,
  failed,
}

/// UI-Sicht auf den (einzigen) laufenden Anruf.
class ActiveCall {
  const ActiveCall({
    required this.number,
    required this.incoming,
    required this.phase,
    required this.startedAt,
    this.id,
    this.displayName,
    this.muted = false,
    this.speaker = false,
    this.onHold = false,
    this.remoteHold = false,
    this.connectedAt,
    this.endReason,
    this.endCode,
    this.dtmf = '',
    this.line,
  });

  final String? id;
  final String number;
  final String? displayName;
  final bool incoming;
  final CallPhase phase;
  final DateTime startedAt;
  final bool muted;
  final bool speaker;
  final bool onHold;
  final bool remoteHold;
  final DateTime? connectedAt;
  final CallEndReason? endReason;

  /// SIP-Statuscode bei [CallEndReason.failed].
  final int? endCode;

  /// Während des Gesprächs getippte Töne (Anzeige im Call-Screen).
  final String dtmf;

  /// Leitung (Bezeichnung), über die der Anruf läuft – null bei nur einer.
  final String? line;

  String get title => (displayName != null && displayName!.trim().isNotEmpty)
      ? displayName!.trim()
      : number;

  bool get isLive => phase == CallPhase.active;

  ActiveCall copyWith({
    String? id,
    String? number,
    String? displayName,
    CallPhase? phase,
    bool? muted,
    bool? speaker,
    bool? onHold,
    bool? remoteHold,
    DateTime? connectedAt,
    CallEndReason? endReason,
    int? endCode,
    String? dtmf,
    String? line,
  }) {
    return ActiveCall(
      id: id ?? this.id,
      number: number ?? this.number,
      displayName: displayName ?? this.displayName,
      incoming: incoming,
      phase: phase ?? this.phase,
      startedAt: startedAt,
      muted: muted ?? this.muted,
      speaker: speaker ?? this.speaker,
      onHold: onHold ?? this.onHold,
      remoteHold: remoteHold ?? this.remoteHold,
      connectedAt: connectedAt ?? this.connectedAt,
      endReason: endReason ?? this.endReason,
      endCode: endCode ?? this.endCode,
      dtmf: dtmf ?? this.dtmf,
      line: line ?? this.line,
    );
  }
}

/// Echte Pegel aus den WebRTC-Statistiken (0..1), für die Voice-Aura.
class AudioLevels {
  const AudioLevels({this.remote = 0, this.local = 0, this.live = false});
  final double remote;
  final double local;

  /// `false`, solange keine Messwerte vorliegen → UI animiert synthetisch.
  final bool live;
}

final audioLevelProvider = NotifierProvider<AudioLevelController, AudioLevels>(
  AudioLevelController.new,
);

class AudioLevelController extends Notifier<AudioLevels> {
  @override
  AudioLevels build() => const AudioLevels();

  void set(AudioLevels levels) => state = levels;
}

final callProvider = NotifierProvider<CallController, ActiveCall?>(
  CallController.new,
);

/// Steuert genau einen Anruf. Zweitanrufe werden mit 486 (Besetzt) abgewiesen.
class CallController extends Notifier<ActiveCall?> {
  Call? _call;
  Timer? _statsTimer;
  Timer? _clearTimer;

  /// `true`, wenn wir selbst aufgelegt/abgelehnt haben (für die Anrufliste).
  bool _localHangup = false;

  /// Audio der Gegenseite – für live geänderte Gesprächslautstärke.
  MediaStream? _remoteStream;

  SipService get _sip => ref.read(sipServiceProvider);

  @override
  ActiveCall? build() {
    final sub = ref.read(sipServiceProvider).callEvents.listen(_onEvent);
    // Lautstärke-Regler in den Audio-Einstellungen wirkt sofort im Gespräch.
    ref.listen(audioPrefsProvider, (prev, next) {
      if (prev?.callVolume != next.callVolume) {
        ref
            .read(audioServiceProvider)
            .applyCallVolume(_remoteStream, next.callVolume);
      }
    });
    ref.onDispose(() {
      sub.cancel();
      _statsTimer?.cancel();
      _clearTimer?.cancel();
    });
    return null;
  }

  // --- Aktionen aus der UI ---------------------------------------------------

  Future<void> dial(String raw) async {
    final number = raw.replaceAll(RegExp(r'[^0-9*#+]'), '');
    if (number.isEmpty || state != null) return;

    _clearTimer?.cancel();
    _localHangup = false;
    // Optimistisch: Der Call-Screen erscheint sofort, das fühlt sich schneller an.
    state = ActiveCall(
      number: number,
      displayName: ref.read(contactBookProvider).nameFor(number),
      incoming: false,
      phase: CallPhase.dialing,
      startedAt: DateTime.now(),
    );

    final audio = ref.read(audioServiceProvider);
    if (!await audio.ensureMicrophone()) {
      _finish(CallEndReason.noMicrophone);
      return;
    }
    await audio.applyDevices(ref.read(audioPrefsProvider));
    // Während des Permission-Dialogs schon wieder aufgelegt?
    if (state?.phase != CallPhase.dialing) return;
    unawaited(ref.read(settingsRepositoryProvider).setLastDialed(number));
    final prov = ref.read(provisioningProvider);
    final lineId = prov.hasMultipleLines
        ? ref.read(selectedLineProvider)
        : null;
    if (lineId != null) {
      state = state?.copyWith(line: prov.line(lineId)?.label ?? lineId);
    }
    final ok = await _sip.call(number, line: lineId);
    if (!ok) _finish(CallEndReason.notConnected);
  }

  Future<void> answer() async {
    final call = _call;
    if (call == null || state?.phase != CallPhase.incoming) return;
    final audio = ref.read(audioServiceProvider);
    if (!await audio.ensureMicrophone()) {
      call.hangup(<String, dynamic>{'status_code': 480});
      _finish(CallEndReason.noMicrophone);
      return;
    }
    audio.stopRinging();
    await audio.applyDevices(ref.read(audioPrefsProvider));
    _sip.answer(call);
  }

  void hangup() {
    _localHangup = true;
    final call = _call;
    if (call == null) {
      // Noch keine Session (z. B. sofort nach dem Wählen) → nur UI schließen.
      _finish(CallEndReason.canceled);
      return;
    }
    final incomingUnanswered = state?.phase == CallPhase.incoming;
    call.hangup(
      incomingUnanswered
          ? <String, dynamic>{'status_code': 486, 'reason_phrase': 'Busy Here'}
          : null,
    );
  }

  void toggleMute() {
    final s = state;
    final call = _call;
    if (s == null || call == null || !s.isLive) return;
    s.muted ? call.unmute(true, false) : call.mute(true, false);
    state = s.copyWith(muted: !s.muted);
  }

  Future<void> toggleSpeaker() async {
    final s = state;
    if (s == null) return;
    state = s.copyWith(speaker: !s.speaker);
    await ref.read(audioServiceProvider).setSpeaker(!s.speaker);
  }

  void toggleHold() {
    final s = state;
    final call = _call;
    if (s == null || call == null || !s.isLive) return;
    s.onHold ? call.unhold() : call.hold();
    state = s.copyWith(onHold: !s.onHold);
  }

  void sendDtmf(String tone) {
    final s = state;
    if (s == null || !s.isLive) return;
    _call?.sendDTMF(tone);
    state = s.copyWith(dtmf: s.dtmf + tone);
  }

  // --- Events aus sip_ua -----------------------------------------------------

  void _onEvent(SipCallEvent e) {
    final call = e.call;
    final st = e.state.state;

    if (st == CallStateEnum.CALL_INITIATION) {
      _onInitiation(call);
      return;
    }
    if (_call == null || call.id != _call!.id) return;
    final s = state;
    if (s == null) return;

    switch (st) {
      case CallStateEnum.CONNECTING:
        if (!s.incoming) state = s.copyWith(phase: CallPhase.dialing);
      case CallStateEnum.PROGRESS:
        if (!s.incoming) state = s.copyWith(phase: CallPhase.ringing);
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        if (s.phase != CallPhase.active) _onConnected(s);
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
        final held = st == CallStateEnum.HOLD;
        state = e.state.originator == Originator.remote
            ? s.copyWith(remoteHold: held)
            : s.copyWith(onHold: held);
      case CallStateEnum.MUTED:
      case CallStateEnum.UNMUTED:
        if (e.state.audio ?? true) {
          state = s.copyWith(muted: st == CallStateEnum.MUTED);
        }
      case CallStateEnum.STREAM:
        // Android setzt beim Eintreffen des Remote-Streams gern das Routing
        // zurück – den gewünschten Ausgang daher erneut anwenden.
        if (e.state.originator == Originator.remote) {
          final audio = ref.read(audioServiceProvider);
          audio.setSpeaker(s.speaker);
          _remoteStream = e.state.stream;
          audio.applyCallVolume(
            _remoteStream,
            ref.read(audioPrefsProvider).callVolume,
          );
        }
      case CallStateEnum.FAILED:
        _finish(_reason(e.state, s), code: e.state.cause?.status_code);
      case CallStateEnum.ENDED:
        _finish(
          s.isLive || s.phase == CallPhase.ended
              ? CallEndReason.ended
              : _reason(e.state, s),
          code: e.state.cause?.status_code,
        );
      default:
        break;
    }
  }

  void _onInitiation(Call call) {
    final current = state;
    final incoming = call.direction == Direction.incoming;

    if (incoming) {
      if (current != null && current.phase != CallPhase.ended) {
        // Schon im Gespräch → zweiten Anruf als "Besetzt" abweisen.
        call.hangup(<String, dynamic>{'status_code': 486});
        return;
      }
      _clearTimer?.cancel();
      _localHangup = false;
      _call = call;
      final remote = call.remote_identity ?? '';
      state = ActiveCall(
        id: call.id,
        number: remote,
        // Eigenes Telefonbuch hat Vorrang vor dem, was die Gegenseite sendet.
        displayName:
            ref.read(contactBookProvider).nameFor(remote) ??
            call.remote_display_name,
        incoming: true,
        phase: CallPhase.incoming,
        line: _lineLabel(SipService.incomingLine(call)),
        startedAt: DateTime.now(),
      );
      final l10n = ref.read(l10nProvider);
      ref
          .read(backgroundServiceProvider)
          .showIncomingCall(
            title: l10n.notifIncomingTitle,
            caller: state!.title.isEmpty ? l10n.unknownCaller : state!.title,
          );
      ref.read(audioServiceProvider).startRinging(ref.read(audioPrefsProvider));
      return;
    }

    // Ausgehend, aber der Nutzer hat schon vor dem Session-Start aufgelegt.
    if (current?.phase == CallPhase.ended) {
      call.hangup();
      return;
    }
    // Ausgehend: der optimistisch angelegte Zustand bekommt seine Session-ID.
    _call = call;
    state =
        (current ??
                ActiveCall(
                  number: call.remote_identity ?? '',
                  incoming: false,
                  phase: CallPhase.dialing,
                  startedAt: DateTime.now(),
                ))
            .copyWith(id: call.id);
  }

  void _onConnected(ActiveCall s) {
    state = s.copyWith(phase: CallPhase.active, connectedAt: DateTime.now());
    ref.read(backgroundServiceProvider).cancelIncomingCall();
    ref.read(audioServiceProvider).stopRinging();
    HapticFeedback.mediumImpact();
    final audio = ref.read(audioServiceProvider);
    audio.setSpeaker(s.speaker);
    audio.keepAwake(true);
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(
      const Duration(milliseconds: 180),
      (_) => _pollLevels(),
    );
  }

  void _finish(CallEndReason reason, {int? code}) {
    _statsTimer?.cancel();
    _statsTimer = null;
    _call = null;
    _remoteStream = null;
    ref.read(audioLevelProvider.notifier).set(const AudioLevels());
    final audio = ref.read(audioServiceProvider);
    audio.stopRinging();
    audio.keepAwake(false);
    audio.setSpeaker(false);

    final background = ref.read(backgroundServiceProvider);
    background.cancelIncomingCall();

    final s = state;
    if (s == null || s.phase == CallPhase.ended) return;
    state = s.copyWith(
      phase: CallPhase.ended,
      endReason: reason,
      endCode: code,
    );
    HapticFeedback.heavyImpact();

    final entry = _logEntry(s, reason);
    ref.read(callLogProvider.notifier).add(entry);
    if (entry.isMissed) {
      final l10n = ref.read(l10nProvider);
      final caller = entry.title.isEmpty ? l10n.unknownCaller : entry.title;
      background.showMissedCall(title: l10n.notifMissedTitle, caller: caller);
      ref
          .read(trayServiceProvider)
          .notify(title: l10n.notifMissedTitle, text: caller);
    }

    // Kurz "Anruf beendet" zeigen, dann den Call-Screen schließen.
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(milliseconds: 1600), () {
      if (state?.phase == CallPhase.ended) state = null;
    });
  }

  CallLogEntry _logEntry(ActiveCall s, CallEndReason reason) {
    final connected = s.connectedAt;
    final outcome = connected != null
        ? CallOutcome.answered
        : s.incoming
        ? (_localHangup ? CallOutcome.declined : CallOutcome.missed)
        : (_localHangup ? CallOutcome.canceled : CallOutcome.failed);
    return CallLogEntry(
      id: '${s.startedAt.microsecondsSinceEpoch}',
      number: s.number,
      displayName: s.displayName,
      incoming: s.incoming,
      outcome: outcome,
      startedAt: s.startedAt,
      duration: connected == null
          ? Duration.zero
          : DateTime.now().difference(connected),
      detail: outcome == CallOutcome.failed ? reason.name : null,
      line: s.line,
    );
  }

  /// Server schickt die Leitungs-ID; angezeigt wird die Bezeichnung.
  String? _lineLabel(String? id) {
    if (id == null) return null;
    final prov = ref.read(provisioningProvider);
    if (!prov.hasMultipleLines && prov.lines.isNotEmpty) return null;
    return prov.line(id)?.label ?? id;
  }

  Future<void> _pollLevels() async {
    final call = _call;
    if (call == null) return;
    try {
      final reports = await call.getStats();
      if (reports == null) return;
      double? remote;
      double? local;
      for (final r in reports) {
        final v = r.values;
        if (v['kind'] != 'audio') continue;
        if (r.type == 'inbound-rtp') remote = _asDouble(v['audioLevel']);
        if (r.type == 'media-source') local = _asDouble(v['audioLevel']);
      }
      if (remote == null && local == null) return;
      ref
          .read(audioLevelProvider.notifier)
          .set(
            AudioLevels(
              remote: (remote ?? 0).clamp(0, 1),
              local: (local ?? 0).clamp(0, 1),
              live: true,
            ),
          );
    } catch (_) {
      // Stats sind optional – bei Fehlern animiert die UI synthetisch.
    }
  }

  static double? _asDouble(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('$v');

  static CallEndReason _reason(CallState st, ActiveCall s) {
    final code = st.cause?.status_code;
    return switch (st.cause?.cause) {
      'Busy' => CallEndReason.busy,
      'Rejected' => CallEndReason.rejected,
      'Canceled' => s.incoming ? CallEndReason.missed : CallEndReason.canceled,
      'No Answer' || 'Expires' => CallEndReason.noAnswer,
      'Not Found' => CallEndReason.notFound,
      'Unavailable' => CallEndReason.unavailable,
      'Address Incomplete' => CallEndReason.incomplete,
      'Incompatible SDP' ||
      'Bad Media Description' => CallEndReason.incompatible,
      'User Denied Media Access' => CallEndReason.noMicrophone,
      'Connection Error' || 'Request Timeout' => CallEndReason.connectionLost,
      'RTP Timeout' => CallEndReason.rtpTimeout,
      'Authentication Error' => CallEndReason.unauthorized,
      _ => code != null ? CallEndReason.failed : CallEndReason.ended,
    };
  }
}

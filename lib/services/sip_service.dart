import 'dart:async';

import 'package:sip_ua/sip_ua.dart';

import '../data/sip_account.dart';

/// Ein Zustandswechsel eines Anrufs, so wie `sip_ua` ihn meldet.
class SipCallEvent {
  const SipCallEvent(this.call, this.state);
  final Call call;
  final CallState state;
}

/// Dünne, testbare Hülle um [SIPUAHelper].
///
/// Kennt keine UI und keinen App-State: Sie übersetzt nur die
/// Listener-Callbacks von `sip_ua` in Dart-Streams, die von den
/// Riverpod-Controllern konsumiert werden.
class SipService implements SipUaHelperListener {
  SipService() {
    _helper.addSipUaHelperListener(this);
  }

  final SIPUAHelper _helper = SIPUAHelper();
  bool _started = false;

  final _transport = StreamController<TransportState>.broadcast();
  final _registration = StreamController<RegistrationState>.broadcast();
  final _calls = StreamController<SipCallEvent>.broadcast();

  Stream<TransportState> get transportEvents => _transport.stream;
  Stream<RegistrationState> get registrationEvents => _registration.stream;
  Stream<SipCallEvent> get callEvents => _calls.stream;

  bool get isRegistered => _started && _helper.registered;
  bool get isConnected => _started && _helper.connected;

  /// Startet (oder ersetzt) den User-Agent und registriert sich.
  Future<void> start(SipAccount account) async {
    await stop();
    await _helper.start(_buildSettings(account));
    _started = true;
  }

  Future<void> stop() async {
    if (!_started) return;
    try {
      if (_helper.registered) await _helper.unregister();
    } catch (_) {
      // Abmelden ist "best effort" – der Socket wird ohnehin geschlossen.
    }
    _helper.stop();
    _started = false;
  }

  /// Startet einen reinen Audio-Anruf. `false`, wenn nicht verbunden.
  /// SIP-Header, mit dem App und Server die Leitung (Rufnummer) aushandeln.
  static const lineHeader = 'X-Haustelefon-Line';

  /// [line] = gewünschte ausgehende Leitung (Server prüft die Berechtigung).
  Future<bool> call(String target, {String? line}) => _helper.call(
    target,
    voiceOnly: true,
    headers: line == null ? null : ['$lineHeader: $line'],
  );

  /// Leitung, auf der ein eingehender Anruf ankam (vom Server gesetzt).
  static String? incomingLine(Call call) {
    try {
      final request = call.session.request;
      final value = request?.getHeader(lineHeader);
      final text = value?.toString().trim();
      return (text == null || text.isEmpty) ? null : text;
    } catch (_) {
      return null;
    }
  }

  void answer(Call call) => call.answer(_helper.buildCallOptions(true));

  UaSettings _buildSettings(SipAccount a) {
    final settings = UaSettings()
      ..uri = 'sip:${a.username.trim()}@${a.domain.trim()}'
      ..authorizationUser = a.effectiveAuthUser
      ..password = a.password
      ..displayName = a.displayName.trim().isEmpty
          ? a.username.trim()
          : a.displayName
      ..userAgent = 'Haustelefon/1.0 (sip_ua)'
      ..register = true
      ..register_expires = 300
      // RFC 2833 funktioniert mit Asterisk und den Speedport-IVRs zuverlässiger
      // als SIP INFO.
      ..dtmfMode = DtmfMode.RFC2833
      // Im Heimnetz/VPN braucht es weder STUN noch TURN – das spart beim
      // Rufaufbau die ICE-Gathering-Wartezeit.
      ..iceServers = <Map<String, String>>[]
      ..iceGatheringTimeout = 600
      ..connectionRecoveryMinInterval = 2
      ..connectionRecoveryMaxInterval = 20;

    switch (a.transport) {
      case SipTransport.websocket:
        settings
          ..transportType = TransportType.WS
          ..webSocketUrl = a.wsUrl.trim()
          // Selbstsignierte Zertifikate auf dem Pi (wss://) zulassen.
          ..webSocketSettings.allowBadCertificate = true;
      case SipTransport.tcp:
        settings
          ..transportType = TransportType.TCP
          ..host = a.domain.trim()
          ..port = a.port.toString()
          ..tcpSocketSettings.allowBadCertificate = true;
    }
    return settings;
  }

  // --- SipUaHelperListener ---------------------------------------------------

  @override
  void transportStateChanged(TransportState state) => _transport.add(state);

  @override
  void registrationStateChanged(RegistrationState state) =>
      _registration.add(state);

  @override
  void callStateChanged(Call call, CallState state) =>
      _calls.add(SipCallEvent(call, state));

  /// Re-INVITEs (z. B. Halten durch die Gegenseite, Codec-Wechsel durch
  /// Asterisk) müssen aktiv angenommen werden, sonst hängt der Dialog.
  @override
  void onNewReinvite(ReInvite event) {
    event.accept?.call(<String, dynamic>{});
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  Future<void> dispose() async {
    await stop();
    _helper.removeSipUaHelperListener(this);
    await _transport.close();
    await _registration.close();
    await _calls.close();
  }
}

/// Wie die App mit der Telefonanlage spricht.
enum SipTransport {
  /// SIP über WebSocket zu einem WebRTC-fähigen Gateway (Asterisk auf dem Pi).
  /// Empfohlen: Nur so funktioniert das Audio zuverlässig mit dem Speedport.
  websocket,

  /// SIP über TCP direkt zum Speedport. Experimentell: Die Registrierung kann
  /// klappen, Audio scheitert aber meist, weil WebRTC verschlüsseltes
  /// DTLS-SRTP verlangt und der Speedport nur unverschlüsseltes RTP spricht.
  tcp,
}

/// Unveränderliche Zugangsdaten einer SIP-Nebenstelle.
///
/// Absichtlich ohne `==`-Override: Jede gespeicherte Instanz gilt als neu,
/// damit ein erneutes "Speichern & Verbinden" immer neu registriert.
class SipAccount {
  const SipAccount({
    required this.transport,
    required this.wsUrl,
    required this.domain,
    required this.port,
    required this.username,
    required this.password,
    this.authUser = '',
    this.displayName = '',
  });

  /// Sinnvolle Startwerte für ein Heimnetz mit Pi-Gateway.
  factory SipAccount.defaults() => const SipAccount(
    transport: SipTransport.websocket,
    wsUrl: 'ws://192.168.2.50:8088/ws',
    domain: '192.168.2.50',
    port: 5060,
    username: '',
    password: '',
  );

  final SipTransport transport;

  /// z. B. `ws://192.168.2.50:8088/ws` (nur bei [SipTransport.websocket]).
  final String wsUrl;

  /// SIP-Domain bzw. Registrar, z. B. `192.168.2.50` oder `speedport.ip`.
  final String domain;

  /// SIP-Port für TCP (nur bei [SipTransport.tcp]).
  final int port;

  final String username;
  final String password;

  /// Optionaler abweichender Auth-Benutzer. Leer = [username].
  final String authUser;
  final String displayName;

  String get effectiveAuthUser =>
      authUser.trim().isEmpty ? username.trim() : authUser.trim();

  String get identity => '${username.trim()}@${domain.trim()}';

  bool get isComplete =>
      username.trim().isNotEmpty &&
      password.isNotEmpty &&
      domain.trim().isNotEmpty &&
      (transport == SipTransport.tcp || wsUrl.trim().isNotEmpty);

  SipAccount copyWith({
    SipTransport? transport,
    String? wsUrl,
    String? domain,
    int? port,
    String? username,
    String? password,
    String? authUser,
    String? displayName,
  }) {
    return SipAccount(
      transport: transport ?? this.transport,
      wsUrl: wsUrl ?? this.wsUrl,
      domain: domain ?? this.domain,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      authUser: authUser ?? this.authUser,
      displayName: displayName ?? this.displayName,
    );
  }
}

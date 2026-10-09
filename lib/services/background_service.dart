import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Brücke zum nativen Android-Teil (KeepAliveService, CallNotifications).
///
/// Auf iOS, Windows & Co. sind alle Aufrufe bewusst No-ops: iOS erlaubt
/// keine dauerhaft offenen Sockets im Hintergrund (dafür bräuchte es
/// PushKit + CallKit + einen Push-Server), und am PC läuft die App ohnehin
/// weiter, solange das Fenster offen ist.
class BackgroundService {
  static const _channel = MethodChannel('de.haustelefon/background');

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _running = false;

  /// Startet den Vordergrund-Dienst mit Dauer-Benachrichtigung.
  Future<void> startKeepAlive({
    required String title,
    required String text,
  }) async {
    if (_running) return;
    _running = true;
    await _invoke('startKeepAlive', {'title': title, 'text': text});
  }

  Future<void> stopKeepAlive() async {
    if (!_running) return;
    _running = false;
    await _invoke('stopKeepAlive');
  }

  Future<void> showIncomingCall({
    required String title,
    required String caller,
  }) => _invoke('showIncomingCall', {'title': title, 'caller': caller});

  Future<void> cancelIncomingCall() => _invoke('cancelIncomingCall');

  Future<void> showMissedCall({
    required String title,
    required String caller,
  }) => _invoke('showMissedCall', {'title': title, 'caller': caller});

  /// Öffnet den Android-Dialog "Akku-Optimierung ignorieren".
  Future<void> requestBatteryExemption() => _invoke('requestBatteryExemption');

  Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (e) {
      debugPrint('BackgroundService.$method fehlgeschlagen: $e');
    }
  }
}

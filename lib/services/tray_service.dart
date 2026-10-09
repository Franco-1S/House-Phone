import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/platform.dart';

/// Symbol im Windows-Infobereich (umgesetzt in windows/runner/flutter_window.cpp).
/// Auf allen anderen Plattformen ein No-op.
class TrayService {
  static const _channel = MethodChannel('de.haustelefon/tray');

  /// Übersetzte Texte + ob "X" in den Infobereich minimiert.
  Future<void> configure({
    required String tooltip,
    required String open,
    required String quit,
    required String hiddenTitle,
    required String hiddenText,
    required bool closeToTray,
  }) => _invoke('configure', {
    'tooltip': tooltip,
    'open': open,
    'quit': quit,
    'hiddenTitle': hiddenTitle,
    'hiddenText': hiddenText,
    'closeToTray': closeToTray,
  });

  /// Grüner/grauer Punkt im Symbol + Tooltip.
  Future<void> setStatus({required bool online, required String tooltip}) =>
      _invoke('setStatus', {'online': online, 'tooltip': tooltip});

  /// Windows-Benachrichtigung am Infobereich (z. B. verpasster Anruf).
  Future<void> notify({required String title, required String text}) =>
      _invoke('notify', {'title': title, 'text': text});

  /// Fenster aus dem Infobereich zurückholen.
  Future<void> show() => _invoke('show');

  Future<bool> isAutostart() async =>
      await _invoke<bool>('isAutostart') ?? false;

  /// Trägt die App in "Mit Windows starten" ein (Registry des Benutzers).
  Future<bool> setAutostart(bool enabled) async =>
      await _invoke<bool>('setAutostart', {'enabled': enabled}) ?? false;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    if (!isWindows) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e) {
      debugPrint('TrayService.$method: $e');
      return null;
    }
  }
}

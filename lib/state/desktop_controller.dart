import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n.dart';
import '../core/platform.dart';
import '../services/tray_service.dart';
import 'connection_controller.dart';
import 'locale_controller.dart';
import 'providers.dart';

final trayServiceProvider = Provider<TrayService>((ref) => TrayService());

class DesktopPrefs {
  const DesktopPrefs({this.closeToTray = true, this.autostart = false});

  /// "X" versteckt das Fenster im Infobereich statt die App zu beenden.
  final bool closeToTray;

  /// Mit Windows starten (unsichtbar im Infobereich).
  final bool autostart;

  DesktopPrefs copyWith({bool? closeToTray, bool? autostart}) => DesktopPrefs(
    closeToTray: closeToTray ?? this.closeToTray,
    autostart: autostart ?? this.autostart,
  );
}

final desktopPrefsProvider =
    NotifierProvider<DesktopPrefsController, DesktopPrefs>(
      DesktopPrefsController.new,
    );

class DesktopPrefsController extends Notifier<DesktopPrefs> {
  static const _kCloseToTray = 'desktop.closeToTray';

  @override
  DesktopPrefs build() {
    final prefs = ref.read(sharedPreferencesProvider);
    // Autostart steht in der Registry – Wahrheit von dort holen.
    if (isWindows) {
      ref.read(trayServiceProvider).isAutostart().then((on) {
        if (ref.mounted && on != state.autostart) {
          state = state.copyWith(autostart: on);
        }
      });
    }
    return DesktopPrefs(closeToTray: prefs.getBool(_kCloseToTray) ?? true);
  }

  Future<void> setCloseToTray(bool on) async {
    state = state.copyWith(closeToTray: on);
    await ref.read(sharedPreferencesProvider).setBool(_kCloseToTray, on);
  }

  Future<void> setAutostart(bool on) async {
    final ok = await ref.read(trayServiceProvider).setAutostart(on);
    if (ok) state = state.copyWith(autostart: on);
  }
}

/// Hält das Infobereich-Symbol aktuell: Texte in der gewählten Sprache,
/// grüner/grauer Status-Punkt und Tooltip mit dem Verbindungsstatus.
final trayBindingProvider = Provider<void>((ref) {
  if (!isWindows) return;
  final tray = ref.read(trayServiceProvider);
  final l10n = ref.watch(l10nProvider);
  final prefs = ref.watch(desktopPrefsProvider);
  final status = ref.watch(connectionProvider);

  final tooltip = [
    'Haustelefon',
    l10n.linkTitle(status.phase),
    if (status.identity != null) status.identity!,
  ].join(' · ');

  tray.configure(
    tooltip: tooltip,
    open: l10n.trayOpen,
    quit: l10n.trayQuit,
    hiddenTitle: l10n.trayHiddenTitle,
    hiddenText: l10n.trayHiddenText,
    closeToTray: prefs.closeToTray,
  );
  tray.setStatus(online: status.isRegistered, tooltip: tooltip);
});

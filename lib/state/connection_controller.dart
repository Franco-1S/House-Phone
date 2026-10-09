import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sip_ua/sip_ua.dart';

import '../data/sip_account.dart';
import 'account_controller.dart';
import 'locale_controller.dart';
import 'providers.dart';

enum LinkPhase { unconfigured, connecting, registered, failed, offline }

/// Warum die Verbindung gerade so ist, wie sie ist. Die Oberfläche macht
/// daraus einen Text in der gewählten Sprache.
enum LinkDetail {
  setupHint,
  starting,
  registering,
  connecting,
  ready,
  noAnswer,
  startFailed,
  authRejected,
  notFound,
  unreachable,
  timeout,
  disconnected,
  unregistered,
  other,
}

class ConnectionStatus {
  const ConnectionStatus(
    this.phase, {
    this.detail,
    this.identity,
    this.host,
    this.info,
    this.retrying = false,
  });

  final LinkPhase phase;
  final LinkDetail? detail;

  /// z. B. `handy@192.168.2.50`
  final String? identity;

  /// Server-Adresse für Texte wie "Keine Antwort von …".
  final String? host;

  /// Zusatzinfo für [LinkDetail.other] / [LinkDetail.startFailed].
  final String? info;

  /// `true`: sip_ua versucht es im Hintergrund automatisch weiter.
  final bool retrying;

  bool get isRegistered => phase == LinkPhase.registered;
}

final connectionProvider =
    NotifierProvider<ConnectionController, ConnectionStatus>(
      ConnectionController.new,
    );

/// Übersetzt Transport- und Registrierungs-Events in einen einzigen,
/// UI-tauglichen Verbindungsstatus und (re-)startet die Registrierung,
/// sobald sich die gespeicherte Nebenstelle ändert.
class ConnectionController extends Notifier<ConnectionStatus> {
  SipAccount? _account;
  Timer? _timeout;

  /// Ohne Antwort nach dieser Zeit zeigen wir einen klaren Fehler an
  /// (sip_ua versucht im Hintergrund trotzdem weiter).
  static const _connectTimeout = Duration(seconds: 10);

  @override
  ConnectionStatus build() {
    final sip = ref.read(sipServiceProvider);
    final subs = <StreamSubscription<Object>>[
      sip.transportEvents.listen(_onTransport),
      sip.registrationEvents.listen(_onRegistration),
    ];
    ref.onDispose(() {
      _timeout?.cancel();
      for (final s in subs) {
        s.cancel();
      }
    });

    ref.listen<AsyncValue<SipAccount?>>(accountProvider, (prev, next) {
      if (next.isLoading) return;
      final account = next.value;
      if (identical(prev?.value, account) && prev?.isLoading == false) return;
      // Nicht synchron im build() den eigenen State setzen.
      Future.microtask(() {
        if (account == null || !account.isComplete) {
          _account = null;
          _timeout?.cancel();
          unawaited(sip.stop());
          unawaited(ref.read(backgroundServiceProvider).stopKeepAlive());
          state = const ConnectionStatus(
            LinkPhase.unconfigured,
            detail: LinkDetail.setupHint,
          );
        } else {
          connect(account);
        }
      });
    }, fireImmediately: true);

    return const ConnectionStatus(
      LinkPhase.connecting,
      detail: LinkDetail.starting,
    );
  }

  ConnectionStatus _status(
    LinkPhase phase,
    LinkDetail detail, {
    String? info,
    bool retrying = false,
  }) => ConnectionStatus(
    phase,
    detail: detail,
    identity: _account?.identity,
    host: _account?.domain,
    info: info,
    retrying: retrying,
  );

  Future<void> connect(SipAccount account) async {
    _account = account;
    state = _status(LinkPhase.connecting, LinkDetail.registering);
    _timeout?.cancel();
    _timeout = Timer(_connectTimeout, () {
      if (identical(_account, account) && state.phase == LinkPhase.connecting) {
        state = _status(LinkPhase.failed, LinkDetail.noAnswer, retrying: true);
      }
    });
    try {
      await ref.read(sipServiceProvider).start(account);
    } catch (e) {
      state = _status(LinkPhase.failed, LinkDetail.startFailed, info: '$e');
    }
  }

  Future<void> reconnect() async {
    final a = _account;
    if (a != null) await connect(a);
  }

  /// Wird beim Zurückkehren in den Vordergrund aufgerufen: Auf iOS/Android
  /// kann der Socket im Hintergrund eingeschlafen sein.
  void ensureConnected() {
    if (_account == null) return;
    if (!ref.read(sipServiceProvider).isRegistered) reconnect();
  }

  void _onTransport(TransportState t) {
    switch (t.state) {
      case TransportStateEnum.CONNECTING:
        // Automatische Wiederholungen nicht zwischen Rot und Orange flackern
        // lassen: ein angezeigter Fehler bleibt stehen, bis es klappt.
        if (state.phase == LinkPhase.connecting) {
          state = _status(LinkPhase.connecting, LinkDetail.connecting);
        }
      case TransportStateEnum.DISCONNECTED:
        if (_account == null) return;
        final (detail, info) = _explain(t.cause?.status_code, t.cause?.cause);
        state = _status(LinkPhase.offline, detail, info: info, retrying: true);
      case TransportStateEnum.CONNECTED:
      case TransportStateEnum.NONE:
        break;
    }
  }

  void _onRegistration(RegistrationState r) {
    switch (r.state) {
      case RegistrationStateEnum.REGISTERED:
        state = _status(LinkPhase.registered, LinkDetail.ready);
        // Android: Prozess im Hintergrund am Leben halten → erreichbar bleiben.
        final l10n = ref.read(l10nProvider);
        unawaited(
          ref
              .read(backgroundServiceProvider)
              .startKeepAlive(
                title: l10n.notifReachableTitle,
                text: l10n.notifReachableAs(_account?.identity ?? ''),
              ),
        );
      case RegistrationStateEnum.REGISTRATION_FAILED:
        final (detail, info) = _explain(r.cause?.status_code, r.cause?.cause);
        state = _status(LinkPhase.failed, detail, info: info);
      case RegistrationStateEnum.UNREGISTERED:
        if (_account == null) return;
        state = _status(LinkPhase.offline, LinkDetail.unregistered);
      case RegistrationStateEnum.NONE:
      case null:
        break;
    }
  }

  static (LinkDetail, String?) _explain(int? code, String? cause) {
    if (code == 401 || code == 403 || cause == 'Authentication Error') {
      return (LinkDetail.authRejected, null);
    }
    if (code == 404) return (LinkDetail.notFound, null);
    return switch (cause) {
      'Connection Error' => (LinkDetail.unreachable, null),
      'Request Timeout' => (LinkDetail.timeout, null),
      null || '' => (LinkDetail.disconnected, null),
      final c => (LinkDetail.other, code != null ? '$c ($code)' : c),
    };
  }
}

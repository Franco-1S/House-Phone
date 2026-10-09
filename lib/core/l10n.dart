import 'package:flutter/widgets.dart';

import '../data/audio_prefs.dart';
import '../data/call_log.dart';
import '../data/contacts.dart';
import '../l10n/app_localizations.dart';
import '../state/call_controller.dart';
import '../state/connection_controller.dart';

export '../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Übersetzt App-Zustände in Text. Controller liefern nur Zustände,
/// damit ein Sprachwechsel sofort überall greift.
extension L10nStates on AppLocalizations {
  String linkTitle(LinkPhase phase) => switch (phase) {
    LinkPhase.unconfigured => statusUnconfigured,
    LinkPhase.connecting => statusConnecting,
    LinkPhase.registered => statusRegistered,
    LinkPhase.failed => statusFailed,
    LinkPhase.offline => statusOffline,
  };

  String? linkDetail(ConnectionStatus s) {
    final host = s.host ?? '';
    final base = switch (s.detail) {
      null => null,
      LinkDetail.setupHint => detailSetupHint,
      LinkDetail.starting => detailStarting,
      LinkDetail.registering => detailRegistering(host),
      LinkDetail.connecting => detailConnecting,
      LinkDetail.ready => detailReady,
      LinkDetail.noAnswer => detailNoAnswer(host),
      LinkDetail.startFailed => detailStartFailed(s.info ?? ''),
      LinkDetail.authRejected => detailAuthRejected,
      LinkDetail.notFound => detailNotFound,
      LinkDetail.unreachable => detailUnreachable,
      LinkDetail.timeout => detailTimeout,
      LinkDetail.disconnected => detailDisconnected,
      LinkDetail.unregistered => detailUnregistered,
      LinkDetail.other => s.info ?? detailDisconnected,
    };
    if (base == null) return null;
    return s.retrying ? '$base – $detailRetrying' : base;
  }

  String endReason(CallEndReason? r, {int? code, bool incoming = false}) =>
      switch (r) {
        null || CallEndReason.ended => endEnded,
        CallEndReason.canceled => endCanceled,
        CallEndReason.missed => endMissed,
        CallEndReason.rejected => incoming ? endDeclined : endRejected,
        CallEndReason.busy => endBusy,
        CallEndReason.noAnswer => endNoAnswer,
        CallEndReason.notFound => endNotFound,
        CallEndReason.unavailable => endUnavailable,
        CallEndReason.incomplete => endIncomplete,
        CallEndReason.incompatible => endIncompatible,
        CallEndReason.noMicrophone => endNoMicrophone,
        CallEndReason.notConnected => endNotConnected,
        CallEndReason.connectionLost => endConnectionLost,
        CallEndReason.rtpTimeout => endRtpTimeout,
        CallEndReason.unauthorized => endUnauthorized,
        CallEndReason.failed => endFailed(code?.toString() ?? '?'),
      };

  /// Gespeicherter Grund in der Anrufliste (Enum-Name, ältere Einträge: Text).
  String logDetail(CallLogEntry e) {
    final d = e.detail;
    if (d == null) return logNotReached;
    for (final r in CallEndReason.values) {
      if (r.name == d) return endReason(r);
    }
    return d;
  }

  String ringtoneName(Ringtone r) => switch (r) {
    Ringtone.classic => ringtoneClassic,
    Ringtone.soft => ringtoneSoft,
    Ringtone.digital => ringtoneDigital,
    Ringtone.off => ringtoneOff,
  };

  String numberLabel(String key) => switch (NumberLabel.parse(key)) {
    NumberLabel.mobile => labelMobile,
    NumberLabel.landline => labelLandline,
    NumberLabel.work => labelWork,
    NumberLabel.internal => labelInternal,
    NumberLabel.other => labelOther,
  };
}

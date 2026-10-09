import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum CallOutcome {
  /// Gespräch kam zustande.
  answered,

  /// Eingehend, nicht angenommen (Anrufer hat aufgelegt / Timeout).
  missed,

  /// Eingehend, von uns abgelehnt.
  declined,

  /// Ausgehend, von uns vor dem Annehmen abgebrochen.
  canceled,

  /// Ausgehend, nicht zustande gekommen (besetzt, nicht erreichbar …).
  failed,
}

class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.number,
    required this.incoming,
    required this.outcome,
    required this.startedAt,
    this.displayName,
    this.duration = Duration.zero,
    this.detail,
    this.line,
  });

  final String id;
  final String number;
  final String? displayName;
  final bool incoming;
  final CallOutcome outcome;
  final DateTime startedAt;
  final Duration duration;

  /// z. B. "Besetzt" bei fehlgeschlagenen Anrufen.
  final String? detail;

  /// Bezeichnung der Leitung (z. B. "Firma"), falls mehrere Nummern.
  final String? line;

  String get title => (displayName != null && displayName!.trim().isNotEmpty)
      ? displayName!.trim()
      : number;

  bool get isMissed => outcome == CallOutcome.missed;

  Map<String, Object?> toJson() => {
    'id': id,
    'number': number,
    'name': displayName,
    'in': incoming,
    'outcome': outcome.name,
    'at': startedAt.millisecondsSinceEpoch,
    'sec': duration.inSeconds,
    'detail': detail,
    'line': line,
  };

  factory CallLogEntry.fromJson(Map<String, Object?> j) => CallLogEntry(
    id: j['id'] as String,
    number: j['number'] as String,
    displayName: j['name'] as String?,
    incoming: j['in'] as bool? ?? false,
    outcome: CallOutcome.values.firstWhere(
      (o) => o.name == j['outcome'],
      orElse: () => CallOutcome.failed,
    ),
    startedAt: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
    duration: Duration(seconds: j['sec'] as int? ?? 0),
    detail: j['detail'] as String?,
    line: j['line'] as String?,
  );
}

/// Persistiert die Anrufliste lokal (neueste zuerst, max. [maxEntries]).
class CallLogRepository {
  CallLogRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'calllog.v1';
  static const _kSeen = 'calllog.seenAt';
  static const maxEntries = 300;

  List<CallLogEntry> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, Object?>>();
      return list.map(CallLogEntry.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<CallLogEntry> entries) => _prefs.setString(
    _key,
    jsonEncode(entries.take(maxEntries).map((e) => e.toJson()).toList()),
  );

  /// Zeitpunkt, bis zu dem verpasste Anrufe als "gesehen" gelten (Badge).
  DateTime get seenAt =>
      DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_kSeen) ?? 0);

  Future<void> markSeen() =>
      _prefs.setInt(_kSeen, DateTime.now().millisecondsSinceEpoch);
}

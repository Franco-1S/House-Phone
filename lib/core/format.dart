import '../l10n/app_localizations.dart';

/// Kleine Formatierer für Uhrzeit, Tag und Dauer.
abstract final class Fmt {
  static String _two(int n) => n.toString().padLeft(2, '0');

  static String time(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  /// "Heute"/"Today", "Gestern"/"Yesterday", Wochentag (letzte 7 Tage)
  /// oder ein Datum (DE: 12.03.2026, sonst ISO: 2026-03-12).
  static String day(DateTime t, AppLocalizations l10n, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final d = DateTime(t.year, t.month, t.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return l10n.today;
    if (diff == 1) return l10n.yesterday;
    if (diff > 1 && diff < 7) return l10n.weekday('${t.weekday}');
    return l10n.localeName.startsWith('de')
        ? '${_two(t.day)}.${_two(t.month)}.${t.year}'
        : '${t.year}-${_two(t.month)}-${_two(t.day)}';
  }

  /// "0:42", "12:05" oder "1:02:33".
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
  }
}

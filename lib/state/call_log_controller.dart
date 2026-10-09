import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/call_log.dart';
import 'providers.dart';

final callLogRepositoryProvider = Provider<CallLogRepository>(
  (ref) => CallLogRepository(ref.watch(sharedPreferencesProvider)),
);

final callLogProvider = NotifierProvider<CallLogController, List<CallLogEntry>>(
  CallLogController.new,
);

/// Anzahl verpasster Anrufe seit dem letzten Öffnen der Anrufliste.
final unseenMissedProvider = Provider<int>((ref) {
  final entries = ref.watch(callLogProvider);
  final seen = ref.watch(callLogProvider.notifier).seenAt;
  return entries.where((e) => e.isMissed && e.startedAt.isAfter(seen)).length;
});

class CallLogController extends Notifier<List<CallLogEntry>> {
  CallLogRepository get _repo => ref.read(callLogRepositoryProvider);
  late DateTime _seenAt;

  DateTime get seenAt => _seenAt;

  @override
  List<CallLogEntry> build() {
    _seenAt = _repo.seenAt;
    return _repo.load();
  }

  void add(CallLogEntry entry) {
    state = [entry, ...state].take(CallLogRepository.maxEntries).toList();
    _repo.save(state);
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
    _repo.save(state);
  }

  void clear() {
    state = const [];
    _repo.save(state);
  }

  void markSeen() {
    // Nur schreiben, wenn sich am Badge wirklich etwas ändert – jeder
    // Schreibzugriff schreibt die komplette Einstellungsdatei neu.
    if (!state.any((e) => e.isMissed && e.startedAt.isAfter(_seenAt))) return;
    _seenAt = DateTime.now();
    _repo.markSeen();
    // Neue Liste erzwingt Neuberechnung des Badges.
    state = [...state];
  }
}

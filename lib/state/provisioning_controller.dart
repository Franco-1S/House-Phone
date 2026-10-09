import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/provisioning.dart';
import 'account_controller.dart';
import 'providers.dart';

final provisioningRepositoryProvider = Provider<ProvisioningRepository>(
  (ref) => ProvisioningRepository(ref.watch(sharedPreferencesProvider)),
);

/// Leitungen + Team-Verzeichnis vom Server (oder leer bei manueller Einrichtung).
final provisioningProvider =
    NotifierProvider<ProvisioningController, Provisioning>(
      ProvisioningController.new,
    );

class ProvisioningController extends Notifier<Provisioning> {
  ProvisioningRepository get _repo => ref.read(provisioningRepositoryProvider);

  @override
  Provisioning build() => _repo.load() ?? const Provisioning();

  /// Löst einen Einrichtungscode ein: Zugangsdaten speichern (→ Neu-
  /// Registrierung) und Leitungen/Verzeichnis übernehmen.
  /// Wirft [FormatException] bei ungültigem Code.
  Future<SetupCode> redeem(String code) async {
    final parsed = SetupCode.parse(code);
    await _repo.save(parsed.provisioning);
    await _repo.setSelectedLine(null); // Standard-Leitung des neuen Geräts
    state = parsed.provisioning;
    ref.invalidate(selectedLineProvider);
    await ref.read(accountProvider.notifier).save(parsed.account);
    return parsed;
  }

  /// Bei manueller Einrichtung gibt es keine Leitungen/Verzeichnis vom Server.
  Future<void> clear() async {
    await _repo.clear();
    state = const Provisioning();
    ref.invalidate(selectedLineProvider);
  }
}

/// Ausgewählte Leitung für ausgehende Anrufe (`null` = Server-Standard).
final selectedLineProvider = NotifierProvider<SelectedLineController, String?>(
  SelectedLineController.new,
);

class SelectedLineController extends Notifier<String?> {
  @override
  String? build() {
    final prov = ref.watch(provisioningProvider);
    final stored = ref.read(provisioningRepositoryProvider).selectedLine;
    if (prov.line(stored) != null) return stored;
    return prov.defaultLine ??
        (prov.lines.isEmpty ? null : prov.lines.first.id);
  }

  Future<void> select(String id) async {
    state = id;
    await ref.read(provisioningRepositoryProvider).setSelectedLine(id);
  }
}

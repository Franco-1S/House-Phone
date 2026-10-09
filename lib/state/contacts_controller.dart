import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/contacts.dart';
import 'providers.dart';
import 'provisioning_controller.dart';

final contactsProvider = NotifierProvider<ContactsController, List<Contact>>(
  ContactsController.new,
);

/// Nachschlagewerk Nummer → Kontakt, neu berechnet bei jeder Änderung.
final contactBookProvider = Provider<ContactBook>((ref) {
  // Interne Durchwahlen vom Server zählen wie Kontakte (Name bei Anrufen).
  final team = ref.watch(provisioningProvider).directory;
  return ContactBook([
    ...ref.watch(contactsProvider),
    for (final t in team)
      Contact(
        id: 'team-${t.extension}',
        name: t.name,
        numbers: [ContactNumber(number: t.extension, label: 'internal')],
      ),
  ]);
});

/// Das Telefonbuch, alphabetisch sortiert und lokal gespeichert.
class ContactsController extends Notifier<List<Contact>> {
  ContactsRepository get _repo =>
      ContactsRepository(ref.read(sharedPreferencesProvider));

  @override
  List<Contact> build() => _sorted(_repo.load());

  static List<Contact> _sorted(Iterable<Contact> list) =>
      [...list]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<void> _commit(List<Contact> next) async {
    state = _sorted(next);
    await _repo.save(state);
  }

  /// Neu anlegen oder (gleiche ID) aktualisieren.
  Future<void> upsert(Contact c) =>
      _commit([...state.where((x) => x.id != c.id), c]);

  Future<void> delete(String id) =>
      _commit(state.where((x) => x.id != id).toList());

  Future<void> toggleFavorite(String id) => _commit([
    for (final c in state) c.id == id ? c.copyWith(favorite: !c.favorite) : c,
  ]);

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}

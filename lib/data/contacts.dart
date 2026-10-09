import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Art einer Rufnummer. Gespeichert wird der sprachneutrale Name.
enum NumberLabel {
  mobile,
  landline,
  work,
  internal,
  other;

  /// Liest auch ältere, deutsch gespeicherte Bezeichnungen.
  static NumberLabel parse(String raw) {
    const legacy = {
      'Mobil': mobile,
      'Festnetz': landline,
      'Arbeit': work,
      'Intern': internal,
      'Sonstige': other,
    };
    return legacy[raw] ??
        values.firstWhere((l) => l.name == raw, orElse: () => other);
  }
}

class ContactNumber {
  const ContactNumber({required this.number, this.label = 'mobile'});

  final String number;
  final String label;

  Map<String, Object?> toJson() => {'n': number, 'l': label};

  factory ContactNumber.fromJson(Map<String, Object?> j) => ContactNumber(
    number: j['n'] as String? ?? '',
    label: NumberLabel.parse(j['l'] as String? ?? 'mobile').name,
  );
}

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.numbers,
    this.favorite = false,
  });

  final String id;
  final String name;
  final List<ContactNumber> numbers;
  final bool favorite;

  String get primaryNumber => numbers.isEmpty ? '' : numbers.first.number;

  String get initials {
    // Nur Buchstaben/Ziffern zählen: "Anna (Empfang)" → AE, "Büro-PC" → BP.
    final parts = name
        .split(RegExp(r'[\s\-_/]+'))
        .map((p) => p.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => _first(p).toUpperCase()).join();
  }

  /// Anfangsbuchstabe für die alphabetische Gruppierung.
  String get letter {
    final n = name.trim();
    if (n.isEmpty) return '#';
    final c = _first(n).toUpperCase();
    const umlauts = {'Ä': 'A', 'Ö': 'O', 'Ü': 'U'};
    final mapped = umlauts[c] ?? c;
    return RegExp(r'[A-Z]').hasMatch(mapped) ? mapped : '#';
  }

  Contact copyWith({
    String? name,
    List<ContactNumber>? numbers,
    bool? favorite,
  }) => Contact(
    id: id,
    name: name ?? this.name,
    numbers: numbers ?? this.numbers,
    favorite: favorite ?? this.favorite,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'fav': favorite,
    'nums': numbers.map((n) => n.toJson()).toList(),
  };

  factory Contact.fromJson(Map<String, Object?> j) => Contact(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    favorite: j['fav'] as bool? ?? false,
    numbers: ((j['nums'] as List?) ?? const [])
        .cast<Map<String, Object?>>()
        .map(ContactNumber.fromJson)
        .toList(),
  );
}

/// Erstes Zeichen als ganzer Unicode-Codepoint (Umlaute/Emojis bleiben heil).
String _first(String s) => String.fromCharCodes(s.runes.take(1));

/// Vergleichbare Form einer Rufnummer: ohne Leerzeichen/Trennzeichen,
/// internationale deutsche Vorwahl (+49 / 0049) wird zur führenden 0.
String normalizeNumber(String raw) {
  var n = raw.replaceAll(RegExp(r'[^0-9*#+]'), '');
  if (n.startsWith('+49')) n = '0${n.substring(3)}';
  if (n.startsWith('0049')) n = '0${n.substring(4)}';
  return n;
}

/// Schnelles Nachschlagen: Nummer → Kontakt.
class ContactBook {
  ContactBook(this.contacts) {
    for (final c in contacts) {
      for (final n in c.numbers) {
        final key = normalizeNumber(n.number);
        if (key.isNotEmpty) _byNumber.putIfAbsent(key, () => (c, n));
      }
    }
  }

  final List<Contact> contacts;
  final _byNumber = <String, (Contact, ContactNumber)>{};

  (Contact, ContactNumber)? lookup(String number) {
    final key = normalizeNumber(number);
    if (key.isEmpty) return null;
    return _byNumber[key];
  }

  String? nameFor(String number) => lookup(number)?.$1.name;

  /// Kontakte, deren Nummer mit der Eingabe beginnt (für das Wählfeld).
  List<(Contact, ContactNumber)> startingWith(String typed, {int max = 3}) {
    final key = normalizeNumber(typed);
    if (key.length < 3) return const [];
    final out = <(Contact, ContactNumber)>[];
    for (final e in _byNumber.entries) {
      if (e.key.startsWith(key)) out.add(e.value);
      if (out.length >= max) break;
    }
    return out;
  }
}

class ContactsRepository {
  ContactsRepository(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'contacts.v1';

  List<Contact> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, Object?>>()
          .map(Contact.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<Contact> contacts) => _prefs.setString(
    _key,
    jsonEncode(contacts.map((c) => c.toJson()).toList()),
  );
}

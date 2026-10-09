import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sip_account.dart';

/// Eine Rufnummer der Anlage (z. B. "Privat", "Firma").
class PhoneLine {
  const PhoneLine({required this.id, required this.label, this.number = ''});

  final String id;
  final String label;
  final String number;

  Map<String, Object?> toJson() => {'id': id, 'label': label, 'number': number};

  factory PhoneLine.fromJson(Map<String, Object?> j) => PhoneLine(
    id: j['id'] as String,
    label: (j['label'] as String?) ?? j['id'] as String,
    number: (j['number'] as String?) ?? '',
  );
}

/// Interner Teilnehmer: Gerät/Mitarbeiter oder Gruppe mit Durchwahl.
class DirectoryEntry {
  const DirectoryEntry({
    required this.name,
    required this.extension,
    this.isGroup = false,
  });

  final String name;
  final String extension;
  final bool isGroup;

  Map<String, Object?> toJson() => {
    'name': name,
    'ext': extension,
    'kind': isGroup ? 'group' : 'device',
  };

  factory DirectoryEntry.fromJson(Map<String, Object?> j) => DirectoryEntry(
    name: j['name'] as String? ?? '',
    extension: '${j['ext'] ?? ''}',
    isGroup: j['kind'] == 'group',
  );
}

/// Was der Server über dieses Gerät weiß (aus dem Einrichtungscode).
class Provisioning {
  const Provisioning({
    this.office = false,
    this.deviceName = '',
    this.extension = '',
    this.lines = const [],
    this.defaultLine,
    this.directory = const [],
  });

  final bool office;
  final String deviceName;
  final String extension;
  final List<PhoneLine> lines;
  final String? defaultLine;
  final List<DirectoryEntry> directory;

  bool get hasMultipleLines => lines.length > 1;

  PhoneLine? line(String? id) {
    for (final l in lines) {
      if (l.id == id) return l;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'office': office,
    'name': deviceName,
    'ext': extension,
    'lines': lines.map((l) => l.toJson()).toList(),
    'line': defaultLine,
    'dir': directory.map((d) => d.toJson()).toList(),
  };

  factory Provisioning.fromJson(Map<String, Object?> j) => Provisioning(
    office: j['office'] as bool? ?? false,
    deviceName: j['name'] as String? ?? '',
    extension: '${j['ext'] ?? ''}',
    lines: ((j['lines'] as List?) ?? const [])
        .cast<Map<String, Object?>>()
        .map(PhoneLine.fromJson)
        .toList(),
    defaultLine: j['line'] as String?,
    directory: ((j['dir'] as List?) ?? const [])
        .cast<Map<String, Object?>>()
        .map(DirectoryEntry.fromJson)
        .toList(),
  );
}

/// Ergebnis eines eingelösten Einrichtungscodes.
class SetupCode {
  const SetupCode(this.account, this.provisioning);
  final SipAccount account;
  final Provisioning provisioning;

  static const prefix = 'HT1.';

  /// Liest einen Code wie `HT1.eyJ2Ijox...` (vom Server-Generator erzeugt).
  /// Wirft [FormatException] bei ungültigen Codes.
  static SetupCode parse(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'\s+'), '');
    final start = text.indexOf(prefix);
    if (start < 0) {
      throw const FormatException('Not a Haustelefon setup code');
    }
    var data = text.substring(start + prefix.length);
    data += '=' * ((4 - data.length % 4) % 4);
    final Map<String, Object?> j;
    try {
      j =
          jsonDecode(utf8.decode(base64Url.decode(data)))
              as Map<String, Object?>;
    } catch (_) {
      throw const FormatException('Setup code is corrupt or incomplete');
    }
    if (j['v'] != 1) {
      throw const FormatException('Unsupported setup code version');
    }
    String req(String k) {
      final v = j[k];
      if (v is! String || v.isEmpty) {
        throw FormatException('Setup code lacks "$k"');
      }
      return v;
    }

    final account = SipAccount(
      transport: SipTransport.websocket,
      wsUrl: req('ws'),
      domain: req('domain'),
      port: 5060,
      username: req('user'),
      password: req('pass'),
      displayName: (j['name'] as String?) ?? '',
    );
    final prov = Provisioning.fromJson({
      'office': j['mode'] == 'office',
      'name': j['name'],
      'ext': j['ext'],
      'lines': j['lines'],
      'line': j['line'],
      'dir': j['dir'],
    });
    return SetupCode(account, prov);
  }
}

class ProvisioningRepository {
  ProvisioningRepository(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'provisioning.v1';
  static const _kLine = 'dial.line';

  Provisioning? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return Provisioning.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Provisioning p) =>
      _prefs.setString(_key, jsonEncode(p.toJson()));

  Future<void> clear() => _prefs.remove(_key);

  String? get selectedLine => _prefs.getString(_kLine);

  Future<void> setSelectedLine(String? id) =>
      id == null ? _prefs.remove(_kLine) : _prefs.setString(_kLine, id);
}

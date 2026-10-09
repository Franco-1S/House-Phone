import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

import 'package:haustelefon/core/format.dart';
import 'package:haustelefon/core/l10n.dart';
import 'package:haustelefon/data/audio_prefs.dart';
import 'package:haustelefon/services/ringtone_synth.dart';
import 'package:haustelefon/state/audio_settings_controller.dart';
import 'package:haustelefon/data/call_log.dart';
import 'package:haustelefon/data/contacts.dart';
import 'package:haustelefon/data/provisioning.dart';
import 'package:haustelefon/data/sip_account.dart';
import 'package:haustelefon/state/call_log_controller.dart';
import 'package:haustelefon/state/contacts_controller.dart';
import 'package:haustelefon/state/provisioning_controller.dart';
import 'package:haustelefon/state/dialer_controller.dart';
import 'package:haustelefon/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Passwörter landen im sicheren Speicher – im Test eine In-Memory-Attrappe.
  FlutterSecureStorage.setMockInitialValues({});

  group('DialerController', () {
    test('tippen, löschen, + per langem Druck auf 0', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final d = c.read(dialerProvider.notifier);

      d.append('0');
      d.replaceLast('+');
      for (final k in ['4', '9', '*', '*', '7', '1']) {
        d.append(k);
      }
      expect(c.read(dialerProvider), '+49**71');

      d.backspace();
      expect(c.read(dialerProvider), '+49**7');
      d.clear();
      expect(c.read(dialerProvider), '');
    });

    test('Maximallänge wird eingehalten', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final d = c.read(dialerProvider.notifier);
      for (var i = 0; i < 50; i++) {
        d.append('1');
      }
      expect(c.read(dialerProvider).length, DialerController.maxLength);
    });
  });

  group('SipAccount', () {
    test('Speedport-Daten: Nutzerkennung + Authentifizierungsname', () {
      const a = SipAccount(
        transport: SipTransport.tcp,
        wsUrl: '',
        domain: 'speedport.ip',
        port: 5060,
        username: '**71',
        authUser: 'nutzer-1@speedport.ip',
        password: 'x',
      );
      expect(a.isComplete, isTrue);
      expect(a.identity, '**71@speedport.ip');
      expect(a.effectiveAuthUser, 'nutzer-1@speedport.ip');
    });

    test('Auth-Benutzer fällt auf Benutzername zurück', () {
      final a = SipAccount.defaults().copyWith(
        username: 'handy',
        password: 'x',
      );
      expect(a.effectiveAuthUser, 'handy');
      expect(a.isComplete, isTrue);
    });
  });

  group('Anrufliste', () {
    test('JSON-Roundtrip und Persistenz', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);

      final entry = CallLogEntry(
        id: '1',
        number: '**1',
        displayName: 'Wohnzimmer',
        incoming: true,
        outcome: CallOutcome.missed,
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      c.read(callLogProvider.notifier).add(entry);
      expect(c.read(unseenMissedProvider), 1);

      final restored = CallLogRepository(prefs).load().single;
      expect(restored.number, '**1');
      expect(restored.outcome, CallOutcome.missed);
      expect(
        restored.startedAt.millisecondsSinceEpoch,
        entry.startedAt.millisecondsSinceEpoch,
      );

      c.read(callLogProvider.notifier).markSeen();
      expect(c.read(unseenMissedProvider), 0);
    });
  });

  group('Fmt', () {
    test('Tage, Uhrzeit, Dauer', () {
      final now = DateTime(2026, 10, 8, 12);
      final de = lookupAppLocalizations(const Locale('de'));
      final en = lookupAppLocalizations(const Locale('en'));
      expect(Fmt.day(DateTime(2026, 10, 8, 9), de, now), 'Heute');
      expect(Fmt.day(DateTime(2026, 10, 7, 23), de, now), 'Gestern');
      expect(Fmt.day(DateTime(2026, 10, 5), de, now), 'Montag');
      expect(Fmt.day(DateTime(2026, 9, 1), de, now), '01.09.2026');
      expect(Fmt.day(DateTime(2026, 10, 7), en, now), 'Yesterday');
      expect(Fmt.day(DateTime(2026, 10, 5), en, now), 'Monday');
      expect(Fmt.day(DateTime(2026, 9, 1), en, now), '2026-09-01');
      expect(Fmt.time(DateTime(2026, 1, 1, 7, 5)), '07:05');
      expect(Fmt.duration(const Duration(seconds: 42)), '0:42');
      expect(Fmt.duration(const Duration(minutes: 61, seconds: 3)), '1:01:03');
    });
  });

  group('Audio', () {
    test('Klingeltöne sind gültige WAV-Dateien', () {
      for (final r in Ringtone.values) {
        final wav = RingtoneSynth.wav(r, 0.8);
        final b = ByteData.sublistView(wav);
        expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
        expect(b.getUint32(40, Endian.little), wav.length - 44);
        expect(wav.length, greaterThan(44));
      }
    });

    test('Lautstärke 0 ergibt Stille', () {
      final wav = RingtoneSynth.wav(Ringtone.classic, 0);
      expect(wav.sublist(44).every((x) => x == 0), isTrue);
    });

    test('Audio-Einstellungen werden gespeichert', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);

      await c
          .read(audioPrefsProvider.notifier)
          .update(
            (p) => p.copyWith(
              callVolume: 1.5,
              ringtone: Ringtone.soft,
              ringVolume: 0.3,
            ),
          );
      final loaded = AudioPrefsRepository(prefs).load();
      expect(loaded.callVolume, 1.5);
      expect(loaded.ringtone, Ringtone.soft);
      expect(loaded.ringVolume, 0.3);
      expect(loaded.inputId, '');
    });
  });

  group('Kontakte', () {
    test('Nummern werden vergleichbar gemacht', () {
      expect(normalizeNumber('+49 170 / 123-45 67'), '01701234567');
      expect(normalizeNumber('0049 89 12345'), '08912345');
      expect(normalizeNumber('**71'), '**71');
    });

    test('Telefonbuch findet Kontakte unabhängig vom Format', () {
      final book = ContactBook([
        const Contact(
          id: '1',
          name: 'Mama',
          numbers: [ContactNumber(number: '+49 30 1234567')],
        ),
        const Contact(
          id: '2',
          name: 'Wohnzimmer',
          numbers: [ContactNumber(number: '**1', label: 'Intern')],
        ),
      ]);
      expect(book.nameFor('0301234567'), 'Mama');
      expect(book.nameFor('**1'), 'Wohnzimmer');
      expect(book.nameFor('0301234568'), isNull);
      expect(book.startingWith('0301').single.$1.name, 'Mama');
      expect(book.startingWith('03'), isEmpty); // erst ab 3 Ziffern
    });

    test('Initialen und Buchstaben-Gruppe', () {
      const c = Contact(id: '1', name: 'özil mesut', numbers: []);
      expect(c.initials, 'ÖM');
      expect(
        const Contact(id: 'x', name: 'Anna (Empfang)', numbers: []).initials,
        'AE',
      );
      expect(
        const Contact(id: 'y', name: 'Büro-PC', numbers: []).initials,
        'BP',
      );
      expect(c.letter, 'O');
      expect(const Contact(id: '2', name: '42 Pizza', numbers: []).letter, '#');
    });

    test('Speichern, Sortieren, Favorit, Löschen', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      final ctrl = c.read(contactsProvider.notifier);

      await ctrl.upsert(
        const Contact(
          id: 'b',
          name: 'Zoe',
          numbers: [ContactNumber(number: '0170')],
        ),
      );
      await ctrl.upsert(
        const Contact(
          id: 'a',
          name: 'anna',
          numbers: [ContactNumber(number: '0171')],
        ),
      );
      expect(c.read(contactsProvider).map((x) => x.name), ['anna', 'Zoe']);

      await ctrl.toggleFavorite('b');
      expect(c.read(contactsProvider).last.favorite, isTrue);

      final reloaded = ContactsRepository(prefs).load();
      expect(reloaded.length, 2);
      expect(reloaded.firstWhere((x) => x.id == 'b').favorite, isTrue);

      await ctrl.delete('a');
      expect(c.read(contactsProvider).single.name, 'Zoe');
      expect(c.read(contactBookProvider).nameFor('0170'), 'Zoe');
    });
  });

  group('Einrichtungscode', () {
    // Erzeugt mit server/generator/generate.py aus haustelefon.example.yaml
    // (Gerät "handy"). Sichert das Format zwischen Server und App ab.
    const fixture =
        'HT1.eyJ2IjoxLCJtb2RlIjoiaG9tZSIsIndzIjoid3M6Ly8xOTIuMTY4LjIuNTA6ODA4OC93cyIsImRvbWFpbiI6IjE5Mi4xNjguMi41MCIsInVzZXIiOiJoYW5keSIsInBhc3MiOiJ0ZXN0LXBhc3MtaGFuZHkiLCJuYW1lIjoiSGFuZHkiLCJleHQiOiIxMCIsImxpbmUiOiJwcml2YXQiLCJsaW5lcyI6W3siaWQiOiJwcml2YXQiLCJsYWJlbCI6IlByaXZhdCIsIm51bWJlciI6Iis0OSAzMCAxMTExMTExIn0seyJpZCI6ImZpcm1hIiwibGFiZWwiOiJGaXJtYSIsIm51bWJlciI6Iis0OSAzMCAyMjIyMjIyIn1dLCJkaXIiOlt7Im5hbWUiOiJCw7xyby1QQyIsImV4dCI6IjExIiwia2luZCI6ImRldmljZSJ9LHsibmFtZSI6IkFubmEgKEVtcGZhbmcpIiwiZXh0IjoiMTIiLCJraW5kIjoiZGV2aWNlIn0seyJuYW1lIjoiQsO8cm8iLCJleHQiOiIyMCIsImtpbmQiOiJncm91cCJ9XX0';

    test('Code vom Server wird vollständig gelesen', () {
      final r = SetupCode.parse(fixture);
      expect(r.account.username, 'handy');
      expect(r.account.password, 'test-pass-handy');
      expect(r.account.wsUrl, 'ws://192.168.2.50:8088/ws');
      expect(r.account.domain, '192.168.2.50');
      expect(r.account.isComplete, isTrue);
      final p = r.provisioning;
      expect(p.extension, '10');
      expect(p.defaultLine, 'privat');
      expect(p.lines.map((l) => l.label), ['Privat', 'Firma']);
      expect(p.directory.map((d) => d.name), [
        'Büro-PC',
        'Anna (Empfang)',
        'Büro',
      ]);
      expect(p.directory.last.isGroup, isTrue);
    });

    test('Leerzeichen/Zeilenumbrüche und Text drumherum stören nicht', () {
      final wrapped =
          'Hier dein Code:\n${fixture.substring(0, 40)}\n  '
          '${fixture.substring(40)}  ';
      expect(SetupCode.parse(wrapped).account.username, 'handy');
    });

    test('Kaputte Codes werden verständlich abgelehnt', () {
      expect(() => SetupCode.parse('hallo'), throwsFormatException);
      expect(() => SetupCode.parse('HT1.@@@'), throwsFormatException);
    });

    test('Einlösen speichert Leitungen, Team und Konto', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);

      await c.read(provisioningProvider.notifier).redeem(fixture);
      expect(c.read(selectedLineProvider), 'privat');
      await c.read(selectedLineProvider.notifier).select('firma');
      expect(c.read(selectedLineProvider), 'firma');
      // Team-Durchwahlen werden wie Kontakte aufgelöst.
      expect(c.read(contactBookProvider).nameFor('12'), 'Anna (Empfang)');
      // Nach Neustart (frisches Laden) bleibt alles erhalten.
      expect(ProvisioningRepository(prefs).load()!.lines.length, 2);
      expect(ProvisioningRepository(prefs).selectedLine, 'firma');
    });
  });
}

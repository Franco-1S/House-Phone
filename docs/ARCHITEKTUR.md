# Architektur

## Überblick

```
 ┌──────────── App (Flutter) ────────────┐        ┌────────── Server ───────────┐
 │ UI ─▶ State (Riverpod) ─▶ Services    │  WS +  │ haustelefon.yaml            │
 │        │                    │         │ WebRTC │      │ Generator (Python)  │
 │        │            SipService (sip_ua)├───────▶│      ▼                      │
 │        │            AudioService      │        │ Asterisk (Docker)           │
 │  l10n (ARB, de/en)   BackgroundService │        │  Geräte ─ Wählplan ─ Leitungen│
 └────────────────────────────────────────┘        └──────────────┬──────────────┘
                                                                  │ SIP/RTP
                                                       Router (Speedport, …)
```

## Server

`server/generator/generate.py` liest `haustelefon.yaml`, prüft sie und schreibt
`generated/asterisk/*.conf` sowie `generated/provisioning/<gerät>.txt`.

| Begriff | Asterisk-Objekte |
|---|---|
| **Leitung** (Rufnummer) | `line-<id>-auth`, `line-<id>-reg` (Anmeldung mit `line=yes`), Endpoint + AOR `line-<id>`, Kontext `line-in-<id>` |
| **Gerät** (App-Installation) | WebRTC-Endpoint + AOR `<id>` (`webrtc=yes`, max. ein Kontakt), Kontext `dev-<id>` |
| **Gruppe** | Durchwahl in jedem Geräte-Kontext, die alle Mitglieder anruft |

**Eingehend.** Der Router stellt die Anrufe jeder Nummer an deren eigene
Anmeldung zu. Über `line=yes` ordnet Asterisk den Anruf `line-<id>` zu; entfernt
ein Router diesen Parameter, verteilt der Fallback (`speedport-in` →
`from-speedport`) nach Request-URI bzw. angerufener Nummer. `line-in-<id>` ruft
die konfigurierten Geräte an und setzt per Pre-Dial-Handler
`X-Haustelefon-Line: <id>` – so zeigt die App, welche Nummer angerufen wurde.

**Ausgehend.** Die App schickt `X-Haustelefon-Line: <id>` im INVITE mit.
`dev-<id>` liest den Header und springt nur zu Leitungen, die das Gerät nutzen
darf; sonst gilt die Standard-Leitung des Geräts. Interne Durchwahlen sind
exakte Treffer im selben Kontext und haben deshalb immer Vorrang vor dem Muster
für externe Nummern. Durchwahlen, die mit Not-/Servicerufnummern kollidieren
(110, 112, 115, 116…, 118…), lehnt der Generator ab.

**Passwörter.** `password: auto` erzeugt einmalig ein zufälliges Passwort und
merkt es in `secrets.yaml` – erneutes Generieren bleibt stabil.

**Prüfung.** `server/tests/validate_asterisk.sh` startet einen echten Asterisk
mit der Beispielkonfiguration und prüft Endpunkte, Anmeldungen, Wählplan und ein
fehlerfreies Log – in der CI bei jedem Push.

## Einrichtungscodes

`HT1.<base64url(JSON)>` mit Server-URL, Zugangsdaten, Durchwahl, den Leitungen
des Geräts, Standard-Leitung und dem Verzeichnis der übrigen Durchwahlen/Gruppen.
`SetupCode.parse` (`lib/data/provisioning.dart`) ist per Fixture-Test an den
Generator gekoppelt.

## App

| Schicht | Ordner | Aufgabe |
|---|---|---|
| Daten | `lib/data` | Modelle + Speicherung (SharedPreferences, Passwort in Keychain/Keystore/DPAPI) |
| Services | `lib/services` | Dünne Hüllen um Plattform-APIs: `SipService`, `AudioService`, `BackgroundService` (Android), `DesktopShell` (Windows-FFI), `TrayService` (Infobereich), `MicTest` |
| State | `lib/state` | Riverpod-Notifier: Verbindung, Anruf, Anrufliste, Kontakte, Leitungen, Audio, Sprache |
| UI | `lib/ui` | Wählfeld, Anruf-Bildschirm, Anrufliste, Kontakte, Einstellungen, Assistent |
| Core | `lib/core` | Theme, Haptik, Übergänge, Formatierung, l10n-Helfer |

**Zustände statt Texte.** Controller liefern Enums (`LinkDetail`,
`CallEndReason` …), die Oberfläche übersetzt sie über `lib/core/l10n.dart` –
ein Sprachwechsel greift sofort überall.

**Plattformen.**
- *Android*: `KeepAliveService` (Vordergrund-Dienst) hält den Prozess wach,
  `CallNotifications` zeigt eingehende Anrufe auch auf dem Sperrbildschirm.
- *Windows*: nur eine Instanz (Mutex in `windows/runner/main.cpp`), Klingelton
  per `PlaySound`, blinkende Taskleiste per `FlashWindowEx` (Dart-FFI),
  Geräteauswahl über flutter_webrtc; `flutter_secure_storage` als reine
  DPAPI-Variante (`third_party/`), daher ohne C++-ATL. Das Infobereich-Symbol
  steckt im C++-Runner (`Shell_NotifyIcon` in `windows/runner/flutter_window.cpp`);
  `TrayService` spricht über den Kanal `de.haustelefon/tray` mit ihm (Texte,
  Online-Punkt, Schließen in den Infobereich, Autostart über `HKCU\…\Run`
  mit `--minimized`).
- *iOS*: im Vordergrund voll nutzbar; Klingeln im Hintergrund bräuchte PushKit/CallKit.

# Architecture

## Overview

```
 ┌──────────── App (Flutter) ────────────┐        ┌────────── Server ───────────┐
 │ UI ─▶ state (Riverpod) ─▶ services    │  WS +  │ haustelefon.yaml            │
 │        │                    │         │ WebRTC │      │ generator (Python)  │
 │        │            SipService (sip_ua)├───────▶│      ▼                      │
 │        │            AudioService      │        │ Asterisk (Docker)           │
 │  l10n (ARB, de/en)   BackgroundService │        │  devices ─ dialplan ─ lines │
 └────────────────────────────────────────┘        └──────────────┬──────────────┘
                                                                  │ SIP/RTP
                                                       Router (Speedport, …)
```

## Server

`server/generator/generate.py` reads `haustelefon.yaml`, validates it and writes
`generated/asterisk/*.conf` plus `generated/provisioning/<device>.txt`.

| Concept | Asterisk objects |
|---|---|
| **Line** (phone number) | `line-<id>-auth`, `line-<id>-reg` (registration with `line=yes`), endpoint + AOR `line-<id>`, context `line-in-<id>` |
| **Device** (app installation) | WebRTC endpoint + AOR `<id>` (`webrtc=yes`, max one contact), context `dev-<id>` |
| **Group** | an extension in every device context that dials all members |

**Inbound routing.** The router delivers each line's calls to that line's
registration. `line=yes` lets Asterisk match the call to `line-<id>`; if a router
strips that parameter, the identify fallback (`speedport-in` → `from-speedport`)
dispatches by request-URI user / called number. `line-in-<id>` dials the
configured devices with a pre-dial handler that adds `X-Haustelefon-Line: <id>`,
so the app can show which number was called.

**Outbound routing.** The app sends `X-Haustelefon-Line: <id>` with the INVITE.
`dev-<id>` reads the header and only jumps to lines that device is allowed to
use; anything else falls back to the device's default line. Internal extensions
are exact matches in the same context, so they always win over the external
pattern. Extensions colliding with emergency/service numbers (110, 112, 115,
116…, 118…) are rejected by the validator.

**Secrets.** `password: auto` creates a random device password once and keeps it
in `secrets.yaml`, so re-running the generator is stable.

**Validation.** `server/tests/validate_asterisk.sh` boots a real Asterisk with
the example configuration and checks endpoints, registrations, dialplan routing
and a clean log – in CI on every push.

## Setup codes

`HT1.<base64url(JSON)>` with server URL, credentials, extension, the device's
lines (`id`, `label`, `number`), default line and the directory of other
extensions/groups. `SetupCode.parse` in `lib/data/provisioning.dart` is pinned to
the generator by a fixture test (`test/app_test.dart`).

## App

| Layer | Folder | Responsibility |
|---|---|---|
| Data | `lib/data` | Models + persistence (`SharedPreferences`, password in Keychain/Keystore/DPAPI) |
| Services | `lib/services` | Thin wrappers around platform APIs: `SipService` (sip_ua → streams), `AudioService`, `BackgroundService` (Android), `DesktopShell` (Windows FFI), `TrayService` (Windows notification area), `MicTest` |
| State | `lib/state` | Riverpod notifiers: connection, call, call log, contacts, provisioning/lines, audio, language |
| UI | `lib/ui` | Dialer, call screen, history, contacts, settings, setup wizard |
| Core | `lib/core` | Theme, haptics, transitions, formatting, l10n helpers |

**States, not strings.** Controllers expose enums (`LinkDetail`,
`CallEndReason`, …); widgets translate them with `lib/core/l10n.dart`, so
switching the language updates everything immediately. Notifications use
`l10nProvider`.

**Call flow.** `sip_ua` events → `SipService.callEvents` → `CallController`
(phase, mute/hold/speaker, DTMF, levels from WebRTC stats, call-log entry) →
`HaustelefonApp` opens/closes the call screen with a circular reveal.

**Platform specifics.**
- *Android*: `KeepAliveService` (foreground service, `specialUse`) keeps the
  process alive; `CallNotifications` shows full-screen incoming calls.
- *Windows*: single instance (named mutex in `windows/runner/main.cpp`),
  ringtone via `PlaySound` and taskbar flashing via `FlashWindowEx` (Dart FFI),
  audio device selection through flutter_webrtc. `flutter_secure_storage` uses a
  Dart-only DPAPI implementation (`third_party/`) so no C++ ATL is required.
  The notification-area icon lives in the C++ runner (`Shell_NotifyIcon` in
  `windows/runner/flutter_window.cpp`); `TrayService` talks to it over the
  method channel `de.haustelefon/tray` (texts, online dot, close-to-tray,
  autostart via `HKCU\…\Run` with `--minimized`).
- *iOS*: works in the foreground; background ringing needs PushKit/CallKit.

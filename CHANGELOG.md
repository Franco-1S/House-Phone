# Changelog

## 1.0.0 – first public release

### Phone system (server)
- One `haustelefon.yaml` describes lines (phone numbers), devices/extensions and
  groups; a generator turns it into a complete Asterisk configuration.
- Multiple phone numbers: every number is its own registration at the router,
  so incoming calls ring the right devices and outgoing calls use the chosen number.
- Internal extensions and ring groups (e.g. `10`, `11`, `20`).
- Per-device setup codes – paste into the app, done.
- `./setup.sh` installs Docker if needed, generates everything and starts Asterisk.
- Validation with clear error messages (duplicate extensions, emergency-number
  collisions, unknown devices, missing passwords …).

### App (Android, iOS, Windows)
- Dialer, in-call screen with live voice levels, incoming-call screen.
- Outgoing number picker; incoming calls show which number was called.
- Call history, contacts with favourites, team directory from the server.
- Setup wizard (setup code or manual).
- German and English UI, switchable in the settings.
- Android: foreground service to stay reachable, call notifications.
- Windows: keyboard control, device selection, microphone test, ringtones,
  single instance, taskbar flashing on incoming calls.
- Windows: icon in the notification area with online/offline dot – closing the
  window keeps the app running and reachable; optional start with Windows
  (starts hidden); missed calls as Windows notification.
- Ready-made downloads: signed Android APK, portable Windows zip with
  installer (no admin rights), server package.

# Contributing

Thanks for helping! Bug reports, router compatibility reports and pull requests
are all welcome.

## Before you open a pull request

```bash
flutter pub get
dart format lib/app.dart lib/main.dart lib/core lib/data lib/services lib/state lib/ui test
flutter analyze
flutter test
cd server && python -m unittest discover -s generator
bash server/tests/validate_asterisk.sh   # needs Docker
```

CI runs the same checks plus Android and Windows builds.

## Guidelines

- **UI texts** live in `lib/l10n/app_en.arb` and `app_de.arb` – never hard-code
  strings in widgets. Run `flutter gen-l10n` after editing the ARB files.
- **Controllers produce states, not text** (e.g. `LinkDetail`, `CallEndReason`);
  widgets translate them via `lib/core/l10n.dart`.
- **Server changes** go into `server/generator/generate.py` together with a test
  in `test_generate.py`; never edit generated Asterisk files by hand.
- The setup-code format is a contract between server and app – if you change it,
  bump the version (`HT1.` → `HT2.`) and update the fixture test in
  `test/app_test.dart`.

## Reporting a router

Please include the router model and firmware, whether `./setup.sh status` shows
the lines as `Registered`, and whether inbound/outbound calls work per line.

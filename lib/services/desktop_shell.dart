/// Windows-Funktionen für Klingelton und Fenster-Aufmerksamkeit.
/// Auf Plattformen ohne `dart:ffi` (Web-Vorschau) ein No-op.
library;

export 'desktop_shell_stub.dart' if (dart.library.ffi) 'desktop_shell_ffi.dart';

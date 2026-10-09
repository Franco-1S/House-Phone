// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get addContact => 'Kontakt hinzufügen';

  @override
  String get addNumber => 'Weitere Nummer';

  @override
  String get appTitle => 'Haustelefon';

  @override
  String get atLeastOneNumber => 'Mindestens eine Nummer';

  @override
  String get audio => 'Audio';

  @override
  String get audioAndRingtone => 'Audio & Klingelton';

  @override
  String get audioCardSubtitle =>
      'Mikrofon, Lautsprecher, Lautstärke, Klingelton';

  @override
  String get authName => 'Authentifizierungsname';

  @override
  String get authNameHint => 'z. B. nutzer-1@speedport.ip';

  @override
  String get authUserHint => 'leer = Benutzername';

  @override
  String get authUserOptional => 'Auth-Benutzer (optional)';

  @override
  String get autostart => 'Mit Windows starten';

  @override
  String get autostartHint => 'Startet unsichtbar im Infobereich';

  @override
  String get back => 'Zurück';

  @override
  String get btnAnswer => 'Annehmen';

  @override
  String get btnAudio => 'Audio';

  @override
  String get btnDecline => 'Ablehnen';

  @override
  String get btnHold => 'Halten';

  @override
  String get btnKeypad => 'Tastatur';

  @override
  String get btnMute => 'Stumm';

  @override
  String get btnResume => 'Fortsetzen';

  @override
  String get btnSpeaker => 'Lautsprecher';

  @override
  String get callDialing => 'Wählt';

  @override
  String get callHistory => 'Anrufliste';

  @override
  String get callIncoming => 'Eingehender Anruf';

  @override
  String get callOnHold => 'Gehalten';

  @override
  String get callRemoteHold => 'Von Gegenseite gehalten';

  @override
  String get callRinging => 'Klingelt';

  @override
  String get callVia => 'Anrufen über';

  @override
  String get callVolume => 'Gesprächslautstärke';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get changesSaved => 'Änderungen gespeichert';

  @override
  String get clear => 'Leeren';

  @override
  String get clearHistoryBody =>
      'Alle Einträge werden von diesem Gerät gelöscht.';

  @override
  String get clearHistoryTitle => 'Anrufliste leeren?';

  @override
  String get clearList => 'Liste leeren';

  @override
  String get closeToTray => 'Im Infobereich weiterlaufen';

  @override
  String get closeToTrayHint =>
      'Beim Schließen des Fensters bleibst du für Anrufe erreichbar';

  @override
  String get connectionType => 'Verbindungsart';

  @override
  String contactDeleted(String name) {
    return '$name gelöscht';
  }

  @override
  String contactSaved(String name) {
    return '$name gespeichert';
  }

  @override
  String get contacts => 'Kontakte';

  @override
  String get contactsEmptyBody => 'Leg deinen ersten Kontakt an.';

  @override
  String get contactsEmptyTitle => 'Noch keine Kontakte';

  @override
  String get credentials => 'Zugangsdaten';

  @override
  String get defaultLabel => 'Standard';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteContactBody => 'Der Kontakt wird von diesem Gerät entfernt.';

  @override
  String deleteContactTitle(String name) {
    return '$name löschen?';
  }

  @override
  String get detailAuthRejected => 'Benutzername oder Passwort abgelehnt';

  @override
  String get detailConnecting => 'Baue Verbindung auf …';

  @override
  String get detailDisconnected => 'Verbindung getrennt';

  @override
  String detailNoAnswer(String host) {
    return 'Keine Antwort von $host – VPN aktiv, Adresse richtig?';
  }

  @override
  String get detailNotFound => 'Nebenstelle unbekannt (404)';

  @override
  String get detailReady => 'Bereit für Anrufe';

  @override
  String detailRegistering(String host) {
    return 'Registriere bei $host …';
  }

  @override
  String get detailRetrying => 'neuer Versuch läuft automatisch';

  @override
  String get detailSetupHint =>
      'Tippe auf das Zahnrad, um deine Nebenstelle einzurichten.';

  @override
  String detailStartFailed(String error) {
    return 'Start fehlgeschlagen: $error';
  }

  @override
  String get detailStarting => 'Starte …';

  @override
  String get detailTimeout => 'Zeitüberschreitung – VPN/Adresse prüfen';

  @override
  String get detailUnreachable => 'Server nicht erreichbar – VPN aktiv?';

  @override
  String get detailUnregistered => 'Abgemeldet';

  @override
  String get directionIncoming => 'eingehend';

  @override
  String get directionOutgoing => 'ausgehend';

  @override
  String get displayNameHint => 'z. B. Handy';

  @override
  String get displayNameOptional => 'Anzeigename (optional)';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get editContact => 'Kontakt bearbeiten';

  @override
  String get endBusy => 'Besetzt';

  @override
  String get endCanceled => 'Abgebrochen';

  @override
  String get endConnectionLost => 'Verbindung verloren';

  @override
  String get endDeclined => 'Abgelehnt';

  @override
  String get endEnded => 'Anruf beendet';

  @override
  String endFailed(String code) {
    return 'Fehlgeschlagen ($code)';
  }

  @override
  String get endIncompatible =>
      'Audio inkompatibel – Gateway nötig (siehe Anleitung)';

  @override
  String get endIncomplete => 'Rufnummer unvollständig';

  @override
  String get endMissed => 'Verpasster Anruf';

  @override
  String get endNoAnswer => 'Keine Antwort';

  @override
  String get endNoMicrophone => 'Kein Zugriff aufs Mikrofon';

  @override
  String get endNotConnected => 'Nicht mit der Telefonanlage verbunden';

  @override
  String get endNotFound => 'Rufnummer nicht gefunden';

  @override
  String get endRejected => 'Anruf abgelehnt';

  @override
  String get endRtpTimeout => 'Kein Audio mehr empfangen';

  @override
  String get endUnauthorized => 'Nicht berechtigt';

  @override
  String get endUnavailable => 'Nicht erreichbar';

  @override
  String get enterNumber => 'Nummer eingeben';

  @override
  String extensionLabel(String ext) {
    return 'Durchwahl $ext';
  }

  @override
  String get extensionTitle => 'Nebenstelle';

  @override
  String get favorite => 'Favorit';

  @override
  String get favoriteHint => 'Erscheint oben in der Kontaktliste';

  @override
  String get filterAll => 'Alle';

  @override
  String get filterMissed => 'Verpasst';

  @override
  String filterMissedCount(int count) {
    return 'Verpasst ($count)';
  }

  @override
  String groupExtension(String ext) {
    return 'Gruppe · Durchwahl $ext';
  }

  @override
  String get hearMyself => 'Mich selbst hören';

  @override
  String get hearMyselfHint =>
      'Testet auch den Lautsprecher – Kopfhörer empfohlen';

  @override
  String get historyEmptyBody => 'Deine Gespräche erscheinen hier.';

  @override
  String get historyEmptyMissedBody => 'Alle Anrufe wurden angenommen.';

  @override
  String get historyEmptyMissedTitle => 'Nichts verpasst';

  @override
  String get historyEmptyTitle => 'Noch keine Anrufe';

  @override
  String get invalidPort => 'Ungültiger Port';

  @override
  String get labelInternal => 'Intern';

  @override
  String get labelLandline => 'Festnetz';

  @override
  String get labelMobile => 'Mobil';

  @override
  String get labelOther => 'Sonstige';

  @override
  String get labelWork => 'Arbeit';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String get logCanceled => 'Abgebrochen';

  @override
  String get logDeclined => 'Abgelehnt';

  @override
  String logIncoming(String duration) {
    return 'Eingehend · $duration';
  }

  @override
  String get logMissed => 'Verpasst';

  @override
  String get logNotReached => 'Nicht erreicht';

  @override
  String logOutgoing(String duration) {
    return 'Ausgehend · $duration';
  }

  @override
  String get makeFavorite => 'Favorisieren';

  @override
  String get manualSetup => 'Manuell einrichten';

  @override
  String get manualSetupHint =>
      'Server-Adresse, Benutzer und Passwort selbst eintragen.';

  @override
  String get micOpenFailed => 'Mikrofon konnte nicht geöffnet werden.';

  @override
  String get microphone => 'Mikrofon';

  @override
  String get name => 'Name';

  @override
  String get nameRequired => 'Bitte einen Namen eingeben';

  @override
  String get newContact => 'Neuer Kontakt';

  @override
  String get noMatch => 'Kein Treffer';

  @override
  String get notConnectedCopied =>
      'Nicht verbunden – Nummer ins Wählfeld übernommen';

  @override
  String get notDuringCall => 'Während eines Gesprächs nicht verfügbar.';

  @override
  String get notifIncomingTitle => 'Eingehender Anruf';

  @override
  String get notifMissedTitle => 'Verpasster Anruf';

  @override
  String notifReachableAs(String identity) {
    return 'Erreichbar als $identity';
  }

  @override
  String get notifReachableTitle => 'Haustelefon ist erreichbar';

  @override
  String get numberType => 'Bezeichnung';

  @override
  String onLine(String line) {
    return 'auf $line';
  }

  @override
  String get outgoingNumber => 'Ausgehende Rufnummer';

  @override
  String get password => 'Passwort';

  @override
  String get paste => 'Einfügen';

  @override
  String get pasteSetupCode => 'Einrichtungscode einfügen';

  @override
  String get pasteSetupCodeHint =>
      'Alles automatisch – Code vom Server (./setup.sh codes)';

  @override
  String get phoneNumbers => 'Rufnummern';

  @override
  String get reconnect => 'Neu verbinden';

  @override
  String redial(String number) {
    return 'Wahlwiederholung: $number';
  }

  @override
  String get registrar => 'Registrar (Router)';

  @override
  String get registrarHint => 'speedport.ip oder 192.168.2.1';

  @override
  String get required => 'Pflichtfeld';

  @override
  String get rescanDevices => 'Geräte neu suchen';

  @override
  String get ringVolume => 'Klingellautstärke';

  @override
  String get ringtone => 'Klingelton';

  @override
  String get ringtoneClassic => 'Klassisch';

  @override
  String get ringtoneDigital => 'Digital';

  @override
  String get ringtoneHintMobile =>
      'Auf dem Handy klingelt die System-Benachrichtigung.';

  @override
  String get ringtoneHintWindows =>
      'Der Klingelton läuft über das Windows-Standardgerät. Bei eingehenden Anrufen holt sich die App außerdem nach vorne und lässt die Taskleiste blinken.';

  @override
  String get ringtoneOff => 'Aus';

  @override
  String get ringtoneSoft => 'Sanft';

  @override
  String get save => 'Speichern';

  @override
  String get saveAndConnect => 'Speichern & verbinden';

  @override
  String get saveAsContact => 'Als Kontakt speichern';

  @override
  String get savedConnecting =>
      'Gespeichert – verbinde mit der Telefonanlage …';

  @override
  String get savedInstantly => 'Änderungen werden sofort gespeichert.';

  @override
  String get searchContacts => 'Name oder Nummer suchen';

  @override
  String get searchingDevices => 'Suche Geräte …';

  @override
  String get server => 'Server';

  @override
  String get setUp => 'Einrichten';

  @override
  String get settings => 'Einstellungen';

  @override
  String get settingsPc => 'PC';

  @override
  String get setupCardSubtitle => 'Server, Benutzer & Passwort hinterlegen';

  @override
  String get setupCardTitle => 'Nebenstelle einrichten';

  @override
  String get setupCodeChoiceHint =>
      'Den Code erzeugt der Server (./setup.sh codes). Empfohlen – alles wird automatisch eingestellt.';

  @override
  String setupDoneDevice(String name, String ext) {
    return 'Eingerichtet: $name · Durchwahl $ext';
  }

  @override
  String setupDoneUser(String user) {
    return 'Eingerichtet als $user';
  }

  @override
  String get setupInvalidCode =>
      'Das ist kein gültiger Einrichtungscode – bitte vollständig kopieren.';

  @override
  String get showContact => 'Kontakt anzeigen';

  @override
  String get sipDomain => 'SIP-Domain (Server-IP)';

  @override
  String get sipPort => 'SIP-Port (TCP)';

  @override
  String get speakerHeadphones => 'Lautsprecher / Kopfhörer';

  @override
  String get statusConnecting => 'Verbinde …';

  @override
  String get statusFailed => 'Fehler';

  @override
  String get statusOffline => 'Nicht verbunden';

  @override
  String get statusRegistered => 'Registriert';

  @override
  String get statusUnconfigured => 'Nicht eingerichtet';

  @override
  String get stopTest => 'Test beenden';

  @override
  String get systemDefaultDevice => 'Standardgerät des Systems';

  @override
  String get team => 'Team';

  @override
  String get testMicrophone => 'Mikrofon testen';

  @override
  String get today => 'Heute';

  @override
  String get transportTcp => 'Direkt (TCP)';

  @override
  String get transportTcpHint =>
      'Experimentell. Registriert direkt per SIP/TCP am Router. Gespräche scheitern meist, weil WebRTC verschlüsseltes Audio (DTLS-SRTP) verlangt, das Router wie der Speedport nicht können.';

  @override
  String get transportWs => 'Server (WS)';

  @override
  String get transportWsHint =>
      'Empfohlen. Die App spricht WebRTC mit dem Haustelefon-Server (Asterisk), der als IP-Telefon an deinem Router angemeldet ist.';

  @override
  String get trayHiddenText =>
      'Du bleibst erreichbar. Beenden über das Symbol im Infobereich.';

  @override
  String get trayHiddenTitle => 'Haustelefon läuft weiter';

  @override
  String get trayOpen => 'Öffnen';

  @override
  String get trayQuit => 'Beenden';

  @override
  String get unknownCaller => 'Unbekannt';

  @override
  String get unnamedDevice => 'Unbenanntes Gerät';

  @override
  String get userId => 'Nutzerkennung';

  @override
  String get userIdHint => 'z. B. **71';

  @override
  String get usernameGateway => 'Benutzername (Server)';

  @override
  String viaLine(String line) {
    return 'über $line';
  }

  @override
  String weekday(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      '1': 'Montag',
      '2': 'Dienstag',
      '3': 'Mittwoch',
      '4': 'Donnerstag',
      '5': 'Freitag',
      '6': 'Samstag',
      'other': 'Sonntag',
    });
    return '$_temp0';
  }

  @override
  String get welcomeBody => 'Verbinde dieses Gerät mit deiner Telefonanlage.';

  @override
  String get welcomeTitle => 'Willkommen bei Haustelefon';

  @override
  String get wsUrl => 'WebSocket-URL';

  @override
  String get wsUrlInvalid => 'z. B. ws://192.168.2.50:8088/ws';

  @override
  String get yesterday => 'Gestern';
}

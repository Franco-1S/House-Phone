// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get addContact => 'Add contact';

  @override
  String get addNumber => 'Add number';

  @override
  String get appTitle => 'Haustelefon';

  @override
  String get atLeastOneNumber => 'At least one number';

  @override
  String get audio => 'Audio';

  @override
  String get audioAndRingtone => 'Audio & ringtone';

  @override
  String get audioCardSubtitle => 'Microphone, speaker, volume, ringtone';

  @override
  String get authName => 'Authentication name';

  @override
  String get authNameHint => 'e.g. nutzer-1@speedport.ip';

  @override
  String get authUserHint => 'empty = username';

  @override
  String get authUserOptional => 'Auth user (optional)';

  @override
  String get autostart => 'Start with Windows';

  @override
  String get autostartHint => 'Starts hidden in the notification area';

  @override
  String get back => 'Back';

  @override
  String get btnAnswer => 'Answer';

  @override
  String get btnAudio => 'Audio';

  @override
  String get btnDecline => 'Decline';

  @override
  String get btnHold => 'Hold';

  @override
  String get btnKeypad => 'Keypad';

  @override
  String get btnMute => 'Mute';

  @override
  String get btnResume => 'Resume';

  @override
  String get btnSpeaker => 'Speaker';

  @override
  String get callDialing => 'Dialling';

  @override
  String get callHistory => 'Call history';

  @override
  String get callIncoming => 'Incoming call';

  @override
  String get callOnHold => 'On hold';

  @override
  String get callRemoteHold => 'Held by the other party';

  @override
  String get callRinging => 'Ringing';

  @override
  String get callVia => 'Call via';

  @override
  String get callVolume => 'Call volume';

  @override
  String get cancel => 'Cancel';

  @override
  String get changesSaved => 'Changes saved';

  @override
  String get clear => 'Clear';

  @override
  String get clearHistoryBody =>
      'All entries will be deleted from this device.';

  @override
  String get clearHistoryTitle => 'Clear call history?';

  @override
  String get clearList => 'Clear list';

  @override
  String get closeToTray => 'Keep running in the notification area';

  @override
  String get closeToTrayHint =>
      'Closing the window keeps you reachable for calls';

  @override
  String get connectionType => 'Connection type';

  @override
  String contactDeleted(String name) {
    return '$name deleted';
  }

  @override
  String contactSaved(String name) {
    return '$name saved';
  }

  @override
  String get contacts => 'Contacts';

  @override
  String get contactsEmptyBody => 'Add your first contact.';

  @override
  String get contactsEmptyTitle => 'No contacts yet';

  @override
  String get credentials => 'Credentials';

  @override
  String get defaultLabel => 'Default';

  @override
  String get delete => 'Delete';

  @override
  String get deleteContactBody =>
      'The contact will be removed from this device.';

  @override
  String deleteContactTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get detailAuthRejected => 'Username or password rejected';

  @override
  String get detailConnecting => 'Establishing connection …';

  @override
  String get detailDisconnected => 'Disconnected';

  @override
  String detailNoAnswer(String host) {
    return 'No answer from $host – is the VPN on and the address correct?';
  }

  @override
  String get detailNotFound => 'Unknown extension (404)';

  @override
  String get detailReady => 'Ready for calls';

  @override
  String detailRegistering(String host) {
    return 'Registering with $host …';
  }

  @override
  String get detailRetrying => 'retrying automatically';

  @override
  String get detailSetupHint => 'Tap the gear icon to set up your extension.';

  @override
  String detailStartFailed(String error) {
    return 'Start failed: $error';
  }

  @override
  String get detailStarting => 'Starting …';

  @override
  String get detailTimeout => 'Timed out – check VPN/address';

  @override
  String get detailUnreachable => 'Server unreachable – is the VPN on?';

  @override
  String get detailUnregistered => 'Signed out';

  @override
  String get directionIncoming => 'incoming';

  @override
  String get directionOutgoing => 'outgoing';

  @override
  String get displayNameHint => 'e.g. Phone';

  @override
  String get displayNameOptional => 'Display name (optional)';

  @override
  String get edit => 'Edit';

  @override
  String get editContact => 'Edit contact';

  @override
  String get endBusy => 'Busy';

  @override
  String get endCanceled => 'Cancelled';

  @override
  String get endConnectionLost => 'Connection lost';

  @override
  String get endDeclined => 'Declined';

  @override
  String get endEnded => 'Call ended';

  @override
  String endFailed(String code) {
    return 'Failed ($code)';
  }

  @override
  String get endIncompatible =>
      'Audio incompatible – gateway required (see guide)';

  @override
  String get endIncomplete => 'Incomplete number';

  @override
  String get endMissed => 'Missed call';

  @override
  String get endNoAnswer => 'No answer';

  @override
  String get endNoMicrophone => 'No microphone access';

  @override
  String get endNotConnected => 'Not connected to the phone system';

  @override
  String get endNotFound => 'Number not found';

  @override
  String get endRejected => 'Call declined';

  @override
  String get endRtpTimeout => 'No more audio received';

  @override
  String get endUnauthorized => 'Not authorised';

  @override
  String get endUnavailable => 'Not reachable';

  @override
  String get enterNumber => 'Enter number';

  @override
  String extensionLabel(String ext) {
    return 'Extension $ext';
  }

  @override
  String get extensionTitle => 'Extension';

  @override
  String get favorite => 'Favourite';

  @override
  String get favoriteHint => 'Shown at the top of your contacts';

  @override
  String get filterAll => 'All';

  @override
  String get filterMissed => 'Missed';

  @override
  String filterMissedCount(int count) {
    return 'Missed ($count)';
  }

  @override
  String groupExtension(String ext) {
    return 'Group · extension $ext';
  }

  @override
  String get hearMyself => 'Hear myself';

  @override
  String get hearMyselfHint =>
      'Also tests the speaker – headphones recommended';

  @override
  String get historyEmptyBody => 'Your calls will show up here.';

  @override
  String get historyEmptyMissedBody => 'Every call was answered.';

  @override
  String get historyEmptyMissedTitle => 'Nothing missed';

  @override
  String get historyEmptyTitle => 'No calls yet';

  @override
  String get invalidPort => 'Invalid port';

  @override
  String get labelInternal => 'Internal';

  @override
  String get labelLandline => 'Landline';

  @override
  String get labelMobile => 'Mobile';

  @override
  String get labelOther => 'Other';

  @override
  String get labelWork => 'Work';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get logCanceled => 'Cancelled';

  @override
  String get logDeclined => 'Declined';

  @override
  String logIncoming(String duration) {
    return 'Incoming · $duration';
  }

  @override
  String get logMissed => 'Missed';

  @override
  String get logNotReached => 'Not reached';

  @override
  String logOutgoing(String duration) {
    return 'Outgoing · $duration';
  }

  @override
  String get makeFavorite => 'Favourite';

  @override
  String get manualSetup => 'Set up manually';

  @override
  String get manualSetupHint =>
      'Enter server address, user and password yourself.';

  @override
  String get micOpenFailed => 'Could not open the microphone.';

  @override
  String get microphone => 'Microphone';

  @override
  String get name => 'Name';

  @override
  String get nameRequired => 'Please enter a name';

  @override
  String get newContact => 'New contact';

  @override
  String get noMatch => 'No match';

  @override
  String get notConnectedCopied =>
      'Not connected – number copied to the dialer';

  @override
  String get notDuringCall => 'Not available during a call.';

  @override
  String get notifIncomingTitle => 'Incoming call';

  @override
  String get notifMissedTitle => 'Missed call';

  @override
  String notifReachableAs(String identity) {
    return 'Reachable as $identity';
  }

  @override
  String get notifReachableTitle => 'Haustelefon is reachable';

  @override
  String get numberType => 'Number type';

  @override
  String onLine(String line) {
    return 'on $line';
  }

  @override
  String get outgoingNumber => 'Outgoing number';

  @override
  String get password => 'Password';

  @override
  String get paste => 'Paste';

  @override
  String get pasteSetupCode => 'Paste setup code';

  @override
  String get pasteSetupCodeHint =>
      'Everything automatic – code from the server (./setup.sh codes)';

  @override
  String get phoneNumbers => 'Phone numbers';

  @override
  String get reconnect => 'Reconnect';

  @override
  String redial(String number) {
    return 'Redial: $number';
  }

  @override
  String get registrar => 'Registrar (router)';

  @override
  String get registrarHint => 'speedport.ip or 192.168.2.1';

  @override
  String get required => 'Required';

  @override
  String get rescanDevices => 'Search devices again';

  @override
  String get ringVolume => 'Ring volume';

  @override
  String get ringtone => 'Ringtone';

  @override
  String get ringtoneClassic => 'Classic';

  @override
  String get ringtoneDigital => 'Digital';

  @override
  String get ringtoneHintMobile => 'On phones the system notification rings.';

  @override
  String get ringtoneHintWindows =>
      'The ringtone plays on the Windows default device. For incoming calls the app also comes to the front and flashes the taskbar.';

  @override
  String get ringtoneOff => 'Off';

  @override
  String get ringtoneSoft => 'Soft';

  @override
  String get save => 'Save';

  @override
  String get saveAndConnect => 'Save & connect';

  @override
  String get saveAsContact => 'Save as contact';

  @override
  String get savedConnecting => 'Saved – connecting to the phone system …';

  @override
  String get savedInstantly => 'Changes are saved immediately.';

  @override
  String get searchContacts => 'Search name or number';

  @override
  String get searchingDevices => 'Searching devices …';

  @override
  String get server => 'Server';

  @override
  String get setUp => 'Set up';

  @override
  String get settings => 'Settings';

  @override
  String get settingsPc => 'PC';

  @override
  String get setupCardSubtitle => 'Enter server, user & password';

  @override
  String get setupCardTitle => 'Set up extension';

  @override
  String get setupCodeChoiceHint =>
      'The server creates the code (./setup.sh codes). Recommended – everything is configured automatically.';

  @override
  String setupDoneDevice(String name, String ext) {
    return 'Set up: $name · extension $ext';
  }

  @override
  String setupDoneUser(String user) {
    return 'Set up as $user';
  }

  @override
  String get setupInvalidCode =>
      'This is not a valid setup code – please copy it completely.';

  @override
  String get showContact => 'Show contact';

  @override
  String get sipDomain => 'SIP domain (server IP)';

  @override
  String get sipPort => 'SIP port (TCP)';

  @override
  String get speakerHeadphones => 'Speaker / headphones';

  @override
  String get statusConnecting => 'Connecting …';

  @override
  String get statusFailed => 'Error';

  @override
  String get statusOffline => 'Not connected';

  @override
  String get statusRegistered => 'Registered';

  @override
  String get statusUnconfigured => 'Not set up';

  @override
  String get stopTest => 'Stop test';

  @override
  String get systemDefaultDevice => 'System default device';

  @override
  String get team => 'Team';

  @override
  String get testMicrophone => 'Test microphone';

  @override
  String get today => 'Today';

  @override
  String get transportTcp => 'Direct (TCP)';

  @override
  String get transportTcpHint =>
      'Experimental. Registers directly with the router via SIP/TCP. Calls usually fail because WebRTC requires encrypted audio (DTLS-SRTP) that routers like the Speedport do not support.';

  @override
  String get transportWs => 'Server (WS)';

  @override
  String get transportWsHint =>
      'Recommended. The app talks WebRTC to the Haustelefon server (Asterisk), which is registered with your router as an IP phone.';

  @override
  String get trayHiddenText =>
      'You stay reachable. Quit from the icon in the notification area.';

  @override
  String get trayHiddenTitle => 'Haustelefon keeps running';

  @override
  String get trayOpen => 'Open';

  @override
  String get trayQuit => 'Quit';

  @override
  String get unknownCaller => 'Unknown';

  @override
  String get unnamedDevice => 'Unnamed device';

  @override
  String get userId => 'User ID';

  @override
  String get userIdHint => 'e.g. **71';

  @override
  String get usernameGateway => 'Username (server)';

  @override
  String viaLine(String line) {
    return 'via $line';
  }

  @override
  String weekday(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      '1': 'Monday',
      '2': 'Tuesday',
      '3': 'Wednesday',
      '4': 'Thursday',
      '5': 'Friday',
      '6': 'Saturday',
      'other': 'Sunday',
    });
    return '$_temp0';
  }

  @override
  String get welcomeBody => 'Connect this device to your phone system.';

  @override
  String get welcomeTitle => 'Welcome to Haustelefon';

  @override
  String get wsUrl => 'WebSocket URL';

  @override
  String get wsUrlInvalid => 'e.g. ws://192.168.2.50:8088/ws';

  @override
  String get yesterday => 'Yesterday';
}

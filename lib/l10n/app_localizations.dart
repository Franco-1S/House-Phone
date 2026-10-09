import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// No description provided for @addNumber.
  ///
  /// In en, this message translates to:
  /// **'Add number'**
  String get addNumber;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Haustelefon'**
  String get appTitle;

  /// No description provided for @atLeastOneNumber.
  ///
  /// In en, this message translates to:
  /// **'At least one number'**
  String get atLeastOneNumber;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @audioAndRingtone.
  ///
  /// In en, this message translates to:
  /// **'Audio & ringtone'**
  String get audioAndRingtone;

  /// No description provided for @audioCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone, speaker, volume, ringtone'**
  String get audioCardSubtitle;

  /// No description provided for @authName.
  ///
  /// In en, this message translates to:
  /// **'Authentication name'**
  String get authName;

  /// No description provided for @authNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. nutzer-1@speedport.ip'**
  String get authNameHint;

  /// No description provided for @authUserHint.
  ///
  /// In en, this message translates to:
  /// **'empty = username'**
  String get authUserHint;

  /// No description provided for @authUserOptional.
  ///
  /// In en, this message translates to:
  /// **'Auth user (optional)'**
  String get authUserOptional;

  /// No description provided for @autostart.
  ///
  /// In en, this message translates to:
  /// **'Start with Windows'**
  String get autostart;

  /// No description provided for @autostartHint.
  ///
  /// In en, this message translates to:
  /// **'Starts hidden in the notification area'**
  String get autostartHint;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @btnAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get btnAnswer;

  /// No description provided for @btnAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get btnAudio;

  /// No description provided for @btnDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get btnDecline;

  /// No description provided for @btnHold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get btnHold;

  /// No description provided for @btnKeypad.
  ///
  /// In en, this message translates to:
  /// **'Keypad'**
  String get btnKeypad;

  /// No description provided for @btnMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get btnMute;

  /// No description provided for @btnResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get btnResume;

  /// No description provided for @btnSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get btnSpeaker;

  /// No description provided for @callDialing.
  ///
  /// In en, this message translates to:
  /// **'Dialling'**
  String get callDialing;

  /// No description provided for @callHistory.
  ///
  /// In en, this message translates to:
  /// **'Call history'**
  String get callHistory;

  /// No description provided for @callIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get callIncoming;

  /// No description provided for @callOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get callOnHold;

  /// No description provided for @callRemoteHold.
  ///
  /// In en, this message translates to:
  /// **'Held by the other party'**
  String get callRemoteHold;

  /// No description provided for @callRinging.
  ///
  /// In en, this message translates to:
  /// **'Ringing'**
  String get callRinging;

  /// No description provided for @callVia.
  ///
  /// In en, this message translates to:
  /// **'Call via'**
  String get callVia;

  /// No description provided for @callVolume.
  ///
  /// In en, this message translates to:
  /// **'Call volume'**
  String get callVolume;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @changesSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get changesSaved;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'All entries will be deleted from this device.'**
  String get clearHistoryBody;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear call history?'**
  String get clearHistoryTitle;

  /// No description provided for @clearList.
  ///
  /// In en, this message translates to:
  /// **'Clear list'**
  String get clearList;

  /// No description provided for @closeToTray.
  ///
  /// In en, this message translates to:
  /// **'Keep running in the notification area'**
  String get closeToTray;

  /// No description provided for @closeToTrayHint.
  ///
  /// In en, this message translates to:
  /// **'Closing the window keeps you reachable for calls'**
  String get closeToTrayHint;

  /// No description provided for @connectionType.
  ///
  /// In en, this message translates to:
  /// **'Connection type'**
  String get connectionType;

  /// No description provided for @contactDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String contactDeleted(String name);

  /// No description provided for @contactSaved.
  ///
  /// In en, this message translates to:
  /// **'{name} saved'**
  String contactSaved(String name);

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @contactsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first contact.'**
  String get contactsEmptyBody;

  /// No description provided for @contactsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get contactsEmptyTitle;

  /// No description provided for @credentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get credentials;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteContactBody.
  ///
  /// In en, this message translates to:
  /// **'The contact will be removed from this device.'**
  String get deleteContactBody;

  /// No description provided for @deleteContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteContactTitle(String name);

  /// No description provided for @detailAuthRejected.
  ///
  /// In en, this message translates to:
  /// **'Username or password rejected'**
  String get detailAuthRejected;

  /// No description provided for @detailConnecting.
  ///
  /// In en, this message translates to:
  /// **'Establishing connection …'**
  String get detailConnecting;

  /// No description provided for @detailDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get detailDisconnected;

  /// No description provided for @detailNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer from {host} – is the VPN on and the address correct?'**
  String detailNoAnswer(String host);

  /// No description provided for @detailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Unknown extension (404)'**
  String get detailNotFound;

  /// No description provided for @detailReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for calls'**
  String get detailReady;

  /// No description provided for @detailRegistering.
  ///
  /// In en, this message translates to:
  /// **'Registering with {host} …'**
  String detailRegistering(String host);

  /// No description provided for @detailRetrying.
  ///
  /// In en, this message translates to:
  /// **'retrying automatically'**
  String get detailRetrying;

  /// No description provided for @detailSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the gear icon to set up your extension.'**
  String get detailSetupHint;

  /// No description provided for @detailStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Start failed: {error}'**
  String detailStartFailed(String error);

  /// No description provided for @detailStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting …'**
  String get detailStarting;

  /// No description provided for @detailTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timed out – check VPN/address'**
  String get detailTimeout;

  /// No description provided for @detailUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable – is the VPN on?'**
  String get detailUnreachable;

  /// No description provided for @detailUnregistered.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get detailUnregistered;

  /// No description provided for @directionIncoming.
  ///
  /// In en, this message translates to:
  /// **'incoming'**
  String get directionIncoming;

  /// No description provided for @directionOutgoing.
  ///
  /// In en, this message translates to:
  /// **'outgoing'**
  String get directionOutgoing;

  /// No description provided for @displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Phone'**
  String get displayNameHint;

  /// No description provided for @displayNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get displayNameOptional;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editContact.
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get editContact;

  /// No description provided for @endBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get endBusy;

  /// No description provided for @endCanceled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get endCanceled;

  /// No description provided for @endConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get endConnectionLost;

  /// No description provided for @endDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get endDeclined;

  /// No description provided for @endEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get endEnded;

  /// No description provided for @endFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed ({code})'**
  String endFailed(String code);

  /// No description provided for @endIncompatible.
  ///
  /// In en, this message translates to:
  /// **'Audio incompatible – gateway required (see guide)'**
  String get endIncompatible;

  /// No description provided for @endIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete number'**
  String get endIncomplete;

  /// No description provided for @endMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed call'**
  String get endMissed;

  /// No description provided for @endNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get endNoAnswer;

  /// No description provided for @endNoMicrophone.
  ///
  /// In en, this message translates to:
  /// **'No microphone access'**
  String get endNoMicrophone;

  /// No description provided for @endNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected to the phone system'**
  String get endNotConnected;

  /// No description provided for @endNotFound.
  ///
  /// In en, this message translates to:
  /// **'Number not found'**
  String get endNotFound;

  /// No description provided for @endRejected.
  ///
  /// In en, this message translates to:
  /// **'Call declined'**
  String get endRejected;

  /// No description provided for @endRtpTimeout.
  ///
  /// In en, this message translates to:
  /// **'No more audio received'**
  String get endRtpTimeout;

  /// No description provided for @endUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Not authorised'**
  String get endUnauthorized;

  /// No description provided for @endUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not reachable'**
  String get endUnavailable;

  /// No description provided for @enterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter number'**
  String get enterNumber;

  /// No description provided for @extensionLabel.
  ///
  /// In en, this message translates to:
  /// **'Extension {ext}'**
  String extensionLabel(String ext);

  /// No description provided for @extensionTitle.
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get extensionTitle;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get favorite;

  /// No description provided for @favoriteHint.
  ///
  /// In en, this message translates to:
  /// **'Shown at the top of your contacts'**
  String get favoriteHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get filterMissed;

  /// No description provided for @filterMissedCount.
  ///
  /// In en, this message translates to:
  /// **'Missed ({count})'**
  String filterMissedCount(int count);

  /// No description provided for @groupExtension.
  ///
  /// In en, this message translates to:
  /// **'Group · extension {ext}'**
  String groupExtension(String ext);

  /// No description provided for @hearMyself.
  ///
  /// In en, this message translates to:
  /// **'Hear myself'**
  String get hearMyself;

  /// No description provided for @hearMyselfHint.
  ///
  /// In en, this message translates to:
  /// **'Also tests the speaker – headphones recommended'**
  String get hearMyselfHint;

  /// No description provided for @historyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your calls will show up here.'**
  String get historyEmptyBody;

  /// No description provided for @historyEmptyMissedBody.
  ///
  /// In en, this message translates to:
  /// **'Every call was answered.'**
  String get historyEmptyMissedBody;

  /// No description provided for @historyEmptyMissedTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing missed'**
  String get historyEmptyMissedTitle;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No calls yet'**
  String get historyEmptyTitle;

  /// No description provided for @invalidPort.
  ///
  /// In en, this message translates to:
  /// **'Invalid port'**
  String get invalidPort;

  /// No description provided for @labelInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal'**
  String get labelInternal;

  /// No description provided for @labelLandline.
  ///
  /// In en, this message translates to:
  /// **'Landline'**
  String get labelLandline;

  /// No description provided for @labelMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get labelMobile;

  /// No description provided for @labelOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get labelOther;

  /// No description provided for @labelWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get labelWork;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @logCanceled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get logCanceled;

  /// No description provided for @logDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get logDeclined;

  /// No description provided for @logIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming · {duration}'**
  String logIncoming(String duration);

  /// No description provided for @logMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get logMissed;

  /// No description provided for @logNotReached.
  ///
  /// In en, this message translates to:
  /// **'Not reached'**
  String get logNotReached;

  /// No description provided for @logOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing · {duration}'**
  String logOutgoing(String duration);

  /// No description provided for @makeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get makeFavorite;

  /// No description provided for @manualSetup.
  ///
  /// In en, this message translates to:
  /// **'Set up manually'**
  String get manualSetup;

  /// No description provided for @manualSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Enter server address, user and password yourself.'**
  String get manualSetupHint;

  /// No description provided for @micOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the microphone.'**
  String get micOpenFailed;

  /// No description provided for @microphone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get microphone;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get nameRequired;

  /// No description provided for @newContact.
  ///
  /// In en, this message translates to:
  /// **'New contact'**
  String get newContact;

  /// No description provided for @noMatch.
  ///
  /// In en, this message translates to:
  /// **'No match'**
  String get noMatch;

  /// No description provided for @notConnectedCopied.
  ///
  /// In en, this message translates to:
  /// **'Not connected – number copied to the dialer'**
  String get notConnectedCopied;

  /// No description provided for @notDuringCall.
  ///
  /// In en, this message translates to:
  /// **'Not available during a call.'**
  String get notDuringCall;

  /// No description provided for @notifIncomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get notifIncomingTitle;

  /// No description provided for @notifMissedTitle.
  ///
  /// In en, this message translates to:
  /// **'Missed call'**
  String get notifMissedTitle;

  /// No description provided for @notifReachableAs.
  ///
  /// In en, this message translates to:
  /// **'Reachable as {identity}'**
  String notifReachableAs(String identity);

  /// No description provided for @notifReachableTitle.
  ///
  /// In en, this message translates to:
  /// **'Haustelefon is reachable'**
  String get notifReachableTitle;

  /// No description provided for @numberType.
  ///
  /// In en, this message translates to:
  /// **'Number type'**
  String get numberType;

  /// No description provided for @onLine.
  ///
  /// In en, this message translates to:
  /// **'on {line}'**
  String onLine(String line);

  /// No description provided for @outgoingNumber.
  ///
  /// In en, this message translates to:
  /// **'Outgoing number'**
  String get outgoingNumber;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @pasteSetupCode.
  ///
  /// In en, this message translates to:
  /// **'Paste setup code'**
  String get pasteSetupCode;

  /// No description provided for @pasteSetupCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Everything automatic – code from the server (./setup.sh codes)'**
  String get pasteSetupCodeHint;

  /// No description provided for @phoneNumbers.
  ///
  /// In en, this message translates to:
  /// **'Phone numbers'**
  String get phoneNumbers;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @redial.
  ///
  /// In en, this message translates to:
  /// **'Redial: {number}'**
  String redial(String number);

  /// No description provided for @registrar.
  ///
  /// In en, this message translates to:
  /// **'Registrar (router)'**
  String get registrar;

  /// No description provided for @registrarHint.
  ///
  /// In en, this message translates to:
  /// **'speedport.ip or 192.168.2.1'**
  String get registrarHint;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @rescanDevices.
  ///
  /// In en, this message translates to:
  /// **'Search devices again'**
  String get rescanDevices;

  /// No description provided for @ringVolume.
  ///
  /// In en, this message translates to:
  /// **'Ring volume'**
  String get ringVolume;

  /// No description provided for @ringtone.
  ///
  /// In en, this message translates to:
  /// **'Ringtone'**
  String get ringtone;

  /// No description provided for @ringtoneClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get ringtoneClassic;

  /// No description provided for @ringtoneDigital.
  ///
  /// In en, this message translates to:
  /// **'Digital'**
  String get ringtoneDigital;

  /// No description provided for @ringtoneHintMobile.
  ///
  /// In en, this message translates to:
  /// **'On phones the system notification rings.'**
  String get ringtoneHintMobile;

  /// No description provided for @ringtoneHintWindows.
  ///
  /// In en, this message translates to:
  /// **'The ringtone plays on the Windows default device. For incoming calls the app also comes to the front and flashes the taskbar.'**
  String get ringtoneHintWindows;

  /// No description provided for @ringtoneOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get ringtoneOff;

  /// No description provided for @ringtoneSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get ringtoneSoft;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAndConnect.
  ///
  /// In en, this message translates to:
  /// **'Save & connect'**
  String get saveAndConnect;

  /// No description provided for @saveAsContact.
  ///
  /// In en, this message translates to:
  /// **'Save as contact'**
  String get saveAsContact;

  /// No description provided for @savedConnecting.
  ///
  /// In en, this message translates to:
  /// **'Saved – connecting to the phone system …'**
  String get savedConnecting;

  /// No description provided for @savedInstantly.
  ///
  /// In en, this message translates to:
  /// **'Changes are saved immediately.'**
  String get savedInstantly;

  /// No description provided for @searchContacts.
  ///
  /// In en, this message translates to:
  /// **'Search name or number'**
  String get searchContacts;

  /// No description provided for @searchingDevices.
  ///
  /// In en, this message translates to:
  /// **'Searching devices …'**
  String get searchingDevices;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @setUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get setUp;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsPc.
  ///
  /// In en, this message translates to:
  /// **'PC'**
  String get settingsPc;

  /// No description provided for @setupCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter server, user & password'**
  String get setupCardSubtitle;

  /// No description provided for @setupCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up extension'**
  String get setupCardTitle;

  /// No description provided for @setupCodeChoiceHint.
  ///
  /// In en, this message translates to:
  /// **'The server creates the code (./setup.sh codes). Recommended – everything is configured automatically.'**
  String get setupCodeChoiceHint;

  /// No description provided for @setupDoneDevice.
  ///
  /// In en, this message translates to:
  /// **'Set up: {name} · extension {ext}'**
  String setupDoneDevice(String name, String ext);

  /// No description provided for @setupDoneUser.
  ///
  /// In en, this message translates to:
  /// **'Set up as {user}'**
  String setupDoneUser(String user);

  /// No description provided for @setupInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid setup code – please copy it completely.'**
  String get setupInvalidCode;

  /// No description provided for @showContact.
  ///
  /// In en, this message translates to:
  /// **'Show contact'**
  String get showContact;

  /// No description provided for @sipDomain.
  ///
  /// In en, this message translates to:
  /// **'SIP domain (server IP)'**
  String get sipDomain;

  /// No description provided for @sipPort.
  ///
  /// In en, this message translates to:
  /// **'SIP port (TCP)'**
  String get sipPort;

  /// No description provided for @speakerHeadphones.
  ///
  /// In en, this message translates to:
  /// **'Speaker / headphones'**
  String get speakerHeadphones;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting …'**
  String get statusConnecting;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusFailed;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusOffline;

  /// No description provided for @statusRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get statusRegistered;

  /// No description provided for @statusUnconfigured.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get statusUnconfigured;

  /// No description provided for @stopTest.
  ///
  /// In en, this message translates to:
  /// **'Stop test'**
  String get stopTest;

  /// No description provided for @systemDefaultDevice.
  ///
  /// In en, this message translates to:
  /// **'System default device'**
  String get systemDefaultDevice;

  /// No description provided for @team.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get team;

  /// No description provided for @testMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Test microphone'**
  String get testMicrophone;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @transportTcp.
  ///
  /// In en, this message translates to:
  /// **'Direct (TCP)'**
  String get transportTcp;

  /// No description provided for @transportTcpHint.
  ///
  /// In en, this message translates to:
  /// **'Experimental. Registers directly with the router via SIP/TCP. Calls usually fail because WebRTC requires encrypted audio (DTLS-SRTP) that routers like the Speedport do not support.'**
  String get transportTcpHint;

  /// No description provided for @transportWs.
  ///
  /// In en, this message translates to:
  /// **'Server (WS)'**
  String get transportWs;

  /// No description provided for @transportWsHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended. The app talks WebRTC to the Haustelefon server (Asterisk), which is registered with your router as an IP phone.'**
  String get transportWsHint;

  /// No description provided for @trayHiddenText.
  ///
  /// In en, this message translates to:
  /// **'You stay reachable. Quit from the icon in the notification area.'**
  String get trayHiddenText;

  /// No description provided for @trayHiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'Haustelefon keeps running'**
  String get trayHiddenTitle;

  /// No description provided for @trayOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get trayOpen;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @unknownCaller.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownCaller;

  /// No description provided for @unnamedDevice.
  ///
  /// In en, this message translates to:
  /// **'Unnamed device'**
  String get unnamedDevice;

  /// No description provided for @userId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userId;

  /// No description provided for @userIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. **71'**
  String get userIdHint;

  /// No description provided for @usernameGateway.
  ///
  /// In en, this message translates to:
  /// **'Username (server)'**
  String get usernameGateway;

  /// No description provided for @viaLine.
  ///
  /// In en, this message translates to:
  /// **'via {line}'**
  String viaLine(String line);

  /// No description provided for @weekday.
  ///
  /// In en, this message translates to:
  /// **'{day, select, 1{Monday} 2{Tuesday} 3{Wednesday} 4{Thursday} 5{Friday} 6{Saturday} other{Sunday}}'**
  String weekday(String day);

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Connect this device to your phone system.'**
  String get welcomeBody;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Haustelefon'**
  String get welcomeTitle;

  /// No description provided for @wsUrl.
  ///
  /// In en, this message translates to:
  /// **'WebSocket URL'**
  String get wsUrl;

  /// No description provided for @wsUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'e.g. ws://192.168.2.50:8088/ws'**
  String get wsUrlInvalid;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

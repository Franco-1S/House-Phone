import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sip_account.dart';

/// Persistiert die SIP-Konfiguration.
///
/// Unkritische Werte liegen in SharedPreferences, das Passwort im
/// Keychain (iOS) bzw. Keystore-verschlüsselt (Android).
class SettingsRepository {
  SettingsRepository(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _kTransport = 'sip.transport';
  static const _kWsUrl = 'sip.wsUrl';
  static const _kDomain = 'sip.domain';
  static const _kPort = 'sip.port';
  static const _kUser = 'sip.username';
  static const _kAuthUser = 'sip.authUser';
  static const _kDisplayName = 'sip.displayName';
  static const _kPassword = 'sip.password';
  static const _kLastDialed = 'dialer.lastDialed';

  Future<SipAccount?> loadAccount() async {
    if (!_prefs.containsKey(_kUser)) return null;
    final defaults = SipAccount.defaults();
    String password;
    try {
      password = await _secure.read(key: _kPassword) ?? '';
    } catch (_) {
      // Kann nach einer Neuinstallation mit Backup-Restore passieren.
      password = '';
    }
    return SipAccount(
      transport: SipTransport.values.firstWhere(
        (t) => t.name == _prefs.getString(_kTransport),
        orElse: () => defaults.transport,
      ),
      wsUrl: _prefs.getString(_kWsUrl) ?? defaults.wsUrl,
      domain: _prefs.getString(_kDomain) ?? defaults.domain,
      port: _prefs.getInt(_kPort) ?? defaults.port,
      username: _prefs.getString(_kUser) ?? '',
      authUser: _prefs.getString(_kAuthUser) ?? '',
      displayName: _prefs.getString(_kDisplayName) ?? '',
      password: password,
    );
  }

  Future<void> saveAccount(SipAccount a) async {
    await Future.wait([
      _prefs.setString(_kTransport, a.transport.name),
      _prefs.setString(_kWsUrl, a.wsUrl.trim()),
      _prefs.setString(_kDomain, a.domain.trim()),
      _prefs.setInt(_kPort, a.port),
      _prefs.setString(_kUser, a.username.trim()),
      _prefs.setString(_kAuthUser, a.authUser.trim()),
      _prefs.setString(_kDisplayName, a.displayName.trim()),
      _secure.write(key: _kPassword, value: a.password),
    ]);
  }

  String? get lastDialed => _prefs.getString(_kLastDialed);

  Future<void> setLastDialed(String number) =>
      _prefs.setString(_kLastDialed, number);
}

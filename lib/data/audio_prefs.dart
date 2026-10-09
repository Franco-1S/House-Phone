import 'package:shared_preferences/shared_preferences.dart';

enum Ringtone { classic, soft, digital, off }

/// Audio-Einstellungen (vor allem für den PC).
class AudioPrefs {
  const AudioPrefs({
    this.inputId = '',
    this.outputId = '',
    this.callVolume = 1.0,
    this.ringtone = Ringtone.classic,
    this.ringVolume = 0.8,
  });

  /// Leer = Windows-Standardgerät.
  final String inputId;
  final String outputId;

  /// Lautstärke der Gegenseite, 0.0 … 2.0 (1.0 = unverändert).
  final double callVolume;
  final Ringtone ringtone;

  /// 0.0 … 1.0
  final double ringVolume;

  AudioPrefs copyWith({
    String? inputId,
    String? outputId,
    double? callVolume,
    Ringtone? ringtone,
    double? ringVolume,
  }) => AudioPrefs(
    inputId: inputId ?? this.inputId,
    outputId: outputId ?? this.outputId,
    callVolume: callVolume ?? this.callVolume,
    ringtone: ringtone ?? this.ringtone,
    ringVolume: ringVolume ?? this.ringVolume,
  );
}

class AudioPrefsRepository {
  AudioPrefsRepository(this._prefs);
  final SharedPreferences _prefs;

  static const _kIn = 'audio.inputId';
  static const _kOut = 'audio.outputId';
  static const _kCallVol = 'audio.callVolume';
  static const _kRing = 'audio.ringtone';
  static const _kRingVol = 'audio.ringVolume';

  AudioPrefs load() {
    const d = AudioPrefs();
    return AudioPrefs(
      inputId: _prefs.getString(_kIn) ?? d.inputId,
      outputId: _prefs.getString(_kOut) ?? d.outputId,
      callVolume: _prefs.getDouble(_kCallVol) ?? d.callVolume,
      ringtone: Ringtone.values.firstWhere(
        (r) => r.name == _prefs.getString(_kRing),
        orElse: () => d.ringtone,
      ),
      ringVolume: _prefs.getDouble(_kRingVol) ?? d.ringVolume,
    );
  }

  Future<void> save(AudioPrefs p) async {
    await Future.wait([
      _prefs.setString(_kIn, p.inputId),
      _prefs.setString(_kOut, p.outputId),
      _prefs.setDouble(_kCallVol, p.callVolume),
      _prefs.setString(_kRing, p.ringtone.name),
      _prefs.setDouble(_kRingVol, p.ringVolume),
    ]);
  }
}

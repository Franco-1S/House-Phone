import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/settings_repository.dart';
import '../services/audio_service.dart';
import '../services/background_service.dart';
import '../services/sip_service.dart';

/// Wird in `main()` per `overrideWithValue` gesetzt.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    ref.watch(sharedPreferencesProvider),
    const FlutterSecureStorage(),
  );
});

/// Genau ein User-Agent für die ganze App-Laufzeit.
final sipServiceProvider = Provider<SipService>((ref) {
  final service = SipService();
  ref.onDispose(service.dispose);
  return service;
});

final audioServiceProvider = Provider<AudioService>((ref) => AudioService());

/// Android: Vordergrund-Dienst + Anruf-Benachrichtigungen. Sonst ein No-op.
final backgroundServiceProvider = Provider<BackgroundService>(
  (ref) => BackgroundService(),
);

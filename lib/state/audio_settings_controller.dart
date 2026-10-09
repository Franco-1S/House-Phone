import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/audio_prefs.dart';
import '../services/audio_service.dart';
import 'providers.dart';

final audioPrefsProvider = NotifierProvider<AudioPrefsController, AudioPrefs>(
  AudioPrefsController.new,
);

/// Audio-Einstellungen: werden bei jeder Änderung sofort gespeichert und
/// angewendet – kein extra "Speichern" nötig.
class AudioPrefsController extends Notifier<AudioPrefs> {
  AudioPrefsRepository get _repo =>
      AudioPrefsRepository(ref.read(sharedPreferencesProvider));

  @override
  AudioPrefs build() => _repo.load();

  Future<void> update(AudioPrefs Function(AudioPrefs) change) async {
    final next = change(state);
    final devicesChanged =
        next.inputId != state.inputId || next.outputId != state.outputId;
    state = next;
    await _repo.save(next);
    if (devicesChanged) {
      await ref.read(audioServiceProvider).applyDevices(next);
    }
  }
}

typedef AudioDeviceLists = ({
  List<AudioDevice> inputs,
  List<AudioDevice> outputs,
});

final audioDevicesProvider =
    AsyncNotifierProvider<AudioDevicesController, AudioDeviceLists>(
      AudioDevicesController.new,
    );

class AudioDevicesController extends AsyncNotifier<AudioDeviceLists> {
  @override
  Future<AudioDeviceLists> build() async {
    final audio = ref.read(audioServiceProvider);
    // Ohne Mikrofon-Freigabe liefert WebRTC oft keine Gerätenamen.
    await audio.ensureMicrophone();
    return audio.listDevices();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(audioServiceProvider).listDevices(),
    );
  }
}

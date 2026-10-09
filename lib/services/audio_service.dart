import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/platform.dart';
import '../data/audio_prefs.dart';
import 'desktop_shell.dart';
import 'ringtone_synth.dart';

/// Ein Audiogerät, wie es die Einstellungen anzeigen.
class AudioDevice {
  const AudioDevice(this.id, this.label);
  final String id;
  final String label;
}

/// Alles rund um Mikrofon, Lautsprecher und Bildschirm während eines Anrufs.
///
/// Die eigentliche Audio-Pipeline (Mikrofon → Opus/G.711 → Netz → Ausgabe)
/// übernimmt flutter_webrtc vollständig nativ. Hier wird nur geroutet.
class AudioService {
  bool _micGranted = false;
  bool _ringing = false;

  /// Löst den System-Dialog für das Mikrofon frühzeitig aus, damit er nicht
  /// mitten im Rufaufbau erscheint. Auf Android und iOS fragt
  /// `getUserMedia` selbst nach der Berechtigung.
  Future<bool> ensureMicrophone() async {
    if (_micGranted) return true;
    try {
      final stream = await navigator.mediaDevices.getUserMedia(
        <String, dynamic>{'audio': true, 'video': false},
      );
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
      _micGranted = true;
    } catch (_) {
      _micGranted = false;
    }
    return _micGranted;
  }

  /// `true` = Freisprechen über den Lautsprecher, `false` = Hörmuschel.
  Future<void> setSpeaker(bool on) async {
    if (isDesktop) return; // Am PC gibt es keine Hörmuschel.
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (_) {
      // Ohne aktive Audio-Session (z. B. Simulator) ignorieren.
    }
  }

  /// Hält Display & CPU während eines Gesprächs wach.
  Future<void> keepAwake(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {}
  }

  // --- Geräte (PC) -----------------------------------------------------------

  /// Mikrofone und Lautsprecher, die WebRTC kennt.
  Future<({List<AudioDevice> inputs, List<AudioDevice> outputs})>
  listDevices() async {
    final all = await navigator.mediaDevices.enumerateDevices();
    AudioDevice map(MediaDeviceInfo d) => AudioDevice(
      d.deviceId,
      d.label.trim(), // leer → Oberfläche zeigt "Unbenanntes Gerät"
    );
    return (
      inputs: all.where((d) => d.kind == 'audioinput').map(map).toList(),
      outputs: all.where((d) => d.kind == 'audiooutput').map(map).toList(),
    );
  }

  /// Wendet die gewählten Geräte an (gilt für alle folgenden Gespräche).
  Future<void> applyDevices(AudioPrefs p) async {
    if (!isDesktop) return;
    if (p.inputId.isNotEmpty) {
      try {
        await Helper.selectAudioInput(p.inputId);
      } catch (_) {
        // Gerät abgesteckt → Windows-Standard bleibt aktiv.
      }
    }
    if (p.outputId.isNotEmpty) {
      try {
        await Helper.selectAudioOutput(p.outputId);
      } catch (_) {}
    }
  }

  /// Lautstärke der Gegenseite (1.0 = unverändert, bis 2.0 = doppelt).
  Future<void> applyCallVolume(MediaStream? remote, double volume) async {
    if (remote == null) return;
    for (final t in remote.getAudioTracks()) {
      try {
        await Helper.setVolume(volume, t);
      } catch (_) {}
    }
  }

  // --- Klingeln (PC) ---------------------------------------------------------

  /// Klingelton in Schleife + blinkende Taskleiste (nur Windows).
  Future<void> startRinging(AudioPrefs p) async {
    if (!isWindows || _ringing) return;
    _ringing = true;
    DesktopShell.attention(true);
    if (p.ringtone == Ringtone.off) return;
    await DesktopShell.playLoop(
      RingtoneSynth.wav(p.ringtone, p.ringVolume),
      'ring',
    );
  }

  void stopRinging() {
    if (!_ringing) return;
    _ringing = false;
    DesktopShell.stopSound();
    DesktopShell.attention(false);
  }

  /// Einmal Probehören in den Einstellungen.
  Future<void> previewRingtone(Ringtone tone, double volume) async {
    if (!isWindows || tone == Ringtone.off) return;
    await DesktopShell.playOnce(RingtoneSynth.wav(tone, volume), 'preview');
  }
}

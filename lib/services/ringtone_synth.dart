import 'dart:math' as math;
import 'dart:typed_data';

import '../data/audio_prefs.dart';

/// Erzeugt die Klingeltöne als WAV (16 Bit, mono) – ohne Asset-Dateien.
abstract final class RingtoneSynth {
  static const _rate = 22050;

  static Uint8List wav(Ringtone tone, double volume) {
    final samples = switch (tone) {
      Ringtone.classic => _classic(),
      Ringtone.soft => _soft(),
      Ringtone.digital => _digital(),
      Ringtone.off => Float64List(_rate ~/ 10),
    };
    return _encode(samples, volume.clamp(0.0, 1.0) * 0.85);
  }

  /// Altes Telefon: zwei Klingel-Stöße mit schnellem "Glocken"-Tremolo.
  static Float64List _classic() {
    final out = Float64List((_rate * 3.0).round());
    void burst(double start, double len) {
      final s0 = (start * _rate).round();
      final n = (len * _rate).round();
      for (var i = 0; i < n; i++) {
        final t = i / _rate;
        final tone =
            0.5 * math.sin(2 * math.pi * 440 * t) +
            0.5 * math.sin(2 * math.pi * 480 * t);
        final trem = 0.55 + 0.45 * math.sin(2 * math.pi * 20 * t);
        out[s0 + i] = tone * trem * _fade(i, n);
      }
    }

    burst(0.0, 0.45);
    burst(0.65, 0.45);
    return out;
  }

  /// Weiches Marimba-Arpeggio.
  static Float64List _soft() {
    final out = Float64List((_rate * 2.8).round());
    const notes = [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5];
    for (var k = 0; k < notes.length; k++) {
      final s0 = (k * 0.17 * _rate).round();
      final n = (0.6 * _rate).round();
      for (var i = 0; i < n && s0 + i < out.length; i++) {
        final t = i / _rate;
        final f = notes[k];
        final v =
            (math.sin(2 * math.pi * f * t) +
                0.3 * math.sin(2 * math.pi * f * 2 * t) +
                0.1 * math.sin(2 * math.pi * f * 4 * t)) /
            1.4;
        out[s0 + i] += v * math.exp(-6 * t) * _fade(i, n, attack: 0.003);
      }
    }
    return out;
  }

  /// Moderne Doppel-Pieptöne.
  static Float64List _digital() {
    final out = Float64List((_rate * 2.4).round());
    for (var k = 0; k < 8; k++) {
      final s0 = (k * 0.1 * _rate).round();
      final n = (0.08 * _rate).round();
      final f = k.isEven ? 1046.5 : 1318.5;
      for (var i = 0; i < n; i++) {
        final t = i / _rate;
        out[s0 + i] = 0.8 * math.sin(2 * math.pi * f * t) * _fade(i, n);
      }
    }
    return out;
  }

  /// Kurze Ein-/Ausblendung gegen Knackser.
  static double _fade(int i, int n, {double attack = 0.008}) {
    final a = (attack * _rate).round();
    if (i < a) return i / a;
    if (i > n - a) return (n - i) / a;
    return 1;
  }

  static Uint8List _encode(Float64List s, double gain) {
    final dataLen = s.length * 2;
    final b = ByteData(44 + dataLen);
    void str(int o, String v) {
      for (var i = 0; i < v.length; i++) {
        b.setUint8(o + i, v.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // mono
    b.setUint32(24, _rate, Endian.little);
    b.setUint32(28, _rate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < s.length; i++) {
      final v = (s[i] * gain).clamp(-1.0, 1.0);
      b.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return b.buffer.asUint8List();
  }
}

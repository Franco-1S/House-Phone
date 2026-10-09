import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Mikrofon-/Lautsprecher-Test ohne Server: Zwei lokale PeerConnections
/// schicken das Mikrofon an sich selbst. So messen wir den echten
/// WebRTC-Eingangspegel und können optional über das gewählte
/// Ausgabegerät mithören – exakt der Weg, den auch ein Anruf nimmt.
class MicTest {
  MediaStream? _local;
  RTCPeerConnection? _tx;
  RTCPeerConnection? _rx;
  MediaStreamTrack? _remoteTrack;
  Timer? _timer;
  bool _monitor = false;

  final _levels = StreamController<double>.broadcast();
  Stream<double> get levels => _levels.stream;

  bool get running => _timer != null;

  Future<void> start({required bool monitor}) async {
    await stop();
    _monitor = monitor;
    _local = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'audio': true,
      'video': false,
    });
    final config = <String, dynamic>{
      'iceServers': <Map<String, String>>[],
      'sdpSemantics': 'unified-plan',
    };
    final tx = _tx = await createPeerConnection(config);
    final rx = _rx = await createPeerConnection(config);
    tx.onIceCandidate = (c) => rx.addCandidate(c);
    rx.onIceCandidate = (c) => tx.addCandidate(c);
    rx.onTrack = (e) {
      _remoteTrack = e.track;
      _applyMonitor();
    };
    for (final t in _local!.getAudioTracks()) {
      await tx.addTrack(t, _local!);
    }
    final offer = await tx.createOffer();
    await tx.setLocalDescription(offer);
    await rx.setRemoteDescription(offer);
    final answer = await rx.createAnswer();
    await rx.setLocalDescription(answer);
    await tx.setRemoteDescription(answer);

    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) => _poll());
  }

  Future<void> setMonitor(bool on) async {
    _monitor = on;
    await _applyMonitor();
  }

  Future<void> _applyMonitor() async {
    final t = _remoteTrack;
    if (t == null) return;
    try {
      await Helper.setVolume(_monitor ? 1.0 : 0.0, t);
    } catch (_) {}
  }

  Future<void> _poll() async {
    double? level;
    try {
      for (final r in await _tx?.getStats() ?? const <StatsReport>[]) {
        if (r.type == 'media-source' && r.values['kind'] == 'audio') {
          level = _num(r.values['audioLevel']);
        }
      }
      if (level == null) {
        for (final r in await _rx?.getStats() ?? const <StatsReport>[]) {
          if (r.type == 'inbound-rtp' && r.values['kind'] == 'audio') {
            level = _num(r.values['audioLevel']);
          }
        }
      }
    } catch (_) {}
    if (level != null && !_levels.isClosed) _levels.add(level.clamp(0, 1));
  }

  static double? _num(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('$v');

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _remoteTrack = null;
    for (final t in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
      await t.stop();
    }
    await _local?.dispose();
    _local = null;
    await _tx?.close();
    await _rx?.close();
    _tx = null;
    _rx = null;
    if (!_levels.isClosed) _levels.add(0);
  }

  Future<void> dispose() async {
    await stop();
    await _levels.close();
  }
}

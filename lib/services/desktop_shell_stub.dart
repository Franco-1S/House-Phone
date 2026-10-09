import 'dart:typed_data';

abstract final class DesktopShell {
  static Future<void> playLoop(Uint8List wav, String name) async {}
  static Future<void> playOnce(Uint8List wav, String name) async {}
  static void stopSound() {}
  static void attention(bool on) {}
}

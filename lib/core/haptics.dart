import 'package:flutter/services.dart';

/// Ein zentrales Vokabular für haptisches Feedback, damit sich die App
/// überall gleich "anfühlt".
abstract final class Haptics {
  static void key() => HapticFeedback.lightImpact();
  static void tick() => HapticFeedback.selectionClick();
  static void press() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();

  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.heavyImpact();
  }

  /// Ein "Klingel"-Impuls für eingehende Anrufe.
  static Future<void> ring() async {
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }
}

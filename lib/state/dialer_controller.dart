import 'package:flutter_riverpod/flutter_riverpod.dart';

final dialerProvider = NotifierProvider<DialerController, String>(
  DialerController.new,
);

/// Die eingegebene Rufnummer im Wählfeld.
class DialerController extends Notifier<String> {
  static const maxLength = 32;

  @override
  String build() => '';

  void append(String key) {
    if (state.length >= maxLength) return;
    state = state + key;
  }

  /// Langes Drücken auf "0" ersetzt die eben getippte 0 durch "+".
  void replaceLast(String key) {
    if (state.isEmpty) return append(key);
    state = state.substring(0, state.length - 1) + key;
  }

  void backspace() {
    if (state.isEmpty) return;
    state = state.substring(0, state.length - 1);
  }

  void clear() => state = '';

  void set(String value) => state = value;
}

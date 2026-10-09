import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../core/platform.dart';

// ---------------------------------------------------------------- winmm.dll
typedef _PlaySoundC = Int32 Function(Pointer<Utf16>, IntPtr, Uint32);
typedef _PlaySoundDart = int Function(Pointer<Utf16>, int, int);

const _sndAsync = 0x0001;
const _sndNoDefault = 0x0002;
const _sndLoop = 0x0008;
const _sndFilename = 0x00020000;

// ---------------------------------------------------------------- user32.dll
final class _FlashWInfo extends Struct {
  @Uint32()
  external int cbSize;
  @IntPtr()
  external int hwnd;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int uCount;
  @Uint32()
  external int dwTimeout;
}

typedef _FindWindowC = IntPtr Function(Pointer<Utf16>, Pointer<Utf16>);
typedef _FindWindowDart = int Function(Pointer<Utf16>, Pointer<Utf16>);
typedef _FlashC = Int32 Function(Pointer<_FlashWInfo>);
typedef _FlashDart = int Function(Pointer<_FlashWInfo>);
typedef _HwndIntC = Int32 Function(IntPtr, Int32);
typedef _HwndIntDart = int Function(int, int);
typedef _HwndC = Int32 Function(IntPtr);
typedef _HwndDart = int Function(int);

const _flashStop = 0;
const _flashAll = 3;
const _flashTimerNoFg = 12;
const _swRestore = 9;
const _swShow = 5;

/// Klingelton über `PlaySound` (Windows-Standardausgabe) und blinkende
/// Taskleiste bei eingehenden Anrufen. Nur unter Windows aktiv.
abstract final class DesktopShell {
  static final _winmm = isWindows ? DynamicLibrary.open('winmm.dll') : null;
  static final _user32 = isWindows ? DynamicLibrary.open('user32.dll') : null;

  static final _playSound = _winmm!.lookupFunction<_PlaySoundC, _PlaySoundDart>(
    'PlaySoundW',
  );
  static final _findWindow = _user32!
      .lookupFunction<_FindWindowC, _FindWindowDart>('FindWindowW');
  static final _flash = _user32!.lookupFunction<_FlashC, _FlashDart>(
    'FlashWindowEx',
  );
  static final _showWindow = _user32!.lookupFunction<_HwndIntC, _HwndIntDart>(
    'ShowWindow',
  );
  static final _isIconic = _user32!.lookupFunction<_HwndC, _HwndDart>(
    'IsIconic',
  );
  static final _setForeground = _user32!.lookupFunction<_HwndC, _HwndDart>(
    'SetForegroundWindow',
  );
  static final _isVisible = _user32!.lookupFunction<_HwndC, _HwndDart>(
    'IsWindowVisible',
  );

  static Future<String> _writeTemp(Uint8List wav, String name) async {
    final file = File('${Directory.systemTemp.path}\\haustelefon_$name.wav');
    await file.writeAsBytes(wav, flush: true);
    return file.path;
  }

  static void _play(String path, int flags) {
    final p = path.toNativeUtf16();
    try {
      _playSound(p, 0, flags);
    } finally {
      calloc.free(p);
    }
  }

  static Future<void> playLoop(Uint8List wav, String name) async {
    if (!isWindows) return;
    final path = await _writeTemp(wav, name);
    _play(path, _sndFilename | _sndAsync | _sndLoop | _sndNoDefault);
  }

  static Future<void> playOnce(Uint8List wav, String name) async {
    if (!isWindows) return;
    final path = await _writeTemp(wav, name);
    _play(path, _sndFilename | _sndAsync | _sndNoDefault);
  }

  static void stopSound() {
    if (!isWindows) return;
    _playSound(nullptr, 0, 0);
  }

  static int _hwnd() {
    final cls = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
    try {
      return _findWindow(cls, nullptr);
    } finally {
      calloc.free(cls);
    }
  }

  /// `true`: Fenster wiederherstellen + Taskleiste blinken lassen.
  static void attention(bool on) {
    if (!isWindows) return;
    final hwnd = _hwnd();
    if (hwnd == 0) return;
    if (on) {
      // Versteckt im Infobereich → wieder anzeigen.
      if (_isVisible(hwnd) == 0) _showWindow(hwnd, _swShow);
      if (_isIconic(hwnd) != 0) _showWindow(hwnd, _swRestore);
      _setForeground(hwnd);
    }
    final info = calloc<_FlashWInfo>();
    try {
      info.ref
        ..cbSize = sizeOf<_FlashWInfo>()
        ..hwnd = hwnd
        ..dwFlags = on ? (_flashAll | _flashTimerNoFg) : _flashStop
        ..uCount = 0
        ..dwTimeout = 0;
      _flash(info);
    } finally {
      calloc.free(info);
    }
  }
}

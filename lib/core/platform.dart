import 'package:flutter/foundation.dart';

/// PC-Plattformen (Geräteauswahl, Klingelton per Lautsprecher, Tastatur).
bool get isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

bool get isWindows =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

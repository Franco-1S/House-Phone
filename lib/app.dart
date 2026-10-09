import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n.dart';
import 'core/reveal_route.dart';
import 'core/theme.dart';
import 'state/audio_settings_controller.dart';
import 'state/call_controller.dart';
import 'state/connection_controller.dart';
import 'state/desktop_controller.dart';
import 'state/locale_controller.dart';
import 'state/providers.dart';
import 'ui/call/call_page.dart';
import 'ui/dialer/dialer_page.dart';

class HaustelefonApp extends ConsumerStatefulWidget {
  const HaustelefonApp({super.key});

  @override
  ConsumerState<HaustelefonApp> createState() => _HaustelefonAppState();
}

class _HaustelefonAppState extends ConsumerState<HaustelefonApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycle;
  Route<void>? _callRoute;

  @override
  void initState() {
    super.initState();
    // Gespeicherte Audiogeräte (PC) gleich beim Start aktivieren.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioServiceProvider).applyDevices(ref.read(audioPrefsProvider));
    });
    // Zurück im Vordergrund → Registrierung prüfen (Socket kann im
    // Hintergrund vom OS gekappt worden sein, z. B. nach VPN-Reconnect).
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(connectionProvider.notifier).ensureConnected(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onCallChanged(ActiveCall? prev, ActiveCall? next) {
    final nav = _navigator.currentState;
    if (nav == null) return;

    if (next != null && _callRoute == null) {
      // Eingehende Anrufe "platzen" aus der Bildschirmmitte auf,
      // ausgehende aus dem Anruf-Button.
      final route = RevealRoute<void>(
        origin: next.incoming ? null : RevealOrigin.value,
        builder: (_) => const CallPage(),
      );
      _callRoute = route;
      nav.push(route);
    } else if (next == null && _callRoute != null) {
      final route = _callRoute!;
      _callRoute = null;
      if (route.isCurrent) {
        nav.pop();
      } else if (route.isActive) {
        nav.removeRoute(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Startet den Verbindungs-Controller sofort (Auto-Registrierung beim Start).
    ref.watch(connectionProvider);
    // Windows: Symbol im Infobereich (Status, Texte, Minimieren).
    ref.watch(trayBindingProvider);
    ref.listen<ActiveCall?>(callProvider, _onCallChanged);

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      // Deutsch / Englisch; null = Systemsprache (Fallback Englisch).
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: (device, supported) =>
          resolveSystemLocale([?device]),
      navigatorKey: _navigator,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const DialerPage(),
    );
  }
}

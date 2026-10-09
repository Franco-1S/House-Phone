import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'providers.dart';

enum AppLanguage { system, de, en }

final languageProvider = NotifierProvider<LanguageController, AppLanguage>(
  LanguageController.new,
);

/// Gewählte App-Sprache (Standard: wie das Betriebssystem).
class LanguageController extends Notifier<AppLanguage> {
  static const _key = 'ui.language';

  @override
  AppLanguage build() {
    final stored = ref.read(sharedPreferencesProvider).getString(_key);
    return AppLanguage.values.firstWhere(
      (l) => l.name == stored,
      orElse: () => AppLanguage.system,
    );
  }

  Future<void> set(AppLanguage language) async {
    state = language;
    await ref.read(sharedPreferencesProvider).setString(_key, language.name);
  }
}

/// `null` = Systemsprache (MaterialApp wählt selbst).
final localeProvider = Provider<Locale?>((ref) {
  return switch (ref.watch(languageProvider)) {
    AppLanguage.system => null,
    AppLanguage.de => const Locale('de'),
    AppLanguage.en => const Locale('en'),
  };
});

/// Übersetzungen auch außerhalb von Widgets (Benachrichtigungen u. Ä.).
final l10nProvider = Provider<AppLocalizations>((ref) {
  final chosen = ref.watch(localeProvider);
  return lookupAppLocalizations(chosen ?? resolveSystemLocale());
});

/// Systemsprache auf eine unterstützte Sprache abbilden (Fallback Englisch).
Locale resolveSystemLocale([List<Locale>? preferred]) {
  final supported = AppLocalizations.supportedLocales
      .map((l) => l.languageCode)
      .toSet();
  for (final l in preferred ?? PlatformDispatcher.instance.locales) {
    if (supported.contains(l.languageCode)) return Locale(l.languageCode);
  }
  return const Locale('en');
}

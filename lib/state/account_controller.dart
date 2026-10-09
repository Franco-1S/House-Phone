import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sip_account.dart';
import 'providers.dart';

/// Die gespeicherte SIP-Nebenstelle (oder `null`, falls noch nicht eingerichtet).
final accountProvider = AsyncNotifierProvider<AccountController, SipAccount?>(
  AccountController.new,
);

class AccountController extends AsyncNotifier<SipAccount?> {
  @override
  Future<SipAccount?> build() =>
      ref.read(settingsRepositoryProvider).loadAccount();

  /// Speichert und löst damit automatisch eine Neu-Registrierung aus
  /// (der ConnectionController hört auf diesen Provider).
  Future<void> save(SipAccount account) async {
    await ref.read(settingsRepositoryProvider).saveAccount(account);
    state = AsyncData(account);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../state/call_controller.dart';
import '../../state/connection_controller.dart';
import '../../state/dialer_controller.dart';

/// Ruft [number] an – oder übernimmt sie ins Wählfeld, wenn gerade keine
/// Verbindung zur Telefonanlage besteht.
void startCall(BuildContext context, WidgetRef ref, String number) {
  Haptics.press();
  if (!ref.read(connectionProvider).isRegistered) {
    ref.read(dialerProvider.notifier).set(number);
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xEE1A1C2B),
          content: Text(
            context.l10n.notConnectedCopied,
            style: const TextStyle(color: AppColors.text),
          ),
        ),
      );
    return;
  }
  ref.read(callProvider.notifier).dial(number);
}

/// Einheitliche Snackbar für kurze Bestätigungen.
void showInfo(BuildContext context, String text, {IconData? icon}) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xEE1A1C2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.green),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(text, style: const TextStyle(color: AppColors.text)),
            ),
          ],
        ),
      ),
    );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme.dart';
import '../../data/contacts.dart';
import '../../state/call_controller.dart';
import '../../state/call_log_controller.dart';
import '../../state/connection_controller.dart';
import '../../state/contacts_controller.dart';
import '../../state/dialer_controller.dart';
import '../../state/account_controller.dart';
import '../../state/provisioning_controller.dart';
import '../../data/provisioning.dart';
import '../../state/providers.dart';
import '../contacts/contacts_view.dart';
import '../history/call_history.dart';
import '../settings/audio_settings_page.dart';
import '../settings/settings_page.dart';
import '../setup/setup_page.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass.dart';
import '../widgets/status_pill.dart';
import 'call_fab.dart';
import 'dial_pad.dart';
import 'number_display.dart';

class DialerPage extends ConsumerStatefulWidget {
  const DialerPage({super.key});

  @override
  ConsumerState<DialerPage> createState() => _DialerPageState();
}

class _DialerPageState extends ConsumerState<DialerPage> {
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    // Global statt per Focus-Widget: funktioniert unabhängig davon, wo
    // zuletzt hingeklickt wurde – reagiert aber nur, wenn diese Seite oben liegt.
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerSetupOnce());
  }

  /// Beim allerersten Start ohne Konfiguration den Assistenten zeigen.
  Future<void> _offerSetupOnce() async {
    const key = 'setup.offered';
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(key) ?? false) return;
    final account = await ref.read(accountProvider.future);
    if (!mounted || account != null) return;
    await prefs.setBool(key, true);
    if (!mounted) return;
    _openSetup();
  }

  void _openSetup() {
    Haptics.tick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SetupPage()));
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent e) {
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    return _onKey(e) == KeyEventResult.handled;
  }

  void _call() {
    final number = ref.read(dialerProvider);
    final status = ref.read(connectionProvider);

    if (number.isEmpty) {
      // Wahlwiederholung wie beim iPhone: leeres Feld + Anruf = letzte Nummer.
      final last = ref.read(settingsRepositoryProvider).lastDialed;
      if (last != null && last.isNotEmpty) {
        ref.read(dialerProvider.notifier).set(last);
      } else {
        setState(() => _shake++);
      }
      return;
    }
    if (!status.isRegistered) {
      setState(() => _shake++);
      _toast(
        context.l10n.linkDetail(status) ?? context.l10n.linkTitle(status.phase),
      );
      return;
    }
    ref.read(callProvider.notifier).dial(number);
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xEE1A1C2B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(text, style: const TextStyle(color: AppColors.text)),
        ),
      );
  }

  void _openSettings() {
    Haptics.tick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  void _openAudio() {
    Haptics.tick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AudioSettingsPage()));
  }

  void _openContacts() {
    Haptics.tick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ContactsPage()));
  }

  void _openHistory() {
    Haptics.tick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CallHistoryPage()));
  }

  /// PC-Tastatur: Ziffern tippen, Enter = anrufen, Esc = leeren,
  /// Rücktaste = löschen, Strg+V = Nummer einfügen.
  KeyEventResult _onKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (ref.read(callProvider) != null) return KeyEventResult.ignored;
    final dialer = ref.read(dialerProvider.notifier);
    final k = e.logicalKey;
    final hw = HardwareKeyboard.instance;

    if ((hw.isControlPressed || hw.isMetaPressed) &&
        k == LogicalKeyboardKey.keyV) {
      Clipboard.getData(Clipboard.kTextPlain).then((data) {
        final text = data?.text ?? '';
        final cleaned = text.replaceAll(RegExp(r'[^0-9*#+]'), '');
        if (cleaned.isNotEmpty) dialer.set(cleaned);
      });
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace) {
      dialer.backspace();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      _call();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      dialer.clear();
      return KeyEventResult.handled;
    }
    final ch = e.character;
    if (ch != null && RegExp(r'^[0-9*#+]$').hasMatch(ch)) {
      dialer.append(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectionProvider);

    final aurora = switch (status.phase) {
      LinkPhase.registered => AppColors.auroraIdle,
      LinkPhase.connecting => AppColors.auroraWarn,
      LinkPhase.failed || LinkPhase.offline => AppColors.auroraError,
      LinkPhase.unconfigured => AppColors.auroraIdle,
    };

    return Scaffold(
      body: AuroraBackground(
        colors: aurora,
        intensity: status.isRegistered ? 1 : 0.75,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              // Breites Fenster (PC/Tablet): Anrufliste links, Wählfeld rechts.
              final wide = c.maxWidth >= 860;
              final dialer = _dialerColumn(c.maxHeight, wide: wide);
              if (!wide) return dialer;
              return Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 0, 16),
                      child: Glass(
                        radius: 30,
                        blur: 30,
                        padding: EdgeInsets.only(top: 12),
                        child: _SidePanel(),
                      ),
                    ),
                  ),
                  SizedBox(width: 460, child: dialer),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _dialerColumn(double height, {required bool wide}) {
    final number = ref.watch(dialerProvider);
    final status = ref.watch(connectionProvider);
    final dialer = ref.read(dialerProvider.notifier);
    final lastDialed = ref.read(settingsRepositoryProvider).lastDialed;
    final compactHeight = height < 680;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill(),
                ),
              ),
              const SizedBox(width: 12),
              if (!wide) ...[
                GlassIconButton(
                  icon: Icons.contacts_rounded,
                  tooltip: context.l10n.contacts,
                  onTap: _openContacts,
                ),
                const SizedBox(width: 10),
                _HistoryButton(onTap: _openHistory),
                const SizedBox(width: 10),
              ],
              if (isDesktop) ...[
                GlassIconButton(
                  icon: Icons.headset_mic_rounded,
                  tooltip: context.l10n.audioAndRingtone,
                  onTap: _openAudio,
                ),
                const SizedBox(width: 10),
              ],
              GlassIconButton(
                icon: Icons.tune_rounded,
                tooltip: context.l10n.settings,
                onTap: _openSettings,
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          transitionBuilder: (child, a) => SizeTransition(
            sizeFactor: a,
            child: FadeTransition(opacity: a, child: child),
          ),
          child: status.phase == LinkPhase.unconfigured
              ? _SetupCard(onTap: _openSetup)
              : const SizedBox(width: double.infinity),
        ),
        const Spacer(),
        const SizedBox(height: 12),
        const _Brand(),
        SizedBox(height: compactHeight ? 8 : 18),
        NumberDisplay(
          number: number,
          shake: _shake,
          placeholder: context.l10n.enterNumber,
        ),
        SizedBox(
          height: 30,
          child: number.isEmpty
              ? AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: lastDialed != null ? 1 : 0,
                  child: Center(
                    child: Text(
                      context.l10n.redial(lastDialed ?? ''),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                )
              : _ContactHint(number: number),
        ),
        SizedBox(height: compactHeight ? 8 : 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: DialPad(
            maxKeySize: compactHeight ? 70 : 84,
            onKey: dialer.append,
            onLongPressZero: () => dialer.replaceLast('+'),
          ),
        ),
        SizedBox(height: compactHeight ? 4 : 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72, height: 72, child: _LineButton()),
            const SizedBox(width: 12),
            CallFab(
              enabled: status.isRegistered,
              onTap: _call,
              size: compactHeight ? 68 : 78,
            ),
            const SizedBox(width: 12),
            _BackspaceButton(
              visible: number.isNotEmpty,
              onTap: () {
                Haptics.tick();
                dialer.backspace();
              },
              onLongPress: () {
                Haptics.heavy();
                setState(() => _shake++);
                dialer.clear();
              },
            ),
          ],
        ),
        SizedBox(height: compactHeight ? 8 : 20),
      ],
    );
  }
}

/// Anrufliste-Button mit Zähler für verpasste Anrufe.
class _HistoryButton extends ConsumerWidget {
  const _HistoryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missed = ref.watch(unseenMissedProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GlassIconButton(
          icon: Icons.history_rounded,
          tooltip: context.l10n.callHistory,
          onTap: onTap,
        ),
        Positioned(
          right: -2,
          top: -2,
          child: AnimatedScale(
            scale: missed > 0 ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                missed > 9 ? '9+' : '$missed',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => AppColors.accentGradient.createShader(r),
      child: const Text(
        'HAUSTELEFON',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 6,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Glass(
          radius: 22,
          borderColor: AppColors.cyan.withValues(alpha: 0.35),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.accentGradient,
                ),
                child: const Icon(Icons.router_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.setupCardTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.setupCardSubtitle,
                      style: TextStyle(fontSize: 12, color: AppColors.textDim),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackspaceButton extends StatelessWidget {
  const _BackspaceButton({
    required this.visible,
    required this.onTap,
    required this.onLongPress,
  });

  final bool visible;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: AnimatedScale(
        scale: visible ? 1 : 0.4,
        duration: const Duration(milliseconds: 320),
        curve: visible ? Curves.easeOutBack : Curves.easeIn,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: IgnorePointer(
            ignoring: !visible,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onLongPress: onLongPress,
              child: const Icon(
                Icons.backspace_outlined,
                size: 26,
                color: AppColors.textDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// PC-Seitenleiste: Kontakte und Anrufliste, per Tab umschaltbar.
class _SidePanel extends StatefulWidget {
  const _SidePanel();

  @override
  State<_SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<_SidePanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Glass(
            radius: 18,
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              height: 44,
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutBack,
                    alignment: _tab == 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: const FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          gradient: AppColors.accentGradient,
                        ),
                      ),
                    ),
                  ),
                  // Über die volle Höhe, damit die Beschriftung mittig sitzt.
                  Positioned.fill(
                    child: Row(
                      children: [
                        _tabButton(
                          0,
                          Icons.contacts_rounded,
                          context.l10n.contacts,
                        ),
                        _tabButton(
                          1,
                          Icons.history_rounded,
                          context.l10n.callHistory,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
            child: _tab == 0
                ? const ContactsView(key: ValueKey('c'), showTitle: false)
                : const CallHistoryView(key: ValueKey('h'), showTitle: false),
          ),
        ),
      ],
    );
  }

  Widget _tabButton(int index, IconData icon, String label) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.tick();
          setState(() => _tab = index);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppColors.textDim,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : AppColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unter der Nummer: passender Kontakt oder "Als Kontakt speichern".
class _ContactHint extends ConsumerWidget {
  const _ContactHint({required this.number});
  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(contactBookProvider);
    final exact = book.lookup(number);
    final Widget child;
    if (exact != null) {
      child = _chip(
        key: ValueKey('exact${exact.$1.id}'),
        icon: Icons.check_circle_rounded,
        color: AppColors.green,
        text: '${exact.$1.name} · ${context.l10n.numberLabel(exact.$2.label)}',
        onTap: () => showContactSheet(context, exact.$1),
      );
    } else {
      final prefix = book.startingWith(number, max: 1);
      if (prefix.isNotEmpty) {
        final (c, n) = prefix.first;
        child = _chip(
          key: ValueKey('prefix${c.id}${n.number}'),
          icon: Icons.person_search_rounded,
          color: AppColors.cyan,
          text: '${c.name} · ${n.number}',
          onTap: () {
            Haptics.tick();
            ref.read(dialerProvider.notifier).set(normalizeDial(n.number));
          },
        );
      } else if (normalizeNumber(number).length >= 3) {
        child = _chip(
          key: const ValueKey('add'),
          icon: Icons.person_add_alt_1_rounded,
          color: AppColors.textDim,
          text: context.l10n.saveAsContact,
          onTap: () => openContactEditor(context, number: number),
        );
      } else {
        child = const SizedBox.shrink(key: ValueKey('none'));
      }
    }
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: a, child: c),
        ),
        child: child,
      ),
    );
  }

  Widget _chip({
    required Key key,
    required IconData icon,
    required Color color,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wählbare Form einer gespeicherten Nummer (ohne Leer-/Trennzeichen).
String normalizeDial(String n) => n.replaceAll(RegExp(r'[^0-9*#+]'), '');

/// Links neben dem Anruf-Button: über welche Rufnummer raustelefoniert wird.
/// Nur sichtbar, wenn der Server mehrere Leitungen freigibt.
class _LineButton extends ConsumerWidget {
  const _LineButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prov = ref.watch(provisioningProvider);
    if (!prov.hasMultipleLines) return const SizedBox.shrink();
    final selected = prov.line(ref.watch(selectedLineProvider));
    return Center(
      child: Tooltip(
        message: context.l10n.outgoingNumber,
        child: GestureDetector(
          onTap: () => _pickLine(context, ref, prov),
          child: Glass(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            borderColor: AppColors.cyan.withValues(alpha: 0.35),
            child: SizedBox(
              width: 56,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.call_made_rounded,
                    size: 14,
                    color: AppColors.cyan,
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      selected?.label ?? '—',
                      key: ValueKey(selected?.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickLine(
    BuildContext context,
    WidgetRef ref,
    Provisioning prov,
  ) {
    Haptics.tick();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheet) => Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(selectedLineProvider);
          return Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                child: Glass(
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 12),
                          child: Text(
                            context.l10n.callVia,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        for (final l in prov.lines)
                          _LineOption(
                            line: l,
                            selected: l.id == current,
                            isDefault: l.id == prov.defaultLine,
                            onTap: () {
                              Haptics.press();
                              ref
                                  .read(selectedLineProvider.notifier)
                                  .select(l.id);
                              Navigator.of(sheet).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LineOption extends StatelessWidget {
  const _LineOption({
    required this.line,
    required this.selected,
    required this.isDefault,
    required this.onTap,
  });

  final PhoneLine line;
  final bool selected;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected ? AppColors.accentGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 0 : 0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (line.number.isNotEmpty)
                      Text(
                        line.number,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.85)
                              : AppColors.textDim,
                        ),
                      ),
                  ],
                ),
              ),
              if (isDefault)
                Text(
                  context.l10n.defaultLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppColors.textFaint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

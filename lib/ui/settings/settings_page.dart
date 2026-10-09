import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme.dart';
import '../../data/sip_account.dart';
import '../../state/account_controller.dart';
import '../../state/desktop_controller.dart';
import '../../state/locale_controller.dart';
import '../../state/provisioning_controller.dart';
import '../setup/setup_page.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass.dart';
import '../widgets/status_pill.dart';
import 'audio_settings_page.dart';

/// Konfiguration der SIP-Nebenstelle.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _form = GlobalKey<FormState>();
  late SipTransport _transport;
  late final TextEditingController _wsUrl;
  late final TextEditingController _domain;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _authUser;
  late final TextEditingController _password;
  late final TextEditingController _displayName;
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final loaded = ref.read(accountProvider).value;
    _filled = loaded != null;
    final a = loaded ?? SipAccount.defaults();
    _transport = a.transport;
    _wsUrl = TextEditingController(text: a.wsUrl);
    _domain = TextEditingController(text: a.domain);
    _port = TextEditingController(text: a.port.toString());
    _user = TextEditingController(text: a.username);
    _authUser = TextEditingController(text: a.authUser);
    _password = TextEditingController(text: a.password);
    _displayName = TextEditingController(text: a.displayName);
  }

  /// `true`, sobald die Felder mit der gespeicherten Nebenstelle gefüllt sind.
  bool _filled = false;

  /// Falls die Seite geöffnet wurde, während noch geladen wird.
  void _fill(SipAccount a) {
    setState(() => _transport = a.transport);
    _wsUrl.text = a.wsUrl;
    _domain.text = a.domain;
    _port.text = a.port.toString();
    _user.text = a.username;
    _authUser.text = a.authUser;
    _password.text = a.password;
    _displayName.text = a.displayName;
  }

  @override
  void dispose() {
    for (final c in [
      _wsUrl,
      _domain,
      _port,
      _user,
      _authUser,
      _password,
      _displayName,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Füllt die Domain automatisch aus der WebSocket-URL, falls leer.
  void _syncDomainFromUrl(String url) {
    final host = Uri.tryParse(url.trim())?.host ?? '';
    if (host.isNotEmpty && _domain.text.trim().isEmpty) _domain.text = host;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      Haptics.error();
      return;
    }
    setState(() => _saving = true);
    final account = SipAccount(
      transport: _transport,
      wsUrl: _wsUrl.text.trim(),
      domain: _domain.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 5060,
      username: _user.text.trim(),
      authUser: _authUser.text.trim(),
      password: _password.text,
      displayName: _displayName.text.trim(),
    );
    // Anderer Server/Benutzer → Leitungen & Team vom alten Code verwerfen.
    final previous = ref.read(accountProvider).value;
    if (previous == null ||
        previous.username != account.username ||
        previous.wsUrl != account.wsUrl) {
      await ref.read(provisioningProvider.notifier).clear();
    }
    await ref.read(accountProvider.notifier).save(account);
    await Haptics.success();
    if (!mounted) return;
    setState(() => _saving = false);
    // Der ScaffoldMessenger lebt über den Routen → Hinweis bleibt nach dem Schließen sichtbar.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xEE1A1C2B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.savedConnecting,
                  style: const TextStyle(color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
      );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SipAccount?>>(accountProvider, (prev, next) {
      final a = next.value;
      if (!_filled && a != null) {
        _filled = true;
        _fill(a);
      }
    });
    final ws = _transport == SipTransport.websocket;
    final l10n = context.l10n;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuroraBackground(
        colors: AppColors.auroraIdle,
        intensity: 0.6,
        speed: 0.6,
        child: SafeArea(
          // Auf breiten PC-Fenstern nicht über die volle Breite ziehen.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Row(
                      children: [
                        GlassIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          l10n.extensionTitle,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () {
                        Haptics.tick();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const SetupPage(startWithCode: true),
                          ),
                        );
                      },
                      child: Glass(
                        radius: 20,
                        borderColor: AppColors.cyan.withValues(alpha: 0.35),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.qr_code_2_rounded,
                              color: AppColors.cyan,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.pasteSetupCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.pasteSetupCodeHint,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textDim,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(l10n.connectionType),
                    _TransportSwitch(
                      value: _transport,
                      onChanged: (t) {
                        Haptics.tick();
                        setState(() => _transport = t);
                      },
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                        child: Text(
                          ws ? l10n.transportWsHint : l10n.transportTcpHint,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: ws ? AppColors.textDim : AppColors.amber,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(l10n.server),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: ws
                          ? _GlassField(
                              key: const ValueKey('ws'),
                              controller: _wsUrl,
                              label: l10n.wsUrl,
                              hint: 'ws://192.168.2.50:8088/ws',
                              icon: Icons.hub_rounded,
                              keyboardType: TextInputType.url,
                              onChanged: _syncDomainFromUrl,
                              validator: (v) {
                                final u = Uri.tryParse(v?.trim() ?? '');
                                if (u == null ||
                                    !(u.scheme == 'ws' || u.scheme == 'wss') ||
                                    u.host.isEmpty) {
                                  return l10n.wsUrlInvalid;
                                }
                                return null;
                              },
                            )
                          : _GlassField(
                              key: const ValueKey('port'),
                              controller: _port,
                              label: l10n.sipPort,
                              hint: '5060',
                              icon: Icons.numbers_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) {
                                final p = int.tryParse(v ?? '');
                                return p == null || p < 1 || p > 65535
                                    ? l10n.invalidPort
                                    : null;
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    _GlassField(
                      controller: _domain,
                      label: ws ? l10n.sipDomain : l10n.registrar,
                      hint: ws ? '192.168.2.50' : l10n.registrarHint,
                      icon: Icons.dns_rounded,
                      keyboardType: TextInputType.url,
                      validator: _required,
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(l10n.credentials),
                    _GlassField(
                      controller: _user,
                      label: ws ? l10n.usernameGateway : l10n.userId,
                      hint: ws ? 'handy' : l10n.userIdHint,
                      icon: Icons.person_rounded,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    _GlassField(
                      controller: _password,
                      label: l10n.password,
                      icon: Icons.key_rounded,
                      obscure: _obscure,
                      validator: _required,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: AppColors.textDim,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GlassField(
                      controller: _authUser,
                      label: ws ? l10n.authUserOptional : l10n.authName,
                      hint: ws ? l10n.authUserHint : l10n.authNameHint,
                      icon: Icons.badge_rounded,
                    ),
                    const SizedBox(height: 12),
                    _GlassField(
                      controller: _displayName,
                      label: l10n.displayNameOptional,
                      hint: l10n.displayNameHint,
                      icon: Icons.label_rounded,
                    ),
                    const SizedBox(height: 28),
                    _SaveButton(saving: _saving, onTap: _save),
                    if (isDesktop) ...[
                      const SizedBox(height: 28),
                      _SectionLabel(l10n.audio),
                      GestureDetector(
                        onTap: () {
                          Haptics.tick();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AudioSettingsPage(),
                            ),
                          );
                        },
                        child: Glass(
                          radius: 20,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.headset_mic_rounded,
                                color: AppColors.cyan,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.audioAndRingtone,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.audioCardSubtitle,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textDim,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textDim,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (isWindows) ...[
                      const SizedBox(height: 28),
                      _SectionLabel(l10n.settingsPc),
                      const _DesktopOptions(),
                    ],
                    const SizedBox(height: 28),
                    _SectionLabel(l10n.language),
                    const _LanguageSwitch(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? context.l10n.required : null;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 2.4,
          fontWeight: FontWeight.w700,
          color: AppColors.textFaint,
        ),
      ),
    );
  }
}

class _TransportSwitch extends StatelessWidget {
  const _TransportSwitch({required this.value, required this.onChanged});
  final SipTransport value;
  final ValueChanged<SipTransport> onChanged;

  @override
  Widget build(BuildContext context) {
    final left = value == SipTransport.websocket;
    return Glass(
      radius: 20,
      padding: const EdgeInsets.all(5),
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              alignment: left ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: AppColors.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet.withValues(alpha: 0.4),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  _segment(
                    context.l10n.transportWs,
                    SipTransport.websocket,
                    left,
                  ),
                  _segment(context.l10n.transportTcp, SipTransport.tcp, !left),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, SipTransport t, bool selected) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(t),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : AppColors.textDim,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.obscure = false,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final bool obscure;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      autocorrect: false,
      enableSuggestions: !obscure,
      style: const TextStyle(fontSize: 15.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textFaint),
        labelStyle: const TextStyle(color: AppColors.textDim),
        floatingLabelStyle: const TextStyle(color: AppColors.cyan),
        prefixIcon: Icon(icon, color: AppColors.textDim, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        enabledBorder: border(Colors.white.withValues(alpha: 0.1)),
        focusedBorder: border(AppColors.cyan.withValues(alpha: 0.8), 1.4),
        errorBorder: border(AppColors.red.withValues(alpha: 0.7)),
        focusedErrorBorder: border(AppColors.red, 1.4),
        errorStyle: const TextStyle(color: AppColors.red),
      ),
    );
  }
}

class _SaveButton extends StatefulWidget {
  const _SaveButton({required this.saving, required this.onTap});
  final bool saving;
  final VoidCallback onTap;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  bool _down = false;

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.saving ? null : widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedBuilder(
          animation: _shine,
          builder: (context, child) {
            // Ein Lichtstreif wandert über den Button.
            final x = -1.5 + _shine.value * 3;
            return Container(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: AppColors.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.45),
                    blurRadius: 26,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment(x - 0.4, -1),
                  end: Alignment(x + 0.4, 1),
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.28),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
              child: child,
            );
          },
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: widget.saving
                  ? const SizedBox.square(
                      key: ValueKey('busy'),
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      context.l10n.saveAndConnect,
                      key: ValueKey('label'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// System / Deutsch / English – wirkt sofort in der ganzen App.
class _LanguageSwitch extends ConsumerWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    final labels = {
      AppLanguage.system: context.l10n.languageSystem,
      AppLanguage.de: 'Deutsch',
      AppLanguage.en: 'English',
    };
    return Glass(
      radius: 18,
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          for (final lang in AppLanguage.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Haptics.tick();
                  ref.read(languageProvider.notifier).set(lang);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: lang == current ? AppColors.accentGradient : null,
                  ),
                  child: Text(
                    labels[lang]!,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: lang == current
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: lang == current ? Colors.white : AppColors.textDim,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Windows: Infobereich & Autostart.
class _DesktopOptions extends ConsumerWidget {
  const _DesktopOptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(desktopPrefsProvider);
    final ctrl = ref.read(desktopPrefsProvider.notifier);
    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) => SwitchListTile.adaptive(
      value: value,
      activeThumbColor: AppColors.cyan,
      secondary: Icon(icon, color: AppColors.textDim),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textDim),
      ),
      onChanged: (v) {
        Haptics.tick();
        onChanged(v);
      },
    );
    return Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: [
          tile(
            icon: Icons.notifications_paused_rounded,
            title: context.l10n.closeToTray,
            subtitle: context.l10n.closeToTrayHint,
            value: prefs.closeToTray,
            onChanged: ctrl.setCloseToTray,
          ),
          tile(
            icon: Icons.power_settings_new_rounded,
            title: context.l10n.autostart,
            subtitle: context.l10n.autostartHint,
            value: prefs.autostart,
            onChanged: ctrl.setAutostart,
          ),
        ],
      ),
    );
  }
}

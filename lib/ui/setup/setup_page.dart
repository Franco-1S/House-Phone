import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../state/provisioning_controller.dart';
import '../settings/settings_page.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass.dart';
import '../widgets/start_call.dart';

/// Ersteinrichtung: Einrichtungscode vom Server einlösen oder manuell.
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key, this.startWithCode = false});

  /// Direkt das Code-Feld zeigen (z. B. aus den Einstellungen).
  final bool startWithCode;

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  late bool _codeMode = widget.startWithCode;
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    Haptics.tick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text case final text?) {
      setState(() {
        _code.text = text.trim();
        _error = null;
      });
    }
  }

  Future<void> _redeem() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(provisioningProvider.notifier)
          .redeem(_code.text);
      await Haptics.success();
      if (!mounted) return;
      final ext = r.provisioning.extension;
      showInfo(
        context,
        ext.isEmpty
            ? context.l10n.setupDoneUser(r.account.username)
            : context.l10n.setupDoneDevice(r.provisioning.deviceName, ext),
        icon: Icons.check_circle_rounded,
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FormatException {
      Haptics.error();
      setState(() => _error = context.l10n.setupInvalidCode);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _manual() {
    Haptics.tick();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        colors: AppColors.auroraIdle,
        intensity: 0.9,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GlassIconButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _Logo(),
                  const SizedBox(height: 22),
                  Text(
                    context.l10n.welcomeTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.welcomeBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textDim,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 30),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SizeTransition(sizeFactor: a, child: child),
                    ),
                    child: _codeMode ? _codeForm() : _choices(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choices() {
    return Column(
      key: const ValueKey('choices'),
      children: [
        _ChoiceCard(
          icon: Icons.qr_code_2_rounded,
          title: context.l10n.pasteSetupCode,
          subtitle: context.l10n.setupCodeChoiceHint,
          highlighted: true,
          onTap: () {
            Haptics.tick();
            setState(() => _codeMode = true);
          },
        ),
        const SizedBox(height: 14),
        _ChoiceCard(
          icon: Icons.tune_rounded,
          title: context.l10n.manualSetup,
          subtitle: context.l10n.manualSetupHint,
          onTap: _manual,
        ),
      ],
    );
  }

  Widget _codeForm() {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Glass(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          borderColor: _error != null
              ? AppColors.red.withValues(alpha: 0.6)
              : AppColors.cyan.withValues(alpha: 0.35),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  minLines: 3,
                  maxLines: 6,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    letterSpacing: 0.3,
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: const InputDecoration(
                    hintText: 'HT1.eyJ2IjoxLCJtb2RlIjoi…',
                    hintStyle: TextStyle(color: AppColors.textFaint),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.paste,
                onPressed: _paste,
                icon: const Icon(
                  Icons.content_paste_rounded,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: _error == null
              ? const SizedBox(height: 10)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _busy ? null : _redeem,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: AppColors.accentGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    context.l10n.setUp,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() {
            _codeMode = false;
            _error = null;
          }),
          child: Text(context.l10n.back),
        ),
      ],
    );
  }
}

class _Logo extends StatefulWidget {
  const _Logo();

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = Curves.easeInOut.transform(_c.value);
          return Transform.translate(
            offset: Offset(0, -6 * v),
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: AppColors.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.35 + 0.3 * v),
                    blurRadius: 30 + 24 * v,
                  ),
                ],
              ),
              child: const Icon(
                Icons.call_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChoiceCard extends StatefulWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 140),
        child: Glass(
          radius: 24,
          padding: const EdgeInsets.all(18),
          borderColor: widget.highlighted
              ? AppColors.cyan.withValues(alpha: 0.45)
              : null,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: widget.highlighted
                      ? AppColors.accentGradient
                      : null,
                  color: widget.highlighted
                      ? null
                      : Colors.white.withValues(alpha: 0.08),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textDim,
                      ),
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

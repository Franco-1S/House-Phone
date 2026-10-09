import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme.dart';
import '../../data/audio_prefs.dart';
import '../../services/audio_service.dart';
import '../../services/mic_test.dart';
import '../../state/audio_settings_controller.dart';
import '../../state/call_controller.dart';
import '../../state/providers.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass.dart';

/// Mikrofon, Lautsprecher, Lautstärke und Klingelton (vor allem für den PC).
/// Jede Änderung wird sofort gespeichert und angewendet.
class AudioSettingsPage extends ConsumerStatefulWidget {
  const AudioSettingsPage({super.key});

  @override
  ConsumerState<AudioSettingsPage> createState() => _AudioSettingsPageState();
}

class _AudioSettingsPageState extends ConsumerState<AudioSettingsPage> {
  final _test = MicTest();
  StreamSubscription<double>? _levelSub;
  double _level = 0;
  bool _testing = false;
  bool _monitor = false;
  String? _testError;

  @override
  void initState() {
    super.initState();
    _levelSub = _test.levels.listen((v) {
      if (mounted) setState(() => _level = v);
    });
  }

  @override
  void dispose() {
    _levelSub?.cancel();
    _test.dispose();
    super.dispose();
  }

  Future<void> _toggleTest() async {
    Haptics.press();
    if (_testing) {
      await _test.stop();
      setState(() => _testing = false);
      return;
    }
    setState(() {
      _testing = true;
      _testError = null;
    });
    try {
      await ref
          .read(audioServiceProvider)
          .applyDevices(ref.read(audioPrefsProvider));
      await _test.start(monitor: _monitor);
    } catch (e) {
      await _test.stop();
      if (mounted) {
        setState(() {
          _testing = false;
          _testError = context.l10n.micOpenFailed;
        });
      }
    }
  }

  Future<void> _restartTestIfRunning() async {
    if (!_testing) return;
    await _test.stop();
    await _test.start(monitor: _monitor);
  }

  Future<void> _update(AudioPrefs Function(AudioPrefs) change) async {
    Haptics.tick();
    await ref.read(audioPrefsProvider.notifier).update(change);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(audioPrefsProvider);
    final devices = ref.watch(audioDevicesProvider);
    final inCall = ref.watch(callProvider) != null;

    return Scaffold(
      body: AuroraBackground(
        colors: AppColors.auroraIdle,
        intensity: 0.6,
        speed: 0.6,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
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
                      Expanded(
                        child: Text(
                          context.l10n.audioAndRingtone,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GlassIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: context.l10n.rescanDevices,
                        onTap: () {
                          Haptics.tick();
                          ref.read(audioDevicesProvider.notifier).refresh();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      context.l10n.savedInstantly,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ------------------------------------------------ Mikrofon
                  _Label(context.l10n.microphone),
                  _DevicePicker(
                    icon: Icons.mic_rounded,
                    devices: devices.whenData((d) => d.inputs),
                    selected: prefs.inputId,
                    onChanged: (id) async {
                      await _update((p) => p.copyWith(inputId: id));
                      await _restartTestIfRunning();
                    },
                  ),
                  const SizedBox(height: 12),
                  Glass(
                    radius: 20,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LevelMeter(level: _testing ? _level : 0),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _PillButton(
                                icon: _testing
                                    ? Icons.stop_rounded
                                    : Icons.graphic_eq_rounded,
                                label: _testing
                                    ? context.l10n.stopTest
                                    : context.l10n.testMicrophone,
                                active: _testing,
                                enabled: !inCall,
                                onTap: _toggleTest,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _monitor,
                          activeThumbColor: AppColors.cyan,
                          title: Text(
                            context.l10n.hearMyself,
                            style: const TextStyle(fontSize: 14.5),
                          ),
                          subtitle: Text(
                            context.l10n.hearMyselfHint,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textDim,
                            ),
                          ),
                          onChanged: (v) async {
                            Haptics.tick();
                            setState(() => _monitor = v);
                            await _test.setMonitor(v);
                          },
                        ),
                        if (inCall)
                          Text(
                            context.l10n.notDuringCall,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.amber,
                            ),
                          ),
                        if (_testError != null)
                          Text(
                            _testError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),

                  // ------------------------------------------- Lautsprecher
                  _Label(context.l10n.speakerHeadphones),
                  _DevicePicker(
                    icon: Icons.headphones_rounded,
                    devices: devices.whenData((d) => d.outputs),
                    selected: prefs.outputId,
                    onChanged: (id) async {
                      await _update((p) => p.copyWith(outputId: id));
                      await _restartTestIfRunning();
                    },
                  ),
                  const SizedBox(height: 12),
                  _SliderCard(
                    icon: Icons.volume_up_rounded,
                    title: context.l10n.callVolume,
                    value: prefs.callVolume,
                    min: 0,
                    max: 2,
                    divisions: 20,
                    format: (v) => '${(v * 100).round()} %',
                    onChanged: (v) => ref
                        .read(audioPrefsProvider.notifier)
                        .update((p) => p.copyWith(callVolume: v)),
                  ),
                  const SizedBox(height: 26),

                  // ----------------------------------------------- Klingelton
                  _Label(context.l10n.ringtone),
                  _RingtonePicker(
                    value: prefs.ringtone,
                    onChanged: (r) async {
                      await _update((p) => p.copyWith(ringtone: r));
                      await ref
                          .read(audioServiceProvider)
                          .previewRingtone(r, prefs.ringVolume);
                    },
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: prefs.ringtone == Ringtone.off ? 0.4 : 1,
                    child: _SliderCard(
                      icon: Icons.notifications_active_rounded,
                      title: context.l10n.ringVolume,
                      value: prefs.ringVolume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      format: (v) => '${(v * 100).round()} %',
                      onChanged: (v) => ref
                          .read(audioPrefsProvider.notifier)
                          .update((p) => p.copyWith(ringVolume: v)),
                      onChangeEnd: (v) => ref
                          .read(audioServiceProvider)
                          .previewRingtone(prefs.ringtone, v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isWindows
                        ? context.l10n.ringtoneHintWindows
                        : context.l10n.ringtoneHintMobile,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textDim,
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
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
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

class _DevicePicker extends StatelessWidget {
  const _DevicePicker({
    required this.icon,
    required this.devices,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final AsyncValue<List<AudioDevice>> devices;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final list = devices.value ?? const <AudioDevice>[];
    final known = selected.isEmpty || list.any((d) => d.id == selected);
    return Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textDim, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: devices.isLoading && list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      context.l10n.searchingDevices,
                      style: const TextStyle(color: AppColors.textDim),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: known ? selected : '',
                      dropdownColor: const Color(0xFF15172A),
                      borderRadius: BorderRadius.circular(16),
                      iconEnabledColor: AppColors.textDim,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.text,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(context.l10n.systemDefaultDevice),
                        ),
                        for (final d in list)
                          DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              d.label.isEmpty
                                  ? context.l10n.unnamedDevice
                                  : d.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => onChanged(v ?? ''),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// LED-Pegel: 28 Segmente von grün über gelb nach rot.
class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.level});
  final double level;

  static const _segments = 28;

  @override
  Widget build(BuildContext context) {
    // Sprache liegt meist bei 0.05–0.4 → etwas verstärken für die Anzeige.
    final shown = (level * 2.2).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: shown),
      duration: const Duration(milliseconds: 110),
      builder: (context, v, _) {
        final lit = (v * _segments).round();
        return Row(
          children: [
            for (var i = 0; i < _segments; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i < lit
                        ? _color(i / _segments)
                        : Colors.white.withValues(alpha: 0.07),
                    boxShadow: i < lit
                        ? [
                            BoxShadow(
                              color: _color(
                                i / _segments,
                              ).withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ]
                        : const [],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static Color _color(double t) {
    if (t < 0.6) return Color.lerp(AppColors.green, AppColors.cyan, t / 0.6)!;
    if (t < 0.85) return AppColors.amber;
    return AppColors.red;
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: active
                ? const LinearGradient(colors: [AppColors.red, AppColors.pink])
                : AppColors.accentGradient,
            boxShadow: [
              BoxShadow(
                color: (active ? AppColors.red : AppColors.violet).withValues(
                  alpha: 0.4,
                ),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
    this.onChangeEnd,
  });

  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textDim, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
              Text(
                format(value),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.cyan,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.cyan,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor: AppColors.cyan.withValues(alpha: 0.15),
              trackHeight: 5,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingtonePicker extends StatelessWidget {
  const _RingtonePicker({required this.value, required this.onChanged});
  final Ringtone value;
  final ValueChanged<Ringtone> onChanged;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 18,
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          for (final r in Ringtone.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: r == value ? AppColors.accentGradient : null,
                  ),
                  child: Text(
                    context.l10n.ringtoneName(r),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: r == value
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: r == value ? Colors.white : AppColors.textDim,
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

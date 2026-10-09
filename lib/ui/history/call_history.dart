import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/call_log.dart';
import '../../data/contacts.dart';
import '../../state/call_log_controller.dart';
import '../../state/contacts_controller.dart';
import '../contacts/contacts_view.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass.dart';
import '../widgets/start_call.dart';

/// Vollbild-Variante für das Handy (aus dem Wählfeld geöffnet).
class CallHistoryPage extends StatelessWidget {
  const CallHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        colors: AppColors.auroraIdle,
        intensity: 0.65,
        speed: 0.7,
        child: SafeArea(
          child: CallHistoryView(
            leading: GlassIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            onCallStarted: () {},
          ),
        ),
      ),
    );
  }
}

/// Die eigentliche Liste – auch als Seitenleiste in der PC-Ansicht genutzt.
class CallHistoryView extends ConsumerStatefulWidget {
  const CallHistoryView({
    super.key,
    this.leading,
    this.onCallStarted,
    this.showTitle = true,
  });

  final Widget? leading;
  final VoidCallback? onCallStarted;
  final bool showTitle;

  @override
  ConsumerState<CallHistoryView> createState() => _CallHistoryViewState();
}

class _CallHistoryViewState extends ConsumerState<CallHistoryView> {
  bool _missedOnly = false;

  @override
  void initState() {
    super.initState();
    // Öffnen der Liste = verpasste Anrufe gesehen (Badge verschwindet).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(callLogProvider.notifier).markSeen();
    });
  }

  void _callBack(CallLogEntry e) {
    startCall(context, ref, e.number);
    widget.onCallStarted?.call();
  }

  Future<void> _confirmClear() async {
    Haptics.tick();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14151F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(context.l10n.clearHistoryTitle),
        content: Text(
          context.l10n.clearHistoryBody,
          style: const TextStyle(color: AppColors.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(context.l10n.clear),
          ),
        ],
      ),
    );
    if (ok == true) {
      Haptics.heavy();
      ref.read(callLogProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(callLogProvider);
    final book = ref.watch(contactBookProvider);
    final entries = _missedOnly ? all.where((e) => e.isMissed).toList() : all;

    // Nach Tagen gruppieren (Liste ist bereits neueste-zuerst sortiert).
    final rows = <Object>[];
    String? lastDay;
    for (final e in entries) {
      final day = Fmt.day(e.startedAt, context.l10n);
      if (day != lastDay) {
        rows.add(day);
        lastDay = day;
      }
      rows.add(e);
    }

    final clearButton = AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: all.isEmpty ? 0 : 1,
      child: GlassIconButton(
        icon: Icons.delete_sweep_rounded,
        tooltip: context.l10n.clearList,
        onTap: all.isEmpty ? () {} : _confirmClear,
      ),
    );
    final filter = _FilterSwitch(
      missedOnly: _missedOnly,
      missedCount: all.where((e) => e.isMissed).length,
      onChanged: (v) {
        Haptics.tick();
        setState(() => _missedOnly = v);
      },
    );

    return Column(
      children: [
        if (widget.showTitle) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Text(
                    context.l10n.callHistory,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                clearButton,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: filter,
          ),
        ] else
          // Kompakt (PC-Seitenleiste): Filter und Papierkorb in einer Zeile.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(child: filter),
                const SizedBox(width: 10),
                clearButton,
              ],
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: rows.isEmpty
                ? _EmptyState(
                    key: ValueKey('empty$_missedOnly'),
                    missedOnly: _missedOnly,
                  )
                : ListView.builder(
                    key: ValueKey('list$_missedOnly'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      final child = row is String
                          ? _DayHeader(row)
                          : _EntryTile(
                              entry: row as CallLogEntry,
                              contact: book.lookup(row.number)?.$1,
                              onCall: () => _callBack(row),
                              onContact: () {
                                final c = book.lookup(row.number)?.$1;
                                c != null
                                    ? showContactSheet(context, c)
                                    : openContactEditor(
                                        context,
                                        number: row.number,
                                      );
                              },
                              onDelete: () => ref
                                  .read(callLogProvider.notifier)
                                  .remove(row.id),
                            );
                      return _Stagger(index: i, child: child);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// Einträge gleiten nacheinander herein.
class _Stagger extends StatelessWidget {
  const _Stagger({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ms = 320 + math.min(index, 12) * 55;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
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

class _EntryTile extends StatefulWidget {
  const _EntryTile({
    required this.entry,
    required this.onCall,
    required this.onDelete,
    required this.onContact,
    this.contact,
  });

  final CallLogEntry entry;
  final Contact? contact;
  final VoidCallback onCall;
  final VoidCallback onDelete;

  /// Kontakt öffnen bzw. (unbekannte Nummer) als Kontakt speichern.
  final VoidCallback onContact;

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final (icon, color, label) = switch (e.outcome) {
      CallOutcome.answered when e.incoming => (
        Icons.call_received_rounded,
        AppColors.cyan,
        context.l10n.logIncoming(Fmt.duration(e.duration)),
      ),
      CallOutcome.answered => (
        Icons.call_made_rounded,
        AppColors.green,
        context.l10n.logOutgoing(Fmt.duration(e.duration)),
      ),
      CallOutcome.missed => (
        Icons.call_missed_rounded,
        AppColors.red,
        context.l10n.logMissed,
      ),
      CallOutcome.declined => (
        Icons.call_end_rounded,
        AppColors.amber,
        context.l10n.logDeclined,
      ),
      CallOutcome.canceled => (
        Icons.call_missed_outgoing_rounded,
        AppColors.textDim,
        context.l10n.logCanceled,
      ),
      CallOutcome.failed => (
        Icons.call_missed_outgoing_rounded,
        AppColors.amber,
        context.l10n.logDetail(e),
      ),
    };
    // Telefonbuch hat Vorrang vor dem beim Anruf übermittelten Namen.
    final title = widget.contact?.name ?? e.title;
    final showNumber = title != e.number;

    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        Haptics.press();
        widget.onDelete();
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              AppColors.red.withValues(alpha: 0),
              AppColors.red.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onCall,
        onLongPress: widget.onContact,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 140),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Glass(
              radius: 22,
              blur: 14,
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              borderColor: e.isMissed
                  ? AppColors.red.withValues(alpha: 0.35)
                  : null,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.14),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: e.isMissed ? AppColors.red : AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (showNumber) e.number,
                            label,
                            if (e.line != null) e.line!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Fmt.time(e.startedAt),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textDim,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: widget.contact == null
                        ? context.l10n.saveAsContact
                        : context.l10n.showContact,
                    onPressed: widget.onContact,
                    icon: Icon(
                      widget.contact == null
                          ? Icons.person_add_alt_1_rounded
                          : Icons.person_rounded,
                      size: 20,
                      color: widget.contact == null
                          ? AppColors.cyan
                          : AppColors.textDim,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.green, AppColors.greenDeep],
                      ),
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      size: 19,
                      color: Color(0xFF02150D),
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

class _FilterSwitch extends StatelessWidget {
  const _FilterSwitch({
    required this.missedOnly,
    required this.missedCount,
    required this.onChanged,
  });

  final bool missedOnly;
  final int missedCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 18,
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: 40,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutBack,
              alignment: missedOnly
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: missedOnly
                        ? const LinearGradient(
                            colors: [AppColors.red, AppColors.pink],
                          )
                        : AppColors.accentGradient,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  _seg(
                    context.l10n.filterAll,
                    !missedOnly,
                    () => onChanged(false),
                  ),
                  _seg(
                    missedCount > 0
                        ? context.l10n.filterMissedCount(missedCount)
                        : context.l10n.filterMissed,
                    missedOnly,
                    () => onChanged(true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 13.5,
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

class _EmptyState extends StatefulWidget {
  const _EmptyState({super.key, required this.missedOnly});
  final bool missedOnly;

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = Curves.easeInOut.transform(_c.value);
              return Transform.translate(
                offset: Offset(0, -8 * v),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet.withValues(
                          alpha: 0.3 + 0.3 * v,
                        ),
                        blurRadius: 30 + 20 * v,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.missedOnly
                        ? Icons.check_rounded
                        : Icons.history_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          Text(
            widget.missedOnly
                ? context.l10n.historyEmptyMissedTitle
                : context.l10n.historyEmptyTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            widget.missedOnly
                ? context.l10n.historyEmptyMissedBody
                : context.l10n.historyEmptyBody,
            style: const TextStyle(color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/contacts.dart';
import '../../state/contacts_controller.dart';
import '../../state/provisioning_controller.dart';
import '../../data/provisioning.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass.dart';
import '../widgets/start_call.dart';
import 'contact_avatar.dart';
import 'contact_edit_page.dart';

/// Vollbild-Variante für das Handy.
class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        colors: AppColors.auroraIdle,
        intensity: 0.65,
        speed: 0.7,
        child: SafeArea(
          child: ContactsView(
            leading: GlassIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> openContactEditor(
  BuildContext context, {
  Contact? contact,
  String? number,
}) {
  Haptics.tick();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ContactEditPage(contact: contact, initialNumber: number),
    ),
  );
}

/// Telefonbuch – auch als Tab in der PC-Seitenleiste genutzt.
class ContactsView extends ConsumerStatefulWidget {
  const ContactsView({super.key, this.leading, this.showTitle = true});

  final Widget? leading;
  final bool showTitle;

  @override
  ConsumerState<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends ConsumerState<ContactsView> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Contact c) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    if (c.name.toLowerCase().contains(q)) return true;
    final digits = normalizeNumber(_query);
    return digits.isNotEmpty &&
        c.numbers.any((n) => normalizeNumber(n.number).contains(digits));
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(contactsProvider);
    final visible = all.where(_matches).toList();
    final favorites = _query.isEmpty
        ? all.where((c) => c.favorite).toList()
        : const <Contact>[];

    final rows = <Object>[];
    // Interne Teilnehmer (vom Server) zuerst.
    final team = ref
        .watch(provisioningProvider)
        .directory
        .where(
          (t) =>
              _query.isEmpty ||
              t.name.toLowerCase().contains(_query.toLowerCase()) ||
              t.extension.contains(_query),
        )
        .toList();
    if (team.isNotEmpty) {
      rows.add(context.l10n.team);
      rows.addAll(team);
    }
    String? letter;
    for (final c in visible) {
      if (c.letter != letter) {
        letter = c.letter;
        rows.add(letter);
      }
      rows.add(c);
    }

    final searchField = Glass(
      radius: 18,
      padding: EdgeInsets.zero,
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v.trim()),
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: context.l10n.searchContacts,
          hintStyle: const TextStyle(color: AppColors.textFaint),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textDim,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textDim,
                  ),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
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
                    context.l10n.contacts,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _AddButton(onTap: () => openContactEditor(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: searchField,
          ),
        ] else
          // Kompakt (PC-Seitenleiste): Suche und "+" in einer Zeile.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 10),
                _AddButton(onTap: () => openContactEditor(context)),
              ],
            ),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: favorites.isEmpty
              ? const SizedBox(width: double.infinity)
              : _FavoritesStrip(favorites: favorites),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: all.isEmpty && rows.isEmpty
                ? _Empty(
                    key: const ValueKey('empty'),
                    onAdd: () => openContactEditor(context),
                  )
                : rows.isEmpty
                ? Center(
                    key: const ValueKey('nohit'),
                    child: Text(
                      context.l10n.noMatch,
                      style: const TextStyle(color: AppColors.textDim),
                    ),
                  )
                : ListView.builder(
                    key: const ValueKey('list'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      return _Stagger(
                        index: i,
                        child: switch (row) {
                          String() => _LetterHeader(row),
                          DirectoryEntry() => _TeamTile(entry: row),
                          _ => _ContactTile(contact: row as Contact),
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.newContact,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.accentGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.violet.withValues(alpha: 0.45),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _FavoritesStrip extends ConsumerWidget {
  const _FavoritesStrip({required this.favorites});
  final List<Contact> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        itemCount: favorites.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final c = favorites[i];
          return _Stagger(
            index: i,
            child: GestureDetector(
              onTap: () => startCall(context, ref, c.primaryNumber),
              onLongPress: () => showContactSheet(context, c),
              child: SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ContactAvatar(
                          name: c.name,
                          initials: c.initials,
                          size: 56,
                          glow: true,
                        ),
                        const Positioned(
                          right: -2,
                          bottom: -2,
                          child: Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: AppColors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LetterHeader extends StatelessWidget {
  const _LetterHeader(this.letter);
  final String letter;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
    child: ShaderMask(
      shaderCallback: (r) => AppColors.accentGradient.createShader(r),
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _ContactTile extends ConsumerStatefulWidget {
  const _ContactTile({required this.contact});
  final Contact contact;

  @override
  ConsumerState<_ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends ConsumerState<_ContactTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    final first = c.numbers.isEmpty ? null : c.numbers.first;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () => showContactSheet(context, c),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 140),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Glass(
            radius: 22,
            blur: 14,
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                ContactAvatar(name: c.name, initials: c.initials),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (c.favorite) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppColors.amber,
                            ),
                          ],
                        ],
                      ),
                      if (first != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          c.numbers.length > 1
                              ? '${context.l10n.numberLabel(first.label)} · ${first.number}  +${c.numbers.length - 1}'
                              : '${context.l10n.numberLabel(first.label)} · ${first.number}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (first != null)
                  _CallBubble(
                    onTap: () => startCall(context, ref, first.number),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallBubble extends StatelessWidget {
  const _CallBubble({required this.onTap, this.size = 40});
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.green, AppColors.greenDeep],
        ),
      ),
      child: Icon(
        Icons.call_rounded,
        size: size * 0.48,
        color: const Color(0xFF02150D),
      ),
    ),
  );
}

/// Detailansicht als Glas-Sheet: Nummern anrufen, Favorit, bearbeiten, löschen.
Future<void> showContactSheet(BuildContext context, Contact contact) {
  Haptics.tick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        // Live-Version (z. B. nach Favorit-Umschalten).
        final c = ref
            .watch(contactsProvider)
            .firstWhere((x) => x.id == contact.id, orElse: () => contact);
        return Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              child: Glass(
                radius: 30,
                blur: 30,
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ContactAvatar(
                        name: c.name,
                        initials: c.initials,
                        size: 84,
                        glow: true,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        c.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final n in c.numbers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Glass(
                            radius: 18,
                            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                            child: Row(
                              children: [
                                Icon(
                                  iconForNumberLabel(n.label),
                                  color: AppColors.cyan,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.numberLabel(n.label),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textDim,
                                        ),
                                      ),
                                      Text(
                                        n.number,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _CallBubble(
                                  size: 44,
                                  onTap: () {
                                    Navigator.of(sheetContext).pop();
                                    startCall(context, ref, n.number);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _SheetAction(
                            icon: c.favorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            label: c.favorite
                                ? context.l10n.favorite
                                : context.l10n.makeFavorite,
                            color: c.favorite ? AppColors.amber : null,
                            onTap: () {
                              Haptics.tick();
                              ref
                                  .read(contactsProvider.notifier)
                                  .toggleFavorite(c.id);
                            },
                          ),
                          _SheetAction(
                            icon: Icons.edit_rounded,
                            label: context.l10n.edit,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              openContactEditor(context, contact: c);
                            },
                          ),
                          _SheetAction(
                            icon: Icons.delete_outline_rounded,
                            label: context.l10n.delete,
                            color: AppColors.red,
                            onTap: () async {
                              final ok = await confirmDeleteContact(
                                sheetContext,
                                c,
                              );
                              if (ok != true) return;
                              Haptics.heavy();
                              await ref
                                  .read(contactsProvider.notifier)
                                  .delete(c.id);
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                          ),
                        ],
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

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, color: color ?? AppColors.text),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color ?? AppColors.textDim),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.45),
                    blurRadius: 36,
                  ),
                ],
              ),
              child: const Icon(
                Icons.contacts_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            context.l10n.contactsEmptyTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.contactsEmptyBody,
            style: const TextStyle(color: AppColors.textDim),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(context.l10n.addContact),
            style: TextButton.styleFrom(foregroundColor: AppColors.cyan),
          ),
        ],
      ),
    );
  }
}

class _Stagger extends StatelessWidget {
  const _Stagger({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ms = 320 + math.min(index, 12) * 50;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Interner Teilnehmer bzw. Gruppe mit Durchwahl.
class _TeamTile extends ConsumerWidget {
  const _TeamTile({required this.entry});
  final DirectoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = Contact(
      id: '',
      name: entry.name,
      numbers: const [],
    ).initials;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onTap: () => startCall(context, ref, entry.extension),
        child: Glass(
          radius: 22,
          blur: 14,
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              entry.isGroup
                  ? Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cyan.withValues(alpha: 0.14),
                        border: Border.all(
                          color: AppColors.cyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: AppColors.cyan,
                      ),
                    )
                  : ContactAvatar(name: entry.name, initials: initials),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.isGroup
                          ? context.l10n.groupExtension(entry.extension)
                          : context.l10n.extensionLabel(entry.extension),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              _CallBubble(
                onTap: () => startCall(context, ref, entry.extension),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

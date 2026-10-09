import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/contacts.dart';
import '../../state/contacts_controller.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass.dart';
import '../widgets/start_call.dart';
import 'contact_avatar.dart';

/// Kontakt anlegen ([contact] == null) oder bearbeiten.
class ContactEditPage extends ConsumerStatefulWidget {
  const ContactEditPage({super.key, this.contact, this.initialNumber});

  final Contact? contact;

  /// Vorbelegung, z. B. aus dem Wählfeld oder der Anrufliste.
  final String? initialNumber;

  @override
  ConsumerState<ContactEditPage> createState() => _ContactEditPageState();
}

class _NumberRow {
  _NumberRow(String number, this.label)
    : controller = TextEditingController(text: number);
  final TextEditingController controller;
  String label;
}

class _ContactEditPageState extends ConsumerState<ContactEditPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final List<_NumberRow> _rows;
  late bool _favorite;

  bool get _isNew => widget.contact == null;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _name = TextEditingController(text: c?.name ?? '')
      ..addListener(() => setState(() {}));
    _favorite = c?.favorite ?? false;
    _rows = c != null && c.numbers.isNotEmpty
        ? [for (final n in c.numbers) _NumberRow(n.number, n.label)]
        : [_NumberRow(widget.initialNumber ?? '', NumberLabel.mobile.name)];
  }

  @override
  void dispose() {
    _name.dispose();
    for (final r in _rows) {
      r.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      Haptics.error();
      return;
    }
    final numbers = [
      for (final r in _rows)
        if (r.controller.text.trim().isNotEmpty)
          ContactNumber(number: r.controller.text.trim(), label: r.label),
    ];
    final contact = Contact(
      id: widget.contact?.id ?? ContactsController.newId(),
      name: _name.text.trim(),
      numbers: numbers,
      favorite: _favorite,
    );
    await ref.read(contactsProvider.notifier).upsert(contact);
    await Haptics.success();
    if (!mounted) return;
    showInfo(
      context,
      _isNew
          ? context.l10n.contactSaved(contact.name)
          : context.l10n.changesSaved,
      icon: Icons.check_circle_rounded,
    );
    Navigator.of(context).pop(contact);
  }

  Future<void> _delete() async {
    final c = widget.contact;
    if (c == null) return;
    final ok = await confirmDeleteContact(context, c);
    if (ok != true || !mounted) return;
    Haptics.heavy();
    await ref.read(contactsProvider.notifier).delete(c.id);
    if (!mounted) return;
    showInfo(
      context,
      context.l10n.contactDeleted(c.name),
      icon: Icons.delete_rounded,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    final initials = name.isEmpty
        ? '+'
        : Contact(id: '', name: name, numbers: const []).initials;

    return Scaffold(
      body: AuroraBackground(
        colors: AppColors.auroraIdle,
        intensity: 0.6,
        speed: 0.6,
        child: SafeArea(
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
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _isNew
                                ? context.l10n.newContact
                                : context.l10n.editContact,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!_isNew)
                          GlassIconButton(
                            icon: Icons.delete_outline_rounded,
                            tooltip: context.l10n.delete,
                            onTap: _delete,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.6, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        builder: (context, v, child) =>
                            Transform.scale(scale: v, child: child),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: ContactAvatar(
                            key: ValueKey(initials + name),
                            name: name.isEmpty ? 'neu' : name,
                            initials: initials,
                            size: 96,
                            glow: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _Field(
                      controller: _name,
                      label: context.l10n.name,
                      icon: Icons.person_rounded,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.l10n.nameRequired
                          : null,
                    ),
                    const SizedBox(height: 22),
                    _Label(context.l10n.phoneNumbers),
                    for (var i = 0; i < _rows.length; i++) ...[
                      _NumberField(
                        key: ObjectKey(_rows[i]),
                        row: _rows[i],
                        canRemove: _rows.length > 1,
                        onLabel: (l) => setState(() => _rows[i].label = l),
                        onRemove: () => setState(() {
                          _rows.removeAt(i).controller.dispose();
                        }),
                        validator: (v) {
                          final filled = _rows
                              .where((r) => r.controller.text.trim().isNotEmpty)
                              .length;
                          if (filled == 0 && i == 0) {
                            return context.l10n.atLeastOneNumber;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          Haptics.tick();
                          setState(
                            () => _rows.add(
                              _NumberRow('', NumberLabel.landline.name),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: Text(context.l10n.addNumber),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.cyan,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Glass(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: SwitchListTile.adaptive(
                        value: _favorite,
                        activeThumbColor: AppColors.amber,
                        secondary: Icon(
                          _favorite ? Icons.star_rounded : Icons.star_border,
                          color: _favorite
                              ? AppColors.amber
                              : AppColors.textDim,
                        ),
                        title: Text(context.l10n.favorite),
                        subtitle: Text(
                          context.l10n.favoriteHint,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textDim,
                          ),
                        ),
                        onChanged: (v) {
                          Haptics.tick();
                          setState(() => _favorite = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: _save,
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
                        child: Text(
                          context.l10n.save,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sicherheitsabfrage vor dem Löschen (auch aus der Detailansicht genutzt).
Future<bool?> confirmDeleteContact(BuildContext context, Contact c) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF14151F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(context.l10n.deleteContactTitle(c.name)),
      content: Text(
        context.l10n.deleteContactBody,
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
          child: Text(context.l10n.delete),
        ),
      ],
    ),
  );
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

InputDecoration _decoration(String label, IconData? icon, {Widget? prefix}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textDim),
    floatingLabelStyle: const TextStyle(color: AppColors.cyan),
    prefixIcon:
        prefix ??
        (icon == null ? null : Icon(icon, color: AppColors.textDim, size: 20)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    enabledBorder: border(Colors.white.withValues(alpha: 0.1)),
    focusedBorder: border(AppColors.cyan.withValues(alpha: 0.8), 1.4),
    errorBorder: border(AppColors.red.withValues(alpha: 0.7)),
    focusedErrorBorder: border(AppColors.red, 1.4),
    errorStyle: const TextStyle(color: AppColors.red),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    textCapitalization: textCapitalization,
    style: const TextStyle(fontSize: 16),
    decoration: _decoration(label, icon),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.row,
    required this.canRemove,
    required this.onLabel,
    required this.onRemove,
    required this.validator,
  });

  final _NumberRow row;
  final bool canRemove;
  final ValueChanged<String> onLabel;
  final VoidCallback onRemove;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: row.controller,
            validator: validator,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9*#+ ()/-]')),
            ],
            style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
            decoration: _decoration(
              context.l10n.numberLabel(row.label),
              null,
              prefix: PopupMenuButton<String>(
                tooltip: context.l10n.numberType,
                color: const Color(0xFF15172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: onLabel,
                itemBuilder: (_) => [
                  for (final l in NumberLabel.values)
                    PopupMenuItem(
                      value: l.name,
                      child: Text(context.l10n.numberLabel(l.name)),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    _iconFor(row.label),
                    color: AppColors.cyan,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (canRemove)
          IconButton(
            padding: const EdgeInsets.only(top: 10, left: 4),
            onPressed: onRemove,
            icon: const Icon(
              Icons.remove_circle_outline_rounded,
              color: AppColors.textDim,
            ),
          ),
      ],
    );
  }
}

IconData _iconFor(String label) => switch (NumberLabel.parse(label)) {
  NumberLabel.mobile => Icons.smartphone_rounded,
  NumberLabel.landline => Icons.phone_rounded,
  NumberLabel.work => Icons.work_rounded,
  NumberLabel.internal => Icons.router_rounded,
  NumberLabel.other => Icons.tag_rounded,
};

/// Öffentliche Variante für andere Seiten.
IconData iconForNumberLabel(String label) => _iconFor(label);

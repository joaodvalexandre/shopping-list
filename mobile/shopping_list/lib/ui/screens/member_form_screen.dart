import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/family.dart';
import '../../data/me.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/family_dialogs.dart';
import '../widgets/top_bar.dart';

/// Add a member or edit one: name, email, role and, for a plain member, what they may do
/// with each type of list. The same form as the web's.
class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key, required this.listTypes, this.member});

  final List<FamilyListType> listTypes;
  final FamilyMember? member;

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late String _role;
  late final Map<int, Map<Ability, bool>> _permissions;

  bool _saving = false;
  String? _error;

  bool get _editing => widget.member != null;

  @override
  void initState() {
    super.initState();
    final member = widget.member;

    _name = TextEditingController(text: member?.name ?? '');
    _email = TextEditingController(text: member?.email ?? '');
    _role = member?.role ?? 'member';
    _permissions = {
      for (final type in widget.listTypes)
        type.id: {for (final ability in Ability.values) ability: member?.can(type.id, ability) ?? false},
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Any ability includes viewing, as on the web; taking viewing away takes everything away.
  void _toggle(int typeId, Ability ability, bool on) {
    final abilities = _permissions[typeId]!;

    setState(() {
      abilities[ability] = on;
      if (ability == Ability.view && !on) {
        for (final other in Ability.values) {
          abilities[other] = false;
        }
      } else if (on) {
        abilities[Ability.view] = true;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    final api = context.read<ApiClient>();
    final payload = memberPayload(name: _name.text, email: _email.text, role: _role, permissions: _permissions);

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_editing) {
        await api.updateMember(widget.member!.id, payload);
      } else {
        final created = await api.createMember(payload);
        if (!mounted) return;
        // Whoever is told the password is the one who hands it over
        await showTemporaryPassword(context, name: _name.text.trim(), email: _email.text.trim(), password: created['temporary_password'] as String);
      }

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.isOffline ? context.rt('app_cannot_reach') : e.firstMessage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final muted = dark ? Tw.gray400 : Tw.gray500;
    final own = widget.member != null && widget.member!.id == context.read<Repository>().me?.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t(_editing ? 'app_edit_member' : 'new_member'), style: const TextStyle(fontSize: 18)),
        actions: const [ThemeToggle(), SizedBox(width: 12)],
      ),
      body: SingleChildScrollView(
        padding: scrollPadding,
        child: Panel(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[Notice(_error!, error: true), const SizedBox(height: 16)],
                LabeledField(
                  label: context.t('name'),
                  controller: _name,
                  autofocus: !_editing,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    return text.isEmpty || text.length > 255 ? context.rt('app_required') : null;
                  },
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: context.t('email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text) ? null : context.rt('app_required');
                  },
                ),
                const SizedBox(height: 16),
                Text(context.t('role'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Tw.gray300 : Tw.gray700)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    DropdownMenuItem(value: 'member', child: Text(context.t('role_member'))),
                    DropdownMenuItem(value: 'admin', child: Text(context.t('role_admin'))),
                  ],
                  onChanged: (role) => setState(() => _role = role ?? _role),
                ),
                if (own) ...[
                  const SizedBox(height: 4),
                  Text('(${context.t('app_you')})', style: TextStyle(fontSize: 12, color: muted)),
                ],
                if (_role == 'admin') ...[
                  const SizedBox(height: 4),
                  Text(context.t('admin_role_help'), style: TextStyle(fontSize: 12, color: muted)),
                ] else ...[
                  const SizedBox(height: 20),
                  Text(context.t('permissions'), style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(context.t('permissions_help'), style: TextStyle(fontSize: 12, color: muted)),
                  const SizedBox(height: 12),
                  if (widget.listTypes.isEmpty) Text(context.t('no_list_types_yet'), style: TextStyle(color: muted)),
                  for (final type in widget.listTypes) _typePermissions(context, type),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: Text(context.t('go_back'))),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(context.t(_editing ? 'save' : 'create').toUpperCase()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One list type: its name, and a chip per ability to switch on or off.
  Widget _typePermissions(BuildContext context, FamilyListType type) {
    final abilities = _permissions[type.id]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final ability in Ability.values)
                FilterChip(
                  label: Text(context.t('ability_${abilityKeys[ability]}')),
                  selected: abilities[ability] ?? false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) => _toggle(type.id, ability, on),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

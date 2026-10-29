import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/top_bar.dart';

/// Create or edit a list: name, type (only when creating: a list never changes type),
/// and who it is hidden from (for surprises), exactly as on the web.
class ListFormScreen extends StatefulWidget {
  const ListFormScreen({super.key, this.listUuid});

  final String? listUuid;

  @override
  State<ListFormScreen> createState() => _ListFormScreenState();
}

class _ListFormScreenState extends State<ListFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late int? _typeId;
  late Set<int> _hidden;

  bool get _editing => widget.listUuid != null;

  @override
  void initState() {
    super.initState();
    final repository = context.read<Repository>();
    final list = _editing ? repository.list(widget.listUuid!) : null;

    _name = TextEditingController(text: list?.name ?? '');
    _typeId = list?.listTypeId ?? repository.me?.manageableTypeIds.firstOrNull;
    _hidden = {...?list?.hiddenFrom};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate() || _typeId == null) return;

    final repository = context.read<Repository>();

    if (_editing) {
      repository.updateList(widget.listUuid!, name: _name.text, hiddenFrom: _hidden.toList());
    } else {
      repository.createList(name: _name.text, listTypeId: _typeId!, hiddenFrom: _hidden.toList());
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<Repository>();
    final me = repository.me;
    final dark = context.isDark;
    final types = me?.manageableTypeIds ?? const <int>[];
    final members = me?.members ?? const [];
    final muted = dark ? Tw.gray400 : Tw.gray500;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t(_editing ? 'edit' : 'new_list'), style: const TextStyle(fontSize: 18)),
        actions: const [ThemeToggle(), SizedBox(width: 12)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Panel(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledField(
                  label: context.t('name'),
                  controller: _name,
                  autofocus: !_editing,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    return text.isEmpty || text.length > 255 ? context.rt('name') : null;
                  },
                ),
                const SizedBox(height: 16),
                Text(context.t('list_type'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Tw.gray300 : Tw.gray700)),
                const SizedBox(height: 4),
                if (_editing)
                  Text(repository.listTypeName(_typeId ?? 0), style: const TextStyle(fontSize: 16))
                else
                  DropdownButtonFormField<int>(
                    initialValue: _typeId,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: [for (final id in types) DropdownMenuItem(value: id, child: Text(repository.listTypeName(id)))],
                    onChanged: (value) => setState(() => _typeId = value),
                  ),
                if (members.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(context.t('hidden_from'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Tw.gray300 : Tw.gray700)),
                  const SizedBox(height: 2),
                  Text(context.t('hidden_from_help'), style: TextStyle(fontSize: 12, color: muted)),
                  for (final member in members)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      value: _hidden.contains(member.id),
                      title: Text(member.name),
                      onChanged: (checked) => setState(() => checked == true ? _hidden.add(member.id) : _hidden.remove(member.id)),
                    ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t('go_back'))),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _save, child: Text(context.t(_editing ? 'save' : 'create').toUpperCase())),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

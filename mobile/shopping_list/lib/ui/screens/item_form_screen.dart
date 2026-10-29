import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../widgets/common.dart';
import '../widgets/top_bar.dart';

/// Add or edit an item: name and quantity, as on the web.
class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({super.key, required this.listUuid, this.itemUuid});

  final String listUuid;
  final String? itemUuid;

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _quantity;

  bool get _editing => widget.itemUuid != null;

  @override
  void initState() {
    super.initState();
    final repository = context.read<Repository>();
    final item = _editing
        ? repository.itemsOf(widget.listUuid).where((i) => i.uuid == widget.itemUuid).firstOrNull
        : null;

    _name = TextEditingController(text: item?.name ?? '');
    _quantity = TextEditingController(text: '${item?.quantity ?? 1}');
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;

    final repository = context.read<Repository>();
    final quantity = int.parse(_quantity.text.trim());

    if (_editing) {
      repository.updateItem(widget.listUuid, widget.itemUuid!, name: _name.text, quantity: quantity);
    } else {
      repository.addItem(widget.listUuid, name: _name.text, quantity: quantity);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t(_editing ? 'edit' : 'new_item'), style: const TextStyle(fontSize: 18)),
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
                LabeledField(
                  label: context.t('name'),
                  controller: _name,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    return text.isEmpty || text.length > 255 ? context.rt('app_required') : null;
                  },
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: context.t('quantity'),
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  validator: (value) {
                    final number = int.tryParse((value ?? '').trim());
                    return number == null || number < 1 || number > 9999 ? context.rt('app_quantity_rule') : null;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t('back_to_list'))),
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

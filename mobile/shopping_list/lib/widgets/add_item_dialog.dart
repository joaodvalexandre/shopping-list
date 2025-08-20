import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class AddItemDialog extends StatefulWidget {
  final String? initialName;
  final String? initialQuantity;
  final String title;

  const AddItemDialog({
    super.key,
    this.initialName,
    this.initialQuantity,
    this.title = 'Add Shopping Item',
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    if (widget.initialQuantity != null) {
      _quantityController.text = widget.initialQuantity!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title == 'Add Item'
          ? (AppLocalizations.of(context)?.addItem ?? 'Add Item')
          : (AppLocalizations.of(context)?.editItem ?? 'Edit Item')),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.itemName ?? 'Item Name',
                  hintText: AppLocalizations.of(context)?.itemNameHint ?? 'e.g., Milk, Bread, Apples',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_cart_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppLocalizations.of(context)?.itemNameRequired ?? 'Please enter an item name';
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.quantity ?? 'Quantity',
                  hintText: AppLocalizations.of(context)?.quantityHint ?? '1',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'name': _nameController.text.trim(),
                'quantity': _quantityController.text.trim().isEmpty
                    ? '1'
                    : _quantityController.text.trim(),
              });
            }
          },
          child: Text(widget.initialName != null
              ? (AppLocalizations.of(context)?.update ?? 'Update')
              : (AppLocalizations.of(context)?.add ?? 'Add')),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class CreateShoppingListDialog extends StatefulWidget {
  final String? initialName;
  final bool isEditing;

  const CreateShoppingListDialog({
    super.key,
    this.initialName,
    this.isEditing = false,
  });

  @override
  State<CreateShoppingListDialog> createState() => _CreateShoppingListDialogState();
}

class _CreateShoppingListDialogState extends State<CreateShoppingListDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;

    return AlertDialog(
      title: Text(
        isEditing
          ? (AppLocalizations.of(context)?.editList ?? 'Edit List')
          : (AppLocalizations.of(context)?.createNewList ?? 'Create New List')
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)?.listName ?? 'List Name',
            hintText: AppLocalizations.of(context)?.listNameHint ?? 'e.g., Groceries, Home Supplies, Party Shopping',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return AppLocalizations.of(context)?.listNameRequired ?? 'Please enter a list name';
            }
            return null;
          },
          autofocus: true,
          textCapitalization: TextCapitalization.words,
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
              Navigator.of(context).pop(_nameController.text.trim());
            }
          },
          child: Text(
            isEditing
              ? (AppLocalizations.of(context)?.update ?? 'Update')
              : (AppLocalizations.of(context)?.create ?? 'Create')
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class CreateShoppingListDialog extends StatefulWidget {
  const CreateShoppingListDialog({super.key});

  @override
  State<CreateShoppingListDialog> createState() => _CreateShoppingListDialogState();
}

class _CreateShoppingListDialogState extends State<CreateShoppingListDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Shopping List'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Shopping List Name *',
            hintText: 'e.g., Groceries, Home Supplies, Party Shopping',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a shopping list name';
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_nameController.text.trim());
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

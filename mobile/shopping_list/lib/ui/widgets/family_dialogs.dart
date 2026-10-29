import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api_client.dart';
import '../theme.dart';
import 'common.dart';

/// Show a temporary password once, with a button to copy it: the person it is for has to be told.
Future<void> showTemporaryPassword(BuildContext context, {required String name, required String email, required String password}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final dark = dialogContext.isDark;

      return AlertDialog(
        title: Text(dialogContext.t('app_temp_password_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name · $email', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(dialogContext.t('temporary_password_notice'), style: TextStyle(fontSize: 13, color: dark ? Tw.gray400 : Tw.gray500)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: dark ? Tw.gray700 : Tw.gray100, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(password, style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: password));
              if (dialogContext.mounted) toast(dialogContext, dialogContext.rt('app_copied'));
            },
            child: Text(dialogContext.t('app_copy')),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(dialogContext.t('app_close'))),
        ],
      );
    },
  );
}

/// Ask for a single name (a list type's, a person's...). Returns true once [save] went through.
/// A refusal from the server (a name already used...) is shown under the field.
Future<bool> askListTypeName(BuildContext context, {required String title, String initial = '', required Future<void> Function(String name) save}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _NameDialog(title: title, initial: initial, save: save),
  );

  return saved ?? false;
}

/// The dialog is a widget of its own so that its text controller lives exactly as long as it does.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial, required this.save});

  final String title;
  final String initial;
  final Future<void> Function(String name) save;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return; // ("done" on the keyboard, then the button: one save)

    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 100) {
      setState(() => _error = context.rt('app_required'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.save(name);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.isOffline ? context.rt('app_cannot_reach') : e.firstMessage('name');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: context.t('name'), errorText: _error, isDense: true),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text(context.t('go_back'))),
        FilledButton(onPressed: _saving ? null : _submit, child: Text(context.t('save').toUpperCase())),
      ],
    );
  }
}

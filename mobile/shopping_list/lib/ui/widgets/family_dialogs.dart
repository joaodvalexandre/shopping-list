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

/// Ask for a single name (a list type's). Returns it once the server accepted it, else null.
/// [save] does the request; a refusal (a name already used...) is shown under the field.
Future<bool> askListTypeName(BuildContext context, {required String title, String initial = '', required Future<void> Function(String name) save}) async {
  final controller = TextEditingController(text: initial);
  String? error;
  var saving = false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> submit() async {
          final name = controller.text.trim();
          if (name.isEmpty || name.length > 100) {
            setState(() => error = context.rt('app_required'));
            return;
          }

          setState(() {
            saving = true;
            error = null;
          });

          try {
            await save(name);
            if (context.mounted) Navigator.pop(context, true);
          } on ApiException catch (e) {
            if (!context.mounted) return;
            setState(() {
              saving = false;
              error = e.isOffline ? context.rt('app_cannot_reach') : e.firstMessage('name');
            });
          }
        }

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submit(),
            decoration: InputDecoration(labelText: context.t('name'), errorText: error, isDense: true),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: Text(context.t('go_back'))),
            FilledButton(onPressed: saving ? null : submit, child: Text(context.t('save').toUpperCase())),
          ],
        );
      },
    ),
  );

  controller.dispose();
  return saved ?? false;
}

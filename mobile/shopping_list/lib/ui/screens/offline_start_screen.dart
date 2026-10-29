import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../peer/local_family.dart';
import '../../state/auth_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// Use the app with no account and no server: start a family that lives on its phones, or join
/// one with its code. Nothing is ever created on the web app or sent to it.
class OfflineStartScreen extends StatefulWidget {
  const OfflineStartScreen({super.key});

  @override
  State<OfflineStartScreen> createState() => _OfflineStartScreenState();
}

class _OfflineStartScreenState extends State<OfflineStartScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _familyName = TextEditingController();
  final _code = TextEditingController();

  bool _joining = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _familyName.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final auth = context.read<AuthState>();
    final navigator = Navigator.of(context);
    setState(() => _busy = true);

    try {
      if (_joining) {
        await auth.joinLocalFamily(myName: _name.text, code: _code.text);
      } else {
        final family = await auth.startLocalFamily(myName: _name.text, familyName: _familyName.text);
        if (!mounted) return;
        await showFamilyCode(context, family.code);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    // The app is showing behind this screen by now
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final muted = dark ? Tw.gray400 : Tw.gray500;

    return GuestScaffold(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('app_offline_title'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(context.t('app_offline_intro'), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: muted)),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(context.t('app_offline_create'))),
                ButtonSegment(value: true, label: Text(context.t('app_offline_join'))),
              ],
              selected: {_joining},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => setState(() => _joining = selection.first),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: context.t('app_offline_your_name'),
              controller: _name,
              textInputAction: TextInputAction.next,
              autofocus: true,
              validator: (value) => (value ?? '').trim().isEmpty ? context.rt('app_required') : null,
            ),
            const SizedBox(height: 16),
            if (_joining) ...[
              LabeledField(
                label: context.t('app_offline_code'),
                controller: _code,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (value) => LocalFamilyCodes.normalise(value ?? '') == null ? context.rt('app_offline_code_invalid') : null,
              ),
              const SizedBox(height: 4),
              Text(context.t('app_offline_code_help'), style: TextStyle(fontSize: 12, color: muted)),
            ] else
              LabeledField(
                label: context.t('app_offline_family_name'),
                controller: _familyName,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (value) => (value ?? '').trim().isEmpty ? context.rt('app_required') : null,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(context.t(_joining ? 'app_offline_join_button' : 'app_offline_start').toUpperCase()),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(context.t('app_offline_back')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The family's code, to be told to the others (and kept private: whoever has it can join).
Future<void> showFamilyCode(BuildContext context, String code) {
  final shown = LocalFamilyCodes.format(code);

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => AlertDialog(
      title: Text(dialog.t('app_offline_code_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SelectableText(shown, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: 2)),
            ),
          ),
          const SizedBox(height: 12),
          Text(dialog.t('app_offline_code_text'), style: const TextStyle(fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: shown));
            if (dialog.mounted) toast(dialog, dialog.rt('app_offline_copied'));
          },
          child: Text(dialog.t('app_offline_copy')),
        ),
        FilledButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(dialog.t('app_offline_done'))),
      ],
    ),
  );
}

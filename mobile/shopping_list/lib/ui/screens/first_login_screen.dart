import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../state/auth_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// First login with a temporary password: a screen of its own, in the login's style,
/// asking only for the new password and its confirmation (the temporary one was just
/// typed to sign in, so the app sends it along). Nothing else is reachable until then.
class FirstLoginScreen extends StatefulWidget {
  const FirstLoginScreen({super.key});

  @override
  State<FirstLoginScreen> createState() => _FirstLoginScreenState();
}

class _FirstLoginScreenState extends State<FirstLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final auth = context.read<AuthState>();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await auth.choosePassword(password: _password.text, confirmation: _confirmation.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.isOffline ? context.rt('app_cannot_reach') : e.firstMessage('password'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return GuestScaffold(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Notice(context.t('must_change_password')),
            const SizedBox(height: 16),
            LabeledField(
              label: context.t('new_password'),
              controller: _password,
              obscure: !_show,
              autofocus: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) => (value ?? '').length < 8 ? context.rt('password_rules') : null,
              suffix: ExcludeFocus(child: IconButton(
                icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setState(() => _show = !_show),
              )),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: context.t('confirm_password'),
              controller: _confirmation,
              obscure: !_show,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _submit(),
              validator: (value) => value != _password.text ? context.rt('app_password_mismatch') : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(fontSize: 14, color: dark ? Tw.red400 : Tw.red600)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(context.t('change_password').toUpperCase()),
            ),
            const SizedBox(height: 12),
            Text(
              context.t('password_rules'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: dark ? Tw.gray400 : Tw.gray500),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => context.read<AuthState>().logout(),
                child: Text(context.t('logout')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../state/auth_state.dart';
import '../theme.dart';
import 'common.dart';

/// Change password: the same three fields as the web's settings page. Used in
/// settings and as the whole screen on first login, when the password is temporary.
class PasswordForm extends StatefulWidget {
  const PasswordForm({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<PasswordForm> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final auth = context.read<AuthState>();
    setState(() {
      _busy = true;
      _errors = {};
    });

    try {
      await auth.changePassword(current: _current.text, password: _password.text, confirmation: _confirmation.text);
      if (!mounted) return;
      toast(context, context.rt('password_changed_success'));
      _current.clear();
      _password.clear();
      _confirmation.clear();
      widget.onChanged?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errors = {
          for (final field in ['current_password', 'password'])
            if (e.errors[field]?.isNotEmpty ?? false) field: e.errors[field]!.first,
          if (e.isOffline)
            'general': context.rt('app_cannot_reach')
          else if (!e.errors.containsKey('current_password') && !e.errors.containsKey('password'))
            'general': e.message,
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _error(String field) {
    final message = _errors[field];
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(message, style: TextStyle(fontSize: 14, color: context.isDark ? Tw.red400 : Tw.red600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('change_password'), style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 12),
          LabeledField(
            label: context.t('current_password'),
            controller: _current,
            obscure: true,
            textInputAction: TextInputAction.next,
            validator: (value) => (value ?? '').isEmpty ? context.rt('app_required') : null,
          ),
          _error('current_password'),
          const SizedBox(height: 12),
          LabeledField(
            label: context.t('new_password'),
            controller: _password,
            obscure: true,
            textInputAction: TextInputAction.next,
            validator: (value) => (value ?? '').length < 8 ? context.rt('password_rules') : null,
          ),
          _error('password'),
          const SizedBox(height: 12),
          LabeledField(
            label: context.t('confirm_password'),
            controller: _confirmation,
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (value) => value != _password.text ? context.rt('app_password_mismatch') : null,
          ),
          _error('general'),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(context.t('change_password').toUpperCase()),
            ),
          ),
        ],
      ),
    );
  }
}

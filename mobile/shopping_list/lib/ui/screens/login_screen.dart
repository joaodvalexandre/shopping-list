import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../state/auth_state.dart';
import '../../state/settings_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/menu_footer.dart';
import '../widgets/top_bar.dart';

/// The web's guest layout: language and theme on top, a centred card with the logo.
class GuestScaffold extends StatelessWidget {
  const GuestScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [LanguageMenu(), SizedBox(width: 8), ThemeToggle()]),
                  const SizedBox(height: 16),
                  Panel(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo(size: 48)),
                        const SizedBox(height: 16),
                        child,
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const MenuFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final TextEditingController _server;
  bool _showServer = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: context.read<SettingsState>().serverUrl);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _server.dispose();
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
      await auth.login(serverUrl: _server.text, email: _email.text, password: _password.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isOffline
            ? context.rt('app_cannot_reach')
            : e.isValidation
                ? e.firstMessage('email')
                : context.rt('app_sync_error');
        // an unreachable server is most often a wrong address: show the field
        if (e.isOffline) _showServer = true;
      });
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
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: context.t('email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                textInputAction: TextInputAction.next,
                autofocus: true,
                validator: (value) => (value ?? '').trim().isEmpty ? context.rt('app_required') : null,
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: context.t('password'),
                controller: _password,
                obscure: !_showPassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (value) => (value ?? '').isEmpty ? context.rt('app_required') : null,
                suffix: ExcludeFocus(child: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                )),
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
                    : Text(context.t('login').toUpperCase()),
              ),
              const SizedBox(height: 12),
              Text(
                context.t('login_help'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: dark ? Tw.gray400 : Tw.gray500),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _showServer = !_showServer),
                  child: Text(context.t('app_server'), style: const TextStyle(fontSize: 12)),
                ),
              ),
              if (_showServer) ...[
                LabeledField(
                  label: context.t('app_server'),
                  controller: _server,
                  keyboardType: TextInputType.url,
                  validator: (value) => (value ?? '').trim().isEmpty ? context.rt('app_required') : null,
                ),
                const SizedBox(height: 4),
                Text(context.t('app_server_help'), style: TextStyle(fontSize: 12, color: dark ? Tw.gray400 : Tw.gray500)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

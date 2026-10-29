import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../peer/local_family.dart';
import '../../peer/probe.dart';
import '../../peer/radio.dart';
import '../../state/auth_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'local_family_screen.dart';
import 'login_screen.dart';
import 'qr_scan_screen.dart';

/// Where someone is in joining a family.
enum _Join { code, searching, name }

/// Use the app with no account and no server: start a family that lives on its phones, or join
/// one with its code. Nothing is ever created on the web app or sent to it.
///
/// Joining goes in this order: the code (typed or scanned), then finding the family's phones
/// nearby, and only then who you are.
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

  _Join _step = _Join.code;
  String? _code12;
  FamilyPhoneFound? _found;
  bool _gaveUp = false;
  bool _cannotLook = false;
  Timer? _giveUp;
  final _probe = LocalFamilyProbe();

  @override
  void dispose() {
    _giveUp?.cancel();
    _probe.stop();
    _name.dispose();
    _familyName.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (code == null || !mounted) return;

    setState(() => _code.text = LocalFamilyCodes.format(code));
    _next(); // a scanned code is a code: no need to press anything
  }

  /// The code is in: look for the family's phones before asking who this is.
  Future<void> _next() async {
    if (!_form.currentState!.validate()) return;

    final code = LocalFamilyCodes.normalise(_code.text)!;
    FocusScope.of(context).unfocus();

    setState(() {
      _code12 = code;
      _step = _Join.searching;
      _found = null;
      _gaveUp = false;
      _cannotLook = false;
    });

    // Bluetooth and nearby devices need asking for before anything can be looked for
    final allowed = await askForNearbyPermissions();
    if (!mounted) return;

    final looking = allowed && await _probe.start(code, _onFound);
    if (!mounted) return;

    if (!looking) {
      setState(() => _cannotLook = true);
      return;
    }

    _giveUp?.cancel();
    _giveUp = Timer(const Duration(seconds: 20), () {
      if (mounted && _found == null) setState(() => _gaveUp = true);
    });
  }

  Future<void> _onFound(FamilyPhoneFound phone) async {
    final version = await _ownVersion();
    if (!mounted || _step != _Join.searching) return;

    // A phone on another version is not one this can sync with: say so, and keep looking
    if (phone.version != version) {
      setState(() => _found = phone);
      return;
    }

    _giveUp?.cancel();
    await _probe.stop();
    if (!mounted) return;

    setState(() {
      _found = phone;
      _step = _Join.name;
    });
  }

  Future<String> _ownVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  Future<void> _backToCode() async {
    _giveUp?.cancel();
    await _probe.stop();
    if (!mounted) return;

    setState(() {
      _step = _Join.code;
      _found = null;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final auth = context.read<AuthState>();
    final navigator = Navigator.of(context);
    final typeName = context.rt('app_offline_default_type');
    setState(() => _busy = true);

    try {
      if (_joining) {
        await _probe.stop();
        await auth.joinLocalFamily(myName: _name.text, code: _code12 ?? _code.text, typeName: typeName);
      } else {
        final family = await auth.startLocalFamily(myName: _name.text, familyName: _familyName.text, typeName: typeName);
        if (!mounted) return;
        await showFamilyCode(context, family.code, _familyName.text.trim());
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
            // (the two ways in can only be switched between before the family is being looked for)
            if (!_joining || _step == _Join.code)
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
            if (!_joining) ..._start(context, muted) else ..._join(context, muted),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy ? null : (_joining && _step != _Join.code ? _backToCode : () => Navigator.of(context).pop()),
                child: Text(context.t('app_offline_back')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Starting a family: who you are, and what the family is called.
  List<Widget> _start(BuildContext context, Color muted) => [
        LabeledField(
          label: context.t('app_offline_your_name'),
          controller: _name,
          textInputAction: TextInputAction.next,
          validator: (value) => (value ?? '').trim().isEmpty ? context.rt('app_required') : null,
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: context.t('app_offline_family_name'),
          controller: _familyName,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          validator: (value) => (value ?? '').trim().isEmpty ? context.rt('app_required') : null,
        ),
        const SizedBox(height: 16),
        _button(context, 'app_offline_start', _submit),
      ];

  /// Joining a family: the code, then finding the family, then the name.
  List<Widget> _join(BuildContext context, Color muted) {
    switch (_step) {
      case _Join.code:
        return [
          LabeledField(
            label: context.t('app_offline_code'),
            controller: _code,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(),
            validator: (value) => LocalFamilyCodes.normalise(value ?? '') == null ? context.rt('app_offline_code_invalid') : null,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), label: Text(context.t('app_offline_scan'))),
          const SizedBox(height: 4),
          Text(context.t('app_offline_code_help'), style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 16),
          _button(context, 'app_offline_next', _next),
        ];

      case _Join.searching:
        final other = _found != null;

        return [
          Center(child: Text(LocalFamilyCodes.format(_code12 ?? ''), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2))),
          const SizedBox(height: 16),
          if (_cannotLook)
            Notice(context.t('app_nearby_radio_failed'), error: true)
          else if (other)
            Notice(context.t('app_nearby_other_version', {'version': _found!.version}), error: true)
          else ...[
            const Center(child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 3))),
            const SizedBox(height: 12),
            Text(context.t('app_offline_searching'), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: muted)),
          ],
          if (_gaveUp && !other) ...[
            const SizedBox(height: 12),
            Text(context.t('app_offline_not_found'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: muted)),
          ],
          if (_gaveUp || _cannotLook) ...[
            const SizedBox(height: 12),
            // The family may simply be out of reach for now: it connects when its phones are near
            OutlinedButton(onPressed: () => setState(() => _step = _Join.name), child: Text(context.t('app_offline_continue_anyway'))),
          ],
        ];

      case _Join.name:
        return [
          if (_found != null) ...[
            Row(children: [
              Icon(Icons.check_circle, size: 20, color: context.isDark ? Tw.green500 : Tw.green600),
              const SizedBox(width: 8),
              Expanded(child: Text(context.t('app_offline_found', {'name': _found!.person}), style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 16),
          ],
          LabeledField(
            label: context.t('app_offline_your_name'),
            controller: _name,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (value) => (value ?? '').trim().isEmpty ? context.rt('app_required') : null,
          ),
          const SizedBox(height: 16),
          _button(context, 'app_offline_join_button', _submit),
        ];
    }
  }

  Widget _button(BuildContext context, String labelKey, VoidCallback onPressed) {
    return FilledButton(
      onPressed: _busy ? null : onPressed,
      child: _busy
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(context.t(labelKey).toUpperCase()),
    );
  }
}

/// The family's code, to be told to the others (and kept private: whoever has it can join).
Future<void> showFamilyCode(BuildContext context, String code, [String familyName = '']) {
  final shown = LocalFamilyCodes.format(code);

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => AlertDialog(
      scrollable: true,
      title: Text(dialog.t('app_offline_code_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: FamilyQr(code: code, familyName: familyName, size: 170)),
          const SizedBox(height: 12),
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

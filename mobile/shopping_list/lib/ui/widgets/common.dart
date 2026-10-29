import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../state/content_service.dart';
import '../../state/settings_state.dart';
import '../../state/sync_service.dart';
import '../theme.dart';

extension TextsOnContext on BuildContext {
  /// A text of the app in the chosen language (rebuilds when the language changes).
  String t(String key, [Map<String, Object> params = const {}]) => watch<SettingsState>().t(key, params);

  /// Same, for event handlers (which must not watch).
  String rt(String key, [Map<String, Object> params = const {}]) => read<SettingsState>().t(key, params);

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// The web's two pills for switching between a family's people and its list types: the current
/// one dark, the other light. Shared by the server family's page and the offline one.
class FamilyTabPill extends StatelessWidget {
  const FamilyTabPill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Material(
      color: selected ? (dark ? Tw.gray200 : Tw.gray800) : (dark ? Tw.gray700 : Tw.gray200),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: selected ? (dark ? Tw.gray800 : Colors.white) : (dark ? Tw.gray200 : Tw.gray800),
            ),
          ),
        ),
      ),
    );
  }
}

/// The web's rounded call-to-action button ("New List", "Finish List"...).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = Tw.blue500,
    this.hoverColor,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color? hoverColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: enabled ? color : Tw.gray400,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 8 : 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon, size: 20, color: Colors.white),
                if (icon != null && label.isNotEmpty) const SizedBox(width: 8),
                if (label.isNotEmpty)
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A white (dark: gray) panel with a soft shadow, like the web's content cards.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

/// The web's warning banner (yellow) for notices such as "choose your own password".
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final background = error ? (dark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2)) : (dark ? const Color(0xFF713F12) : const Color(0xFFFEF9C3));
    final foreground = error ? (dark ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D)) : (dark ? const Color(0xFFFEF9C3) : const Color(0xFF713F12));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: foreground)),
    );
  }
}

/// The small status pill of the web's tables ("Pending", "Finished"...).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor = color == Tw.yellow500 ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: onColor, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// A form field whose label sits above it, as on the web.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscure = false,
    this.autofillHints,
    this.validator,
    this.textInputAction,
    this.autofocus = false,
    this.onSubmitted,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Tw.gray300 : Tw.gray700)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          validator: validator,
          textInputAction: textInputAction,
          autofocus: autofocus,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(isDense: true, suffixIcon: suffix),
        ),
      ],
    );
  }
}

Future<bool> confirm(BuildContext context, String message, {String? action}) async {
  final settings = context.read<SettingsState>();

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(settings.t('go_back'))),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: Tw.red600),
          child: Text(action ?? settings.t('delete')),
        ),
      ],
    ),
  );

  return result ?? false;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Room around the content of every scrollable page: a gap under the header, and enough
/// at the bottom that the last card is never against (or under) the navigation bar.
const EdgeInsets scrollPadding = EdgeInsets.fromLTRB(12, 20, 12, 40);

/// Pull everything fresh: the family's lists, and the texts, pages and links from the server.
Future<void> syncEverything(BuildContext context) {
  final content = context.read<ContentService>();
  final api = context.read<ApiClient>();
  final sync = context.read<SyncService>();

  // (the texts are a bonus: if they cannot be had, the lists are still refreshed)
  return Future.wait([sync.sync(), content.refresh(api).catchError((Object _) => false)]);
}

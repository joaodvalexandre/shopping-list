import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../state/auth_state.dart';
import '../../state/settings_state.dart';
import '../../state/sync_service.dart';
import '../screens/settings_screen.dart';
import '../theme.dart';
import 'common.dart';

/// The web app's cart logo.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.shopping_cart_outlined, size: size, color: context.isDark ? Tw.gray200 : Tw.gray800);
}

/// The web's sliding sun/moon switch.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final dark = context.isDark;

    return Semantics(
      button: true,
      label: 'theme',
      child: GestureDetector(
        onTap: () => settings.setDark(!dark),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 58,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: dark ? Tw.gray600 : Tw.gray300, borderRadius: BorderRadius.circular(999)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            alignment: dark ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(dark ? Icons.dark_mode : Icons.light_mode, size: 16, color: Tw.gray800),
            ),
          ),
        ),
      ),
    );
  }
}

/// Language choice, as the web's flag dropdown.
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});

  static const _flags = {'pt': '🇵🇹', 'en': '🇬🇧'};

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();

    return PopupMenuButton<String>(
      tooltip: settings.t('language'),
      onSelected: settings.setLanguage,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final entry in SettingsState.supportedLanguages.entries)
          CheckedPopupMenuItem(
            value: entry.key,
            checked: entry.key == settings.language,
            child: Text('${_flags[entry.key] ?? ''}  ${entry.value}'),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_flags[settings.language] ?? '🌐', style: const TextStyle(fontSize: 22)),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ]),
      ),
    );
  }
}

/// The account menu: settings and log out.
class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<Repository>();
    final name = repository.me?.name ?? '';

    return PopupMenuButton<String>(
      tooltip: name,
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        if (value == 'settings') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        } else if (value == 'logout') {
          await signOut(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'settings', child: Text(context.rt('settings'))),
        PopupMenuItem(value: 'logout', child: Text(context.rt('logout'))),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.account_circle_outlined, size: 30),
      ),
    );
  }
}

/// Log out, warning first if changes have not reached the server (they would be lost).
Future<void> signOut(BuildContext context) async {
  final repository = context.read<Repository>();
  final auth = context.read<AuthState>();
  final settings = context.read<SettingsState>();

  if (repository.pendingCount > 0) {
    final proceed = await confirm(
      context,
      settings.t('app_unsynced_warning', {'count': repository.pendingCount}),
      action: settings.t('logout'),
    );
    if (!proceed) return;
  }

  await auth.logout();
}

/// Offline / waiting-changes strip under the top bar. Silent when all is well.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final waiting = context.watch<Repository>().pendingCount;

    final (String? text, IconData icon, Color color) = switch (sync.status) {
      SyncStatus.offline => (context.t('app_offline'), Icons.cloud_off_outlined, Tw.gray500),
      SyncStatus.error => (context.t('app_sync_error'), Icons.error_outline, Tw.red600),
      SyncStatus.syncing when waiting > 0 => (context.t('app_syncing'), Icons.sync, Tw.blue500),
      _ when waiting > 0 => (context.t('app_waiting_changes', {'count': waiting}), Icons.cloud_upload_outlined, Tw.amber600),
      _ => (null, Icons.cloud_done_outlined, Tw.gray500),
    };

    if (text == null) return const SizedBox.shrink();

    final waitingText = (sync.status == SyncStatus.offline || sync.status == SyncStatus.error) && waiting > 0
        ? '$text · ${context.t('app_waiting_changes', {'count': waiting})}'
        : text;

    return Material(
      color: color.withValues(alpha: 0.12),
      child: InkWell(
        onTap: sync.sync,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(waitingText, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
            Icon(Icons.refresh, size: 16, color: color),
          ]),
        ),
      ),
    );
  }
}

/// The page title strip below the top bar (the web's white "header").
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Text(title, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

/// Top bar of the main screens: logo, switches and account.
PreferredSizeWidget appBar(BuildContext context, {List<Widget> extra = const []}) {
  return AppBar(
    titleSpacing: 12,
    title: const Align(alignment: Alignment.centerLeft, child: AppLogo(size: 34)),
    actions: [
      ...extra,
      const LanguageMenu(),
      const ThemeToggle(),
      const SizedBox(width: 4),
      const UserMenu(),
      const SizedBox(width: 6),
    ],
  );
}

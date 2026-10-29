import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../peer/nearby_service.dart';
import '../../peer/session.dart';
import '../../state/auth_state.dart';
import '../../state/settings_state.dart';
import '../../state/sync_service.dart';
import '../screens/settings_screen.dart';
import '../theme.dart';
import 'common.dart';

/// The app's logo: the basket, as on the launcher icon and the web.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset('assets/icon/logo.png', width: size, height: size, filterQuality: FilterQuality.medium);
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();

    return PopupMenuButton<String>(
      tooltip: settings.t('language'),
      onSelected: settings.setLanguage,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final language in settings.languages)
          CheckedPopupMenuItem(
            value: language.code,
            checked: language.code == settings.language,
            child: Text('${SettingsState.flagOf(language.code)}  ${language.nativeName}'),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(SettingsState.flagOf(settings.language), style: const TextStyle(fontSize: 22)),
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
    final nearby = context.watch<NearbyService>();

    // With no way to the server the phone may be talking to a phone nearby: say so
    final (String? nearbyText, IconData nearbyIcon, Color nearbyColor) = _nearbyLine(context, nearby);

    final (String? text, IconData icon, Color color) = switch (sync.status) {
      SyncStatus.offline when nearbyText != null => ('${context.t('app_offline')} · $nearbyText', nearbyIcon, nearbyColor),
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

/// What to say about phones nearby (null: nothing). Another version is said first: it needs doing something.
(String?, IconData, Color) _nearbyLine(BuildContext context, NearbyService nearby) {
  if (nearby.state == NearbyState.off && nearby.otherVersionSeen == null) return (null, Icons.bluetooth, Tw.gray500);

  if (nearby.otherVersionSeen != null) {
    return (context.t('app_nearby_other_version', {'version': nearby.otherVersionSeen!}), Icons.system_update_outlined, Tw.amber600);
  }

  final who = nearby.currentPeer ?? '';
  final last = nearby.lastResult;
  final recent = nearby.lastMeetingAt != null && DateTime.now().difference(nearby.lastMeetingAt!) < const Duration(seconds: 25);

  return switch (nearby.state) {
    NearbyState.syncing => (context.t('app_nearby_syncing', {'name': who}), Icons.bluetooth_connected, Tw.blue500),
    NearbyState.connecting => (context.t('app_nearby_connecting', {'name': who}), Icons.bluetooth_searching, Tw.blue500),
    _ when recent && last != null && last.ok => (
        context.t('app_nearby_done', {'name': last.peerName ?? '', 'sent': last.sent, 'received': last.applied.total}),
        Icons.bluetooth_connected,
        Tw.green600,
      ),
    _ when recent && last != null && last.status == PeerStatus.expired => (context.t('app_nearby_expired'), Icons.bluetooth_searching, Tw.amber600),
    _ => (context.t('app_nearby_searching'), Icons.bluetooth_searching, Tw.blue500),
  };
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

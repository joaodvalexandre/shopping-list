import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/repository.dart';
import '../../peer/nearby_service.dart';
import '../../state/auth_state.dart';
import '../../state/family_link.dart';
import '../../state/notification_service.dart';
import '../../state/settings_state.dart';
import '../../state/sync_service.dart';
import '../theme.dart';
import '../who.dart';
import '../widgets/common.dart';
import '../widgets/menu_footer.dart';
import '../widgets/password_form.dart';
import '../widgets/top_bar.dart';
import 'offline_start_screen.dart';

/// Settings, in groups: who you are, how the app looks, what it tells you, how it connects, and the
/// account. The longer ones (password, devices) have a page of their own.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  /// Asked again when the person comes back from Android's settings.
  int _batteryCheck = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() => _batteryCheck++);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final repository = context.watch<Repository>();
    final local = context.watch<AuthState>().isLocal;
    final accountLinks = [...context.menuLinks('navbar'), ...context.menuLinks('user_menu')].where((link) => link.goesSomewhere).toList();
    final muted = context.isDark ? Tw.gray400 : Tw.gray500;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('settings'), style: const TextStyle(fontSize: 18)),
      ),
      body: ListView(
        padding: scrollPadding,
        children: [
          _profile(context, repository, local),
          const SizedBox(height: 16),

          _Group(title: context.t('app_settings_appearance'), children: [
            _row(
              icon: Icons.language,
              title: context.t('language'),
              trailing: DropdownButton<String>(
                value: settings.language,
                underline: const SizedBox.shrink(),
                items: [
                  for (final language in settings.languages)
                    DropdownMenuItem(value: language.code, child: Text('${SettingsState.flagOf(language.code)}  ${language.nativeName}')),
                ],
                onChanged: (code) => code == null ? null : settings.setLanguage(code),
              ),
            ),
            _row(
              icon: Icons.contrast,
              title: context.t('app_theme'),
              subtitle: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(value: ThemeMode.system, label: Text(context.t('app_theme_auto'))),
                  ButtonSegment(value: ThemeMode.light, label: Text(context.t('app_theme_light'))),
                  ButtonSegment(value: ThemeMode.dark, label: Text(context.t('app_theme_dark'))),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) => settings.setThemeMode(selection.first),
              ),
            ),
          ]),

          _notifications(context, settings, local, muted),

          _connection(context, settings, repository, local, muted),

          if (!local)
            _Group(title: context.t('app_settings_account'), children: [
              _row(
                icon: Icons.lock_outline,
                title: context.t('app_change_password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _PasswordScreen())),
              ),
              _row(
                icon: Icons.devices_other_outlined,
                title: context.t('app_devices'),
                subtitle: Text(context.t('app_devices_help'), style: TextStyle(fontSize: 12, color: muted)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _DevicesScreen())),
              ),
            ]),

          _Group(title: context.t('app_settings_about'), children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) => _row(
                icon: Icons.info_outline,
                title: context.t('app_version'),
                trailing: Text(snapshot.hasData ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}' : '', style: TextStyle(color: muted)),
              ),
            ),
            for (final link in accountLinks)
              _row(
                icon: link.page != null ? Icons.article_outlined : Icons.open_in_new,
                title: link.label,
                trailing: Icon(link.page != null ? Icons.chevron_right : Icons.open_in_new, size: 18),
                onTap: () => openLink(context, link),
              ),
          ]),

          const SizedBox(height: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: context.isDark ? Tw.red400 : Tw.red600),
            onPressed: () => signOut(context),
            icon: const Icon(Icons.logout),
            label: Text(context.t(local ? 'app_offline_leave' : 'logout').toUpperCase()),
          ),
          const MenuFooter(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- who you are

  Widget _profile(BuildContext context, Repository repository, bool local) {
    final me = repository.me;
    final dark = context.isDark;
    final muted = dark ? Tw.gray400 : Tw.gray500;
    final name = repository.displayName(me?.name ?? '');
    final initials = name.trim().isEmpty ? '?' : name.trim().split(RegExp(r'\s+')).take(2).map((word) => word.characters.first.toUpperCase()).join();

    return Panel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Tw.blue500.withValues(alpha: 0.18),
            child: Text(initials, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: dark ? Tw.blue500 : Tw.blue600)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                if (!local && (me?.email ?? '').isNotEmpty) Text(me!.email, style: TextStyle(fontSize: 13, color: muted)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  StatusPill(text: context.t(me?.isAdmin == true ? 'role_admin' : 'role_member'), color: me?.isAdmin == true ? Tw.purple500 : Tw.blue500),
                  StatusPill(
                    text: (me?.familyName ?? '').isEmpty ? context.t('app_offline_family_unknown') : me!.familyName,
                    color: Tw.gray500,
                  ),
                  if (local) StatusPill(text: context.t('app_offline_family_section'), color: Tw.green500),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- what the app tells you

  Widget _notifications(BuildContext context, SettingsState settings, bool local, Color muted) {
    final service = context.read<NotificationService>();
    final prefs = service.prefs;

    Widget kind(IconData icon, String key, String prefKey) => _switchRow(
          icon: icon,
          title: context.t(key),
          value: prefs.getBool(prefKey) ?? true,
          onChanged: (on) async {
            await prefs.setBool(prefKey, on);
            if (mounted) setState(() {});
          },
        );

    return _Group(title: context.t('app_notifications'), children: [
      _switchRow(
        icon: Icons.notifications_active_outlined,
        title: context.t('app_notifications_switch'),
        subtitle: context.t('app_notifications_help_short'),
        value: service.enabled,
        onChanged: (on) async {
          final allowed = await service.setEnabled(on);
          if (!context.mounted) return;
          setState(() {});
          if (on && !allowed) toast(context, context.rt('app_notifications_denied'));
        },
      ),
      _switchRow(
        icon: Icons.chat_bubble_outline,
        title: context.t('app_notifications_inapp'),
        subtitle: context.t('app_notifications_inapp_help'),
        value: service.inAppEnabled,
        onChanged: (on) async {
          await prefs.setBool(NotificationService.inAppKey, on);
          if (mounted) setState(() {});
        },
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(context.t('app_notify_when'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted)),
        ),
      ),
      kind(Icons.add_shopping_cart, 'app_notify_added', 'notify_added'),
      kind(Icons.shopping_cart_outlined, 'app_notify_cart', 'notify_cart'),
      kind(Icons.check_circle_outline, 'app_notify_bought', 'notify_bought'),
      kind(Icons.edit_outlined, 'app_notify_changes', 'notify_changes'),
      if (!local)
        _switchRow(
          icon: Icons.bolt_outlined,
          title: context.t('app_keep_running'),
          subtitle: context.t('app_keep_running_help'),
          value: settings.keepRunning,
          onChanged: (on) async {
            await settings.setKeepRunning(on);
            // (the app is on screen: the watcher goes on from here, and the notification that keeps it alive shows)
            if (context.mounted) context.read<SyncService>().setForeground(true);
          },
        ),
      _background(context, local, muted),
    ]);
  }

  /// Android may stop an app that has been in the background for a while to save battery: ask not to.
  Widget _background(BuildContext context, bool local, Color muted) {
    final needed = local || context.read<SettingsState>().keepRunning;
    if (!needed) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      key: ValueKey(_batteryCheck),
      future: context.read<FamilyLink>().batteryExempt(),
      builder: (context, snapshot) {
        final allowed = snapshot.data != false;

        return _row(
          icon: allowed ? Icons.battery_charging_full : Icons.battery_alert_outlined,
          iconColor: allowed ? null : Tw.amber600,
          title: context.t(allowed ? 'app_background_allowed' : 'app_family_background_allow'),
          subtitle: allowed ? null : Text(context.t('app_family_background_help'), style: TextStyle(fontSize: 12, color: muted)),
          trailing: allowed ? Icon(Icons.check_circle, color: Tw.green500) : const Icon(Icons.chevron_right),
          onTap: allowed ? null : () => context.read<FamilyLink>().askBatteryExemption(),
        );
      },
    );
  }

  // ---------------------------------------------------------------- how it connects

  Widget _connection(BuildContext context, SettingsState settings, Repository repository, bool local, Color muted) {
    final sync = context.watch<SyncService>();
    final nearby = context.watch<NearbyService>();
    final family = context.read<AuthState>().localFamily?.currentSync;
    final last = nearby.lastResult;

    final lastText = last != null && last.ok
        ? context.t('app_nearby_last', {'text': context.t('app_nearby_done', {'name': context.who(last.peerName ?? ''), 'sent': last.sent, 'received': last.applied.total})})
        : null;

    return _Group(title: context.t('app_settings_connection'), children: [
      if (!local) ...[
        _row(icon: Icons.dns_outlined, title: context.t('app_server'), trailing: Flexible(child: Text(settings.serverUrl, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted)))),
        _row(
          icon: Icons.sync,
          title: context.t('app_last_sync'),
          trailing: Text(sync.lastSync == null ? context.t('app_never') : DateFormat.yMd(settings.language).add_Hm().format(sync.lastSync!), style: TextStyle(color: muted)),
        ),
        _row(icon: Icons.cloud_upload_outlined, title: context.t('app_pending'), trailing: Text('${repository.pendingCount}', style: TextStyle(color: muted))),
        _row(
          icon: Icons.refresh,
          title: context.t('app_sync_now'),
          trailing: sync.isSyncing ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
          onTap: sync.isSyncing ? null : () => syncEverything(context),
        ),
      ],
      if (local && family != null && repository.isLocalAdmin)
        _row(
          icon: Icons.qr_code_2,
          title: context.t('app_offline_show_code'),
          subtitle: Text(context.t('app_offline_mode_note'), style: TextStyle(fontSize: 12, color: muted)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showFamilyCode(context, family.code, repository.me?.familyName ?? ''),
        ),
      _switchRow(
        icon: Icons.bluetooth_searching,
        title: context.t('app_nearby_switch'),
        subtitle: context.t(local ? 'app_nearby_help_local' : 'app_nearby_help'),
        value: nearby.enabled,
        onChanged: (on) => nearby.setEnabled(on),
      ),
      if (nearby.enabled && nearby.permissionDenied)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Notice(context.t('app_nearby_permission')),
            TextButton(onPressed: openAppSettings, child: Text(context.t('app_nearby_open_settings'))),
          ]),
        ),
      if (nearby.enabled && nearby.radioFailed) Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: Notice(context.t('app_nearby_radio_failed'))),
      if (lastText != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text(lastText, style: TextStyle(fontSize: 12, color: muted))),
    ]);
  }

  // ---------------------------------------------------------------- rows

  // Room between a row's text and the lines above and below it
  static const _rowPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
  static const _rowGap = 14.0;

  Widget _row({required IconData icon, required String title, Widget? subtitle, Widget? trailing, VoidCallback? onTap, Color? iconColor}) {
    return ListTile(
      contentPadding: _rowPadding,
      minVerticalPadding: _rowGap,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _switchRow({required IconData icon, required String title, String? subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      contentPadding: _rowPadding,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(fontSize: 12, color: context.isDark ? Tw.gray400 : Tw.gray500)),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A titled group of settings in one card, the rows separated by thin lines.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = children.where((child) => child is! SizedBox).toList();
    final muted = context.isDark ? Tw.gray400 : Tw.gray500;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: muted)),
          ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1) Divider(height: 1, thickness: 1, color: context.isDark ? Tw.gray700 : Tw.gray200),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Choose a new password.
class _PasswordScreen extends StatelessWidget {
  const _PasswordScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('app_change_password'), style: const TextStyle(fontSize: 18))),
      body: ListView(padding: scrollPadding, children: const [Panel(padding: EdgeInsets.all(20), child: PasswordForm())]),
    );
  }
}

/// The phones signed in to this account, and signing one of them out.
class _DevicesScreen extends StatefulWidget {
  const _DevicesScreen();

  @override
  State<_DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<_DevicesScreen> {
  late Future<List<Map<String, dynamic>>> _devices = context.read<ApiClient>().devices();

  void _reload() => setState(() => _devices = context.read<ApiClient>().devices());

  @override
  Widget build(BuildContext context) {
    final muted = context.isDark ? Tw.gray400 : Tw.gray500;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('app_devices'), style: const TextStyle(fontSize: 18))),
      body: ListView(
        padding: scrollPadding,
        children: [
          Text(context.t('app_devices_help'), style: TextStyle(fontSize: 13, color: muted)),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _devices,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                }
                if (snapshot.hasError) {
                  return Padding(padding: const EdgeInsets.all(12), child: Text(context.t('app_cannot_reach'), style: TextStyle(color: muted)));
                }

                return Column(children: [for (final device in snapshot.data!) _device(context, device)]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _device(BuildContext context, Map<String, dynamic> device) {
    final current = device['current'] == true;
    final used = DateTime.tryParse('${device['last_used_at']}')?.toLocal();
    final language = context.read<SettingsState>().language;
    final muted = context.isDark ? Tw.gray400 : Tw.gray500;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(current ? Icons.smartphone : Icons.devices_other_outlined),
      title: Text('${device['name']}${current ? '  ·  ${context.t('app_this_device')}' : ''}'),
      subtitle: used == null ? null : Text(DateFormat.yMd(language).add_Hm().format(used), style: TextStyle(color: muted)),
      trailing: current
          ? null
          : IconButton(
              tooltip: context.t('app_sign_out_device'),
              icon: Icon(Icons.logout, color: context.isDark ? Tw.red400 : Tw.red600),
              onPressed: () async {
                final api = context.read<ApiClient>();
                if (!await confirm(context, context.rt('app_sign_out_device_confirm'), action: context.rt('app_sign_out_device'))) return;
                try {
                  await api.removeDevice((device['id'] as num).toInt());
                } on ApiException {
                  // offline: nothing changed; the list below shows it
                }
                if (mounted) _reload();
              },
            ),
    );
  }
}

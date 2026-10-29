import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/repository.dart';
import '../../peer/local_family.dart';
import '../../peer/nearby_service.dart';
import '../../state/auth_state.dart';
import '../../state/notification_service.dart';
import '../../state/settings_state.dart';
import '../../state/sync_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/menu_footer.dart';
import '../widgets/password_form.dart';
import '../widgets/top_bar.dart';
import 'offline_start_screen.dart';

/// Profile, language, password, devices and sync: the web's settings page plus what only a phone has.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<Map<String, dynamic>>> _devices;
  late bool _notifications;

  @override
  void initState() {
    super.initState();
    // A local family never talks to the server, not even to list devices
    _devices = context.read<AuthState>().isLocal ? Future.value(const []) : _loadDevices();
    _notifications = context.read<NotificationService>().enabled;
  }

  Future<List<Map<String, dynamic>>> _loadDevices() => context.read<ApiClient>().devices();

  void _reloadDevices() => setState(() => _devices = _loadDevices());

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final repository = context.watch<Repository>();
    final sync = context.watch<SyncService>();
    final accountLinks = [...context.menuLinks('navbar'), ...context.menuLinks('user_menu')];
    final me = repository.me;
    final local = context.watch<AuthState>().isLocal;
    final dark = context.isDark;
    final muted = dark ? Tw.gray400 : Tw.gray500;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('settings'), style: const TextStyle(fontSize: 18)),
        actions: const [ThemeToggle(), SizedBox(width: 12)],
      ),
      body: ListView(
        padding: scrollPadding,
        children: [
          // Profile (changed on the web; here to see who is signed in)
          Panel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('profile'), style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 12),
                _row(context.t('name'), me?.name ?? ''),
                if (!local) _row(context.t('email'), me?.email ?? ''),
                _row(context.t('family'), (me?.familyName ?? '').isEmpty && local ? context.t('app_offline_family_unknown') : me?.familyName ?? ''),
                if (!local) _row(context.t('role'), me == null ? '' : context.t(me.isAdmin ? 'role_admin' : 'role_member')),
                const SizedBox(height: 12),
                Text(context.t('language'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Tw.gray300 : Tw.gray700)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: settings.language,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final language in settings.languages)
                      DropdownMenuItem(value: language.code, child: Text(language.nativeName)),
                  ],
                  onChanged: (code) => code == null ? null : settings.setLanguage(code),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // The family's code (local families only)
          if (local) ...[
            _localFamilyPanel(context, muted),
            const SizedBox(height: 12),
          ],

          if (!local) ...[
            const Panel(padding: EdgeInsets.all(20), child: PasswordForm()),
            const SizedBox(height: 12),
          ],

          // Notifications about what others did
          if (!local) Panel(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.t('app_notifications'), style: const TextStyle(fontSize: 20))),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('app_notifications_switch')),
                  value: _notifications,
                  onChanged: (on) async {
                    final allowed = await context.read<NotificationService>().setEnabled(on);
                    if (!context.mounted) return;
                    setState(() => _notifications = on);
                    if (on && !allowed) toast(context, context.rt('app_notifications_denied'));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(context.t('app_notifications_help'), style: TextStyle(fontSize: 12, color: muted)),
                ),
              ],
            ),
          ),
          if (!local) const SizedBox(height: 12),

          // Phones of the family nearby, for when there is no way to the server
          _nearbyPanel(context, muted),
          const SizedBox(height: 12),

          // Sync
          if (!local) Panel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('app_sync'), style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 12),
                _row(context.t('app_server'), settings.serverUrl),
                _row(
                  context.t('app_last_sync'),
                  sync.lastSync == null ? context.t('app_never') : DateFormat.yMd(settings.language).add_Hm().format(sync.lastSync!),
                ),
                _row(context.t('app_pending'), '${repository.pendingCount}'),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: PillButton(
                    label: context.t('app_sync_now'),
                    icon: Icons.sync,
                    onPressed: sync.isSyncing ? null : () => syncEverything(context),
                  ),
                ),
              ],
            ),
          ),
          if (!local) const SizedBox(height: 12),

          // Devices
          if (!local) Panel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('app_devices'), style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(context.t('app_devices_help'), style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _devices,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                    }
                    if (snapshot.hasError) {
                      return Text(context.t('app_cannot_reach'), style: TextStyle(color: muted));
                    }

                    return Column(children: [for (final device in snapshot.data!) _device(context, device)]);
                  },
                ),
              ],
            ),
          ),
          if (!local) const SizedBox(height: 12),

          // Links arranged in the backoffice (About, Privacy...); pages open inside the app
          if (accountLinks.any((link) => link.goesSomewhere))
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final link in accountLinks)
                    if (link.goesSomewhere)
                      ListTile(
                        dense: true,
                        title: Text(link.label),
                        trailing: Icon(link.page != null ? Icons.chevron_right : Icons.open_in_new, size: 18),
                        onTap: () => openLink(context, link),
                      ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          Align(
            alignment: Alignment.center,
            child: FilledButton(
              onPressed: () => signOut(context),
              child: Text(context.t(local ? 'app_offline_leave' : 'logout').toUpperCase()),
            ),
          ),
          const MenuFooter(),
        ],
      ),
    );
  }

  /// The family's code, for the others to join with, and what makes the family local.
  Widget _localFamilyPanel(BuildContext context, Color muted) {
    final code = context.read<AuthState>().localFamily?.currentSync;

    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('app_offline_family_section'), style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(context.t('app_offline_mode_note'), style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 12),
          if (code != null) ...[
            Text(context.t('app_offline_code'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.isDark ? Tw.gray300 : Tw.gray700)),
            const SizedBox(height: 4),
            SelectableText(LocalFamilyCodes.format(code.code), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 2)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: PillButton(label: context.t('app_offline_show_code'), icon: Icons.qr_code_2, onPressed: () => showFamilyCode(context, code.code)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _nearbyPanel(BuildContext context, Color muted) {
    final nearby = context.watch<NearbyService>();
    final last = nearby.lastResult;

    final lastText = last == null
        ? null
        : last.ok
            ? context.t('app_nearby_done', {'name': last.peerName ?? '', 'sent': last.sent, 'received': last.applied.total})
            : null;

    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.t('app_nearby'), style: const TextStyle(fontSize: 20))),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('app_nearby_switch')),
            value: nearby.enabled,
            onChanged: (on) => nearby.setEnabled(on),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(context.t('app_nearby_help'), style: TextStyle(fontSize: 12, color: muted)),
          ),
          if (nearby.enabled && nearby.permissionDenied) ...[
            const SizedBox(height: 8),
            Notice(context.t('app_nearby_permission')),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: openAppSettings, child: Text(context.t('app_nearby_open_settings'))),
            ),
          ],
          if (nearby.enabled && nearby.radioFailed) ...[const SizedBox(height: 8), Notice(context.t('app_nearby_radio_failed'))],
          if (lastText != null) ...[
            const SizedBox(height: 8),
            Text(context.t('app_nearby_last', {'text': lastText}), style: TextStyle(fontSize: 12, color: muted)),
          ],
          const SizedBox(height: 4),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => snapshot.hasData
                ? Text('${context.t('app_version')} ${snapshot.data!.version}+${snapshot.data!.buildNumber}', style: TextStyle(fontSize: 12, color: muted))
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    final muted = context.isDark ? Tw.gray400 : Tw.gray500;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 14, color: muted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
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
                if (mounted) _reloadDevices();
              },
            ),
    );
  }
}

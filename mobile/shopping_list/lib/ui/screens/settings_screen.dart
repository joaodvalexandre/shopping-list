import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/repository.dart';
import '../../state/menu_service.dart';
import '../../state/settings_state.dart';
import '../../state/sync_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/menu_footer.dart';
import '../widgets/password_form.dart';
import '../widgets/top_bar.dart';

/// Profile, language, password, devices and sync: the web's settings page plus what only a phone has.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<Map<String, dynamic>>> _devices;

  @override
  void initState() {
    super.initState();
    _devices = _loadDevices();
  }

  Future<List<Map<String, dynamic>>> _loadDevices() => context.read<ApiClient>().devices();

  void _reloadDevices() => setState(() => _devices = _loadDevices());

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final repository = context.watch<Repository>();
    final sync = context.watch<SyncService>();
    final menus = context.watch<MenuService>();
    final me = repository.me;
    final dark = context.isDark;
    final muted = dark ? Tw.gray400 : Tw.gray500;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('settings'), style: const TextStyle(fontSize: 18)),
        actions: const [ThemeToggle(), SizedBox(width: 12)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
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
                _row(context.t('email'), me?.email ?? ''),
                _row(context.t('family'), me?.familyName ?? ''),
                _row(context.t('role'), me == null ? '' : context.t(me.isAdmin ? 'role_admin' : 'role_member')),
                const SizedBox(height: 12),
                Text(context.t('language'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Tw.gray300 : Tw.gray700)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: settings.language,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final entry in SettingsState.supportedLanguages.entries)
                      DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: (code) => code == null ? null : settings.setLanguage(code),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const Panel(padding: EdgeInsets.all(20), child: PasswordForm()),
          const SizedBox(height: 12),

          // Sync
          Panel(
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
                    onPressed: sync.isSyncing ? null : sync.sync,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Devices
          Panel(
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
          const SizedBox(height: 12),

          // Links arranged in the backoffice (About, Privacy...)
          if (menus.userMenu.isNotEmpty)
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final link in menus.userMenu)
                    if (link.url != null)
                      ListTile(
                        dense: true,
                        title: Text(link.label),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => openLink(link),
                      ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          Align(
            alignment: Alignment.center,
            child: FilledButton(onPressed: () => signOut(context), child: Text(context.t('logout').toUpperCase())),
          ),
          const MenuFooter(),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/family.dart';
import '../../data/repository.dart';
import '../../state/sync_service.dart';
import '../theme.dart';
import '../who.dart';
import '../widgets/common.dart';
import '../widgets/family_cards.dart';
import '../widgets/family_dialogs.dart';
import 'member_form_screen.dart';

/// The web's Family pages for a family admin: members (with their permissions) and list types.
/// Needs a connection: these are changes to other people's accounts, so they are made
/// on the server at once and shown as it answers.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  FamilyData? _data;
  bool _loading = true;
  bool _offline = false;
  String? _error;
  bool _showTypes = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    if (_data == null) setState(() => _loading = true);

    try {
      final data = FamilyData.fromJson(await api.family());
      if (!mounted) return;
      setState(() {
        _data = data;
        _offline = false;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = e.isOffline;
        _error = e.isOffline ? null : e.firstMessage();
      });
    }
  }

  /// Run a change; on a refusal say why, on success load what the server now has.
  Future<T?> _run<T>(Future<T> Function() change) async {
    try {
      final result = await change();
      await _load();
      return result;
    } on ApiException catch (e) {
      if (mounted) toast(context, e.isOffline ? context.rt('app_cannot_reach') : e.firstMessage());
      return null;
    }
  }

  Future<void> _openMemberForm({FamilyMember? member}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MemberFormScreen(listTypes: _data!.listTypes, member: member)),
    );
    if (changed == true) _load();
  }

  Future<void> _resetPassword(FamilyMember member) async {
    if (!await confirm(context, context.rt('confirm_reset_password'), action: context.rt('reset_password'))) return;

    final password = await _run(() => context.read<ApiClient>().resetMemberPassword(member.id));
    if (password != null && mounted) {
      await showTemporaryPassword(context, name: member.name, email: member.email, password: password);
      _load();
    }
  }

  Future<void> _deleteMember(FamilyMember member) async {
    if (!await confirm(context, context.rt('app_delete_member_confirm', {'name': member.name}))) return;
    await _run(() => context.read<ApiClient>().deleteMember(member.id));
  }

  Future<void> _deleteType(FamilyListType type) async {
    if (!await confirm(context, context.rt('app_delete_type_confirm', {'name': type.name}))) return;
    await _run(() => context.read<ApiClient>().deleteListType(type.id));
    // The lists screen offers these types too
    if (mounted) context.read<SyncService>().sync();
  }

  Future<void> _typeDialog({FamilyListType? type}) async {
    final api = context.read<ApiClient>();

    final saved = await askListTypeName(
      context,
      title: context.rt(type == null ? 'new_list_type' : 'app_edit_list_type'),
      initial: type?.name ?? '',
      save: (name) => type == null ? api.createListType(name) : api.renameListType(type.id, name),
    );

    if (saved) {
      await _load();
      if (mounted) context.read<SyncService>().sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final muted = dark ? Tw.gray400 : Tw.gray500;
    final data = _data;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: scrollPadding,
        children: [
          if (data != null) ...[
            _header(context),
            const SizedBox(height: 12),
            Row(
              children: [
                _tab(context.t('members'), !_showTypes, () => setState(() => _showTypes = false)),
                const SizedBox(width: 8),
                _tab(context.t('list_types'), _showTypes, () => setState(() => _showTypes = true)),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: PillButton(
                label: context.t(_showTypes ? 'new_list_type' : 'new_member'),
                icon: Icons.add,
                onPressed: _showTypes ? () => _typeDialog() : () => _openMemberForm(),
              ),
            ),
            const SizedBox(height: 12),
            if (_offline) ...[Notice(context.t('app_family_offline')), const SizedBox(height: 12)],
            if (!_showTypes)
              for (final member in data.members) ...[_memberCard(context, member), const SizedBox(height: 8)]
            else ...[
              if (data.listTypes.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(context.t('no_list_types_yet'), textAlign: TextAlign.center, style: TextStyle(color: muted))),
              for (final type in data.listTypes) ...[_typeCard(context, type), const SizedBox(height: 8)],
            ],
          ] else if (_loading)
            const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
          else ...[
            Notice(_offline ? context.t('app_family_offline') : (_error ?? context.t('app_cannot_reach')), error: !_offline),
            const SizedBox(height: 12),
            Center(child: PillButton(label: context.t('app_try_again'), icon: Icons.refresh, onPressed: _load)),
          ],
        ],
      ),
    );
  }

  /// That this person is in the family, as whom, and how it is with the web app.
  Widget _header(BuildContext context) {
    final me = context.read<Repository>().me;
    final sync = context.watch<SyncService>();

    final (String text, IconData icon, Color color) = _offline || sync.status == SyncStatus.offline
        ? (context.t('app_offline'), Icons.cloud_off_outlined, Tw.gray500)
        : sync.status == SyncStatus.error
            ? (context.t('app_sync_error'), Icons.error_outline, Tw.red600)
            : sync.status == SyncStatus.syncing
                ? (context.t('app_syncing'), Icons.sync, Tw.blue500)
                : (context.t('app_family_online'), Icons.cloud_done_outlined, Tw.green600);

    return FamilyHeader(
      familyName: me?.familyName ?? '',
      you: context.t('app_family_you_as', {'name': context.who(me?.name ?? '')}),
      statusText: text,
      statusIcon: icon,
      statusColor: color,
    );
  }

  /// The web's two pills: the current one dark, the other light.
  Widget _tab(String label, bool selected, VoidCallback onTap) => FamilyTabPill(label: label, selected: selected, onTap: onTap);

  Widget _memberCard(BuildContext context, FamilyMember member) {
    final dark = context.isDark;
    final own = member.id == context.read<Repository>().me?.userId;

    return FamilyMemberCard(
      name: context.who(member.name),
      own: own,
      subtitle: member.email,
      pills: [
        StatusPill(text: context.t(member.isAdmin ? 'role_admin' : 'role_member'), color: member.isAdmin ? Tw.purple500 : Tw.blue500),
        StatusPill(text: context.t(member.mustChangePassword ? 'pending_first_login' : 'active'), color: member.mustChangePassword ? Tw.yellow500 : Tw.green500),
      ],
      actions: [
        IconButton(
          tooltip: context.t('edit'),
          icon: Icon(Icons.edit_outlined, color: dark ? Tw.amber400 : Tw.amber600),
          onPressed: () => _openMemberForm(member: member),
        ),
        IconButton(
          tooltip: context.t('reset_password'),
          icon: Icon(Icons.lock_reset, color: dark ? Tw.blue500 : Tw.blue600),
          onPressed: () => _resetPassword(member),
        ),
        // Nobody removes their own account (the server refuses it too)
        if (!own)
          IconButton(
            tooltip: context.t('delete'),
            icon: Icon(Icons.delete_outline, color: dark ? Tw.red400 : Tw.red600),
            onPressed: () => _deleteMember(member),
          ),
      ],
    );
  }

  Widget _typeCard(BuildContext context, FamilyListType type) {
    final dark = context.isDark;

    return FamilyTypeCard(
      name: type.name,
      listsCount: type.listsCount,
      actions: [
        IconButton(
          tooltip: context.t('edit'),
          icon: Icon(Icons.edit_outlined, color: dark ? Tw.amber400 : Tw.amber600),
          onPressed: () => _typeDialog(type: type),
        ),
        // A type that still has lists cannot go: the same rule as on the web
        if (type.listsCount == 0)
          IconButton(
            tooltip: context.t('delete'),
            icon: Icon(Icons.delete_outline, color: dark ? Tw.red400 : Tw.red600),
            onPressed: () => _deleteType(type),
          ),
      ],
      note: type.listsCount == 0 ? null : context.t('app_type_in_use'),
    );
  }
}

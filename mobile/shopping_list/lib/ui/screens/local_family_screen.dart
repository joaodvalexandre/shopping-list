import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/repository.dart';
import '../../peer/local_family.dart';
import '../../peer/nearby_service.dart';
import '../../state/auth_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/family_dialogs.dart';
import '../widgets/top_bar.dart';

/// The management page of a local family: that this phone is in it, who else is, how the link
/// with them is, the code and QR code to bring more phones in, and the list types.
class LocalFamilyScreen extends StatelessWidget {
  const LocalFamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<Repository>();
    final nearby = context.watch<NearbyService>();
    final family = context.read<AuthState>().localFamily?.currentSync;
    final muted = context.isDark ? Tw.gray400 : Tw.gray500;
    final me = repository.me;

    final (String linkText, IconData linkIcon, Color linkColor) = localLinkLine(context, nearby);

    return ListView(
      padding: scrollPadding,
      children: [
        // Am I in the family?
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.check_circle, color: context.isDark ? Tw.green500 : Tw.green600),
                const SizedBox(width: 8),
                Expanded(child: Text(context.t('app_family_you_in'), style: TextStyle(fontSize: 13, color: muted))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text(
                    (me?.familyName ?? '').isEmpty ? context.t('app_offline_family_unknown') : me!.familyName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: context.t('app_family_rename'),
                  icon: Icon(Icons.edit_outlined, color: context.isDark ? Tw.amber400 : Tw.amber600),
                  onPressed: () => askListTypeName(
                    context,
                    title: context.rt('app_family_name_title'),
                    initial: me?.familyName ?? '',
                    save: (name) async => repository.renameFamily(name),
                  ),
                ),
              ]),
              Row(children: [
                Expanded(child: Text(context.t('app_family_you_as', {'name': me?.name ?? ''}), style: TextStyle(fontSize: 14, color: muted))),
                IconButton(
                  tooltip: context.t('app_family_rename'),
                  icon: Icon(Icons.edit_outlined, size: 20, color: context.isDark ? Tw.amber400 : Tw.amber600),
                  onPressed: () => askListTypeName(
                    context,
                    title: context.rt('app_family_my_name_title'),
                    initial: me?.name ?? '',
                    save: (name) async => repository.renameMe(name),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(linkIcon, size: 18, color: linkColor),
                const SizedBox(width: 8),
                Expanded(child: Text(linkText, style: TextStyle(fontSize: 13, color: linkColor, fontWeight: FontWeight.w600))),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // The people
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('app_family_members'), style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              for (final member in repository.localMembers) _member(context, repository, nearby, member, muted),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // The code and the QR code
        if (family != null)
          Panel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('app_offline_code'), style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(context.t('app_family_qr_help'), style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 12),
                Center(child: FamilyQr(code: family.code, familyName: me?.familyName ?? family.familyName)),
                const SizedBox(height: 12),
                Center(
                  child: SelectableText(
                    LocalFamilyCodes.format(family.code),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 2),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: PillButton(
                    label: context.t('app_offline_copy'),
                    icon: Icons.copy,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: LocalFamilyCodes.format(family.code)));
                      if (context.mounted) toast(context, context.rt('app_offline_copied'));
                    },
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // The list types
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(context.t('app_family_types'), style: const TextStyle(fontSize: 20))),
                PillButton(
                  label: context.t('app_family_type_new'),
                  icon: Icons.add,
                  onPressed: () => askListTypeName(
                    context,
                    title: context.rt('app_family_type_new'),
                    save: (name) async => repository.addLocalType(name),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              for (final type in repository.localTypes) _type(context, repository, type, muted),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Align(
          alignment: Alignment.center,
          child: OutlinedButton(onPressed: () => signOut(context), child: Text(context.t('app_offline_leave').toUpperCase())),
        ),
      ],
    );
  }

  Widget _member(BuildContext context, Repository repository, NearbyService nearby, LocalMember member, Color muted) {
    final isMe = member.id == repository.localMyId;
    final connected = nearby.connectedMemberId == member.id;

    final String status;
    final Color color;
    if (isMe) {
      status = context.t('app_family_this_phone');
      color = muted;
    } else if (connected) {
      status = context.t('app_family_connected_now');
      color = context.isDark ? Tw.green500 : Tw.green600;
    } else if (member.seenAt != null) {
      status = context.t('app_family_seen', {'time': _ago(context, member.seenAt!)});
      color = muted;
    } else {
      status = context.t('app_family_not_met');
      color = muted;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(isMe ? Icons.person : Icons.person_outline, color: connected ? color : null),
      title: Text(isMe ? '${member.name}  (${context.t('app_family_you')})' : member.name),
      subtitle: Text(status, style: TextStyle(fontSize: 12, color: color)),
      trailing: isMe
          ? null
          : IconButton(
              tooltip: context.t('app_family_remove_member'),
              icon: Icon(Icons.person_remove_outlined, color: context.isDark ? Tw.red400 : Tw.red600),
              onPressed: () async {
                if (await confirm(context, context.rt('app_family_remove_confirm', {'name': member.name}), action: context.rt('app_family_remove_member'))) {
                  repository.removeLocalMember(member.id);
                }
              },
            ),
    );
  }

  Widget _type(BuildContext context, Repository repository, MapEntry<int, String> type, Color muted) {
    final lists = repository.listsOfType(type.key);
    final canDelete = type.key != Repository.localTypeId && lists == 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(type.value),
      subtitle: Text(context.t('app_family_type_lists', {'count': lists}), style: TextStyle(fontSize: 12, color: muted)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: context.t('app_family_rename'),
          icon: Icon(Icons.edit_outlined, color: context.isDark ? Tw.amber400 : Tw.amber600),
          onPressed: () => askListTypeName(
            context,
            title: context.rt('app_family_type_rename'),
            initial: type.value,
            save: (name) async => repository.renameLocalType(type.key, name),
          ),
        ),
        IconButton(
          tooltip: canDelete ? context.t('delete') : context.t('app_family_type_in_use'),
          icon: Icon(Icons.delete_outline, color: canDelete ? (context.isDark ? Tw.red400 : Tw.red600) : muted),
          onPressed: !canDelete
              ? null
              : () async {
                  if (await confirm(context, context.rt('app_family_type_delete_confirm', {'name': type.value}))) {
                    repository.deleteLocalType(type.key);
                  }
                },
        ),
      ]),
    );
  }

  /// "5 min ago", "2 h ago", "3 days ago".
  String _ago(BuildContext context, int ms) {
    final passed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));

    if (passed.inMinutes < 1) return context.rt('app_ago_now');
    if (passed.inHours < 1) return context.rt('app_ago_minutes', {'n': passed.inMinutes});
    if (passed.inDays < 1) return context.rt('app_ago_hours', {'n': passed.inHours});
    return context.rt('app_ago_days', {'n': passed.inDays});
  }
}

/// The family's QR code: another phone scans it to join with no typing.
class FamilyQr extends StatelessWidget {
  const FamilyQr({super.key, required this.code, required this.familyName, this.size = 190});

  final String code;
  final String familyName;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: QrImageView(
        data: LocalFamilyInvite.encode(code, familyName),
        size: size,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/repository.dart';
import '../../peer/local_family.dart';
import '../../peer/nearby_service.dart';
import '../../state/auth_state.dart';
import '../../state/family_link.dart';
import '../theme.dart';
import '../who.dart';
import '../widgets/common.dart';
import '../widgets/family_cards.dart';
import '../widgets/family_dialogs.dart';
import '../widgets/top_bar.dart';
import 'local_member_screen.dart';
import 'offline_start_screen.dart';

/// The management page of an offline family. It looks like a server family's (the same two pills
/// for people and list types, the same cards), with what only an offline family has on top: that
/// this phone is in the family, and how the link with the others is.
class LocalFamilyScreen extends StatefulWidget {
  const LocalFamilyScreen({super.key});

  @override
  State<LocalFamilyScreen> createState() => _LocalFamilyScreenState();
}

class _LocalFamilyScreenState extends State<LocalFamilyScreen> with WidgetsBindingObserver {
  bool _showTypes = false;

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
    final repository = context.watch<Repository>();
    final nearby = context.watch<NearbyService>();
    final family = context.read<AuthState>().localFamily?.currentSync;
    final dark = context.isDark;
    final muted = dark ? Tw.gray400 : Tw.gray500;
    final me = repository.me;
    final admin = repository.isLocalAdmin;

    final (String linkText, IconData linkIcon, Color linkColor) = localLinkLine(context, nearby);

    return ListView(
      padding: scrollPadding,
      children: [
        // That this phone is in the family, as whom, and how the link with the others is
        FamilyHeader(
          familyName: me?.familyName ?? '',
          you: context.t('app_family_you_as', {'name': context.who(me?.name ?? '')}),
          statusText: linkText,
          statusIcon: linkIcon,
          statusColor: linkColor,
          onRename: admin
              ? () => askListTypeName(
                    context,
                    title: context.rt('app_family_name_title'),
                    initial: me?.familyName ?? '',
                    save: (name) async => repository.renameFamily(name),
                  )
              : null,
        ),
        const SizedBox(height: 12),

        // So the family stays connected with the screen off, the phone must let the app run in the background
        FutureBuilder<bool>(
          key: ValueKey(_batteryCheck),
          future: context.read<FamilyLink>().batteryExempt(),
          builder: (context, snapshot) {
            if (snapshot.data != false) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('app_family_background_help'), style: TextStyle(fontSize: 13, color: muted)),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PillButton(
                        label: context.t('app_family_background_allow'),
                        icon: Icons.battery_charging_full,
                        onPressed: () async {
                          await context.read<FamilyLink>().askBatteryExemption();
                          if (mounted) setState(() => _batteryCheck++);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // The tabs, and (only for the admin, who brings people in and shapes the list types) the button that adds one
        FamilyTabsBar(
          tabs: [
            FamilyTabPill(label: context.t('members'), selected: !_showTypes, onTap: () => setState(() => _showTypes = false)),
            FamilyTabPill(label: context.t('list_types'), selected: _showTypes, onTap: () => setState(() => _showTypes = true)),
          ],
          action: admin && family != null && !_showTypes
              ? PillButton(
                  label: context.t('app_family_invite'),
                  icon: Icons.qr_code_2,
                  onPressed: () => showFamilyCode(context, family.code, me?.familyName ?? family.familyName),
                )
              : admin && _showTypes
                  ? PillButton(
                      label: context.t('new_list_type'),
                      icon: Icons.add,
                      onPressed: () => askListTypeName(context, title: context.rt('new_list_type'), save: (name) async => repository.addLocalType(name)),
                    )
                  : null,
        ),
        const SizedBox(height: 12),

        if (!_showTypes)
          for (final member in repository.localMembers) ...[_memberCard(context, repository, nearby, member, admin), const SizedBox(height: 8)]
        else
          for (final type in repository.localTypes) ...[_typeCard(context, repository, type, admin), const SizedBox(height: 8)],

        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: OutlinedButton(onPressed: () => signOut(context), child: Text(context.t('app_offline_leave').toUpperCase())),
        ),
      ],
    );
  }

  Widget _memberCard(BuildContext context, Repository repository, NearbyService nearby, LocalMember member, bool admin) {
    final dark = context.isDark;
    final own = member.id == repository.localMyId;
    final connected = nearby.connectedMemberIds.contains(member.id);

    final String status;
    final Color statusColor;
    if (own) {
      status = context.t('active');
      statusColor = Tw.green500;
    } else if (connected) {
      status = context.t('app_family_connected_now');
      statusColor = Tw.green500;
    } else if (member.seenAt != null) {
      status = context.t('app_family_seen', {'time': _ago(context, member.seenAt!)});
      statusColor = Tw.gray500;
    } else {
      status = context.t('app_family_not_met');
      statusColor = Tw.yellow500;
    }

    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LocalMemberScreen(memberId: member.id)));

    return FamilyMemberCard(
      name: context.who(member.name),
      own: own,
      onTap: open,
      // (an offline family has no emails: the line says whose phone it is)
      subtitle: own ? context.t('app_family_this_phone') : context.t('app_family_other_phone'),
      pills: [
        StatusPill(text: context.t(member.isAdmin ? 'role_admin' : 'role_member'), color: member.isAdmin ? Tw.purple500 : Tw.blue500),
        StatusPill(text: status, color: statusColor),
      ],
      actions: [
        // Everyone changes their own name; the admin sets what the others may do
        if (own || (admin && !member.founder))
          IconButton(
            tooltip: context.t('edit'),
            icon: Icon(Icons.edit_outlined, color: dark ? Tw.amber400 : Tw.amber600),
            onPressed: own
                ? () => askListTypeName(
                      context,
                      title: context.rt('app_family_my_name_title'),
                      initial: member.name,
                      save: (name) async => repository.renameMe(name),
                    )
                : open,
          )
        else
          IconButton(tooltip: context.t('app_family_see'), icon: const Icon(Icons.visibility_outlined), onPressed: open),
        if (admin && !own)
          IconButton(
            tooltip: context.t('delete'),
            icon: Icon(Icons.delete_outline, color: dark ? Tw.red400 : Tw.red600),
            onPressed: () async {
              if (await confirm(context, context.rt('app_family_remove_confirm', {'name': context.who(member.name)}), action: context.rt('app_family_remove_member'))) {
                repository.removeLocalMember(member.id);
              }
            },
          ),
      ],
    );
  }

  Widget _typeCard(BuildContext context, Repository repository, MapEntry<int, String> type, bool admin) {
    final dark = context.isDark;
    final lists = repository.listsOfType(type.key);
    final canDelete = type.key != Repository.localTypeId && lists == 0;

    return FamilyTypeCard(
      name: type.value,
      listsCount: lists,
      actions: [
        if (admin) ...[
          IconButton(
            tooltip: context.t('edit'),
            icon: Icon(Icons.edit_outlined, color: dark ? Tw.amber400 : Tw.amber600),
            onPressed: () => askListTypeName(
              context,
              title: context.rt('app_family_type_rename'),
              initial: type.value,
              save: (name) async => repository.renameLocalType(type.key, name),
            ),
          ),
          // A type that still has lists cannot go: the same rule as for a server family
          if (canDelete)
            IconButton(
              tooltip: context.t('delete'),
              icon: Icon(Icons.delete_outline, color: dark ? Tw.red400 : Tw.red600),
              onPressed: () async {
                if (await confirm(context, context.rt('app_family_type_delete_confirm', {'name': type.value}))) {
                  repository.deleteLocalType(type.key);
                }
              },
            ),
        ],
      ],
      note: admin && !canDelete ? context.t('app_type_in_use') : null,
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
      // A fixed box: the QR widget is built with a LayoutBuilder, which cannot be measured by a dialog
      // that sizes itself to its content (it then draws nothing at all)
      child: SizedBox(
        width: size,
        height: size,
        child: QrImageView(
          data: LocalFamilyInvite.encode(code, familyName),
          size: size,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
        ),
      ),
    );
  }
}

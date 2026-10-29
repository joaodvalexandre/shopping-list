import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/me.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../peer/nearby_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// One person of an offline family: who they are, what they may do in each list type, and which
/// lists are hidden from them (for surprises). The admin changes these; everyone else sees them.
class LocalMemberScreen extends StatefulWidget {
  const LocalMemberScreen({super.key, required this.memberId});

  final String memberId;

  @override
  State<LocalMemberScreen> createState() => _LocalMemberScreenState();
}

class _LocalMemberScreenState extends State<LocalMemberScreen> {
  Map<int, Map<Ability, bool>>? _rights;
  bool _changed = false;
  bool _saving = false;

  /// Any ability includes viewing, as on the web; taking viewing away takes everything away.
  void _toggle(int typeId, Ability ability, bool on) {
    final abilities = _rights![typeId]!;

    setState(() {
      _changed = true;
      abilities[ability] = on;
      if (ability == Ability.view && !on) {
        for (final other in Ability.values) {
          abilities[other] = false;
        }
      } else if (on) {
        abilities[Ability.view] = true;
      }
    });
  }

  Future<void> _save(Repository repository) async {
    setState(() => _saving = true);
    final saved = await repository.setLocalRights(widget.memberId, _rights!);

    if (!mounted) return;
    setState(() {
      _saving = false;
      _changed = !saved;
    });
    if (saved) toast(context, context.rt('app_member_saved'));
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<Repository>();
    final nearby = context.watch<NearbyService>();
    final muted = context.isDark ? Tw.gray400 : Tw.gray500;

    final member = repository.localMembers.where((m) => m.id == widget.memberId).firstOrNull;
    if (member == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(context.t('app_family_not_met'))));
    }

    final isMe = member.id == repository.localMyId;
    final editable = repository.isLocalAdmin && !member.founder && !isMe;

    // what is shown is what the admin set, until the admin starts changing it here
    _rights ??= repository.localRightsOf(member.id).map((typeId, abilities) => MapEntry(typeId, Map.of(abilities)));
    if (!_changed && !_saving) {
      _rights = repository.localRightsOf(member.id).map((typeId, abilities) => MapEntry(typeId, Map.of(abilities)));
    }

    final types = repository.localTypes;
    final lists = repository.lists;

    return Scaffold(
      appBar: AppBar(title: Text(member.name, style: const TextStyle(fontSize: 18))),
      body: ListView(
        padding: scrollPadding,
        children: [
          Panel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(isMe ? '${member.name}  (${context.t('app_family_you')})' : member.name, style: const TextStyle(fontSize: 20))),
                  StatusPill(
                    text: context.t(member.founder ? 'role_admin' : 'role_member'),
                    color: member.founder ? Tw.purple500 : Tw.blue500,
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  isMe
                      ? context.t('app_family_this_phone')
                      : nearby.connectedMemberId == member.id
                          ? context.t('app_family_connected_now')
                          : member.seenAt != null
                              ? context.t('app_family_seen', {'time': _ago(context, member.seenAt!)})
                              : context.t('app_family_not_met'),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // What they may do
          Panel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('permissions'), style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                if (member.founder)
                  Text(context.t('admin_role_help'), style: TextStyle(fontSize: 12, color: muted))
                else ...[
                  Text(editable ? context.t('permissions_help') : context.t('app_member_only_admin'), style: TextStyle(fontSize: 12, color: muted)),
                  const SizedBox(height: 12),
                  for (final type in types) _typeRights(context, type, editable),
                  if (editable) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _saving || !_changed ? null : () => _save(repository),
                        child: Text(context.t('save').toUpperCase()),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Which lists are hidden from them (only those they could otherwise see)
          if (!isMe && !member.founder)
            Panel(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t('hidden_from'), style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(context.t('hidden_from_help'), style: TextStyle(fontSize: 12, color: muted)),
                  const SizedBox(height: 8),
                  if (lists.isEmpty) Text(context.t('no_lists_yet'), style: TextStyle(color: muted)),
                  for (final list in lists) _hiding(context, repository, list, member),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// One list type: a chip per ability, to switch on or off (or just to see, for those who may not change them).
  Widget _typeRights(BuildContext context, MapEntry<int, String> type, bool editable) {
    final abilities = _rights![type.key] ?? const <Ability, bool>{};

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type.value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final ability in Ability.values)
                FilterChip(
                  label: Text(context.t('ability_${abilityKeys[ability]}')),
                  selected: abilities[ability] ?? false,
                  visualDensity: VisualDensity.compact,
                  onSelected: editable ? (on) => _toggle(type.key, ability, on) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// A list of a type this person may see, and whether it is hidden from them.
  Widget _hiding(BuildContext context, Repository repository, ShoppingListRecord list, LocalMember member) {
    final mayBeSeen = _rights?[list.listTypeId]?[Ability.view] ?? false;
    if (!mayBeSeen) return const SizedBox.shrink();

    final hidden = list.hiddenFrom.contains(member.number);
    final canChange = repository.can(list, Ability.manageLists);

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(list.name),
      subtitle: Text(repository.listTypeName(list.listTypeId), style: const TextStyle(fontSize: 12)),
      value: hidden,
      onChanged: !canChange
          ? null
          : (on) => repository.updateList(
                list.uuid,
                name: list.name,
                hiddenFrom: [
                  for (final number in list.hiddenFrom)
                    if (number != member.number) number,
                  if (on) member.number,
                ],
              ),
    );
  }

  String _ago(BuildContext context, int ms) {
    final passed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));

    if (passed.inMinutes < 1) return context.rt('app_ago_now');
    if (passed.inHours < 1) return context.rt('app_ago_minutes', {'n': passed.inMinutes});
    if (passed.inDays < 1) return context.rt('app_ago_hours', {'n': passed.inHours});
    return context.rt('app_ago_days', {'n': passed.inDays});
  }
}

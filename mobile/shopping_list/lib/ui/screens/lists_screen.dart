import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/me.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/sync_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'list_detail_screen.dart';
import 'list_form_screen.dart';

/// The web's "Shopping List" page: every list with counters, status and actions.
class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<Repository>();
    final lists = repository.lists;
    final canCreate = repository.me?.canCreateLists ?? false;

    return RefreshIndicator(
      onRefresh: context.read<SyncService>().sync,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: scrollPadding,
        children: [
          if (canCreate)
            Align(
              alignment: Alignment.centerRight,
              child: PillButton(
                label: context.t('new_list'),
                icon: Icons.add,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ListFormScreen())),
              ),
            ),
          if (canCreate) const SizedBox(height: 12),
          if (lists.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Text(
                context.t('no_lists_yet'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.isDark ? Tw.gray400 : Tw.gray500),
              ),
            ),
          for (final list in lists) ...[
            _ListRow(list: list),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.list});

  final ShoppingListRecord list;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<Repository>();
    final dark = context.isDark;
    final state = ListState.of(list);
    final canManage = repository.can(list, Ability.manageLists);
    final muted = dark ? Tw.gray400 : Tw.gray500;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListDetailScreen(listUuid: list.uuid))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: list.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        TextSpan(text: '  ${repository.listTypeName(list.listTypeId)}', style: TextStyle(fontSize: 12, color: muted)),
                      ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canManage) ...[
                    IconButton(
                      tooltip: context.t('edit'),
                      icon: Icon(Icons.edit_outlined, color: dark ? Tw.amber400 : Tw.amber600),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListFormScreen(listUuid: list.uuid))),
                    ),
                    IconButton(
                      tooltip: context.t('delete'),
                      icon: Icon(Icons.delete_outline, color: dark ? Tw.red400 : Tw.red600),
                      onPressed: () async {
                        if (await confirm(context, context.rt('confirm_delete_single'))) {
                          repository.deleteList(list.uuid);
                        }
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: StatusPill(text: context.t(state.textKey), color: Tw.named(state.color))),
              const SizedBox(height: 12),
              // Four equal columns, so labels have room however narrow the phone is
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    _count(context, list.toBuy, 'pending'),
                    _count(context, list.inCart, 'in_cart'),
                    _count(context, list.purchased, 'purchased'),
                    _count(context, list.total, 'total'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _count(BuildContext context, int value, String key) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            context.t(key),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: context.isDark ? Tw.gray400 : Tw.gray500),
          ),
        ],
      ),
    );
  }
}

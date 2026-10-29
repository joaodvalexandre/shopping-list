import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/me.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/sync_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/top_bar.dart';
import 'item_form_screen.dart';

/// One list and its items, with only the buttons this person may use (like the web's list page).
class ListDetailScreen extends StatelessWidget {
  const ListDetailScreen({super.key, required this.listUuid});

  final String listUuid;

  static const _statusColors = {
    ItemStatus.toBuy: Color(0xFFFFA500),
    ItemStatus.inCart: Color(0xFF1E90FF),
    ItemStatus.purchased: Color(0xFF4CAF50),
  };

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<Repository>();
    final list = repository.list(listUuid);

    // Deleted, hidden from me, or permission withdrawn while I was looking
    if (list == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.t('no_lists_yet'))),
      );
    }

    final items = repository.itemsOf(listUuid);
    final canAdd = repository.can(list, Ability.addItems);
    final canEdit = repository.can(list, Ability.editItems);
    final canStatus = repository.can(list, Ability.changeStatus);

    final hasItems = items.isNotEmpty;
    final toBuy = items.where((i) => i.status == ItemStatus.toBuy).length;
    final inCart = items.where((i) => i.status == ItemStatus.inCart).length;
    final allInCart = toBuy + inCart > 0 && toBuy == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name, style: const TextStyle(fontSize: 18)),
        actions: const [ThemeToggle(), SizedBox(width: 12)],
      ),
      body: Column(
        children: [
          const SyncBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (canStatus)
                  PillButton(
                    label: context.t('finish_list'),
                    icon: Icons.shopping_cart_checkout,
                    color: Tw.green500,
                    onPressed: (allInCart && hasItems) ? () => repository.markPurchased(listUuid) : null,
                  ),
                if (canAdd)
                  PillButton(
                    label: context.t('new_item'),
                    icon: Icons.add,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ItemFormScreen(listUuid: listUuid))),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: context.read<SyncService>().sync,
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(32, 48, 32, 40),
                      children: [
                        Text(
                          context.t('no_items_yet'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.isDark ? Tw.gray400 : Tw.gray500),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _ItemRow(
                        item: items[index],
                        canEdit: canEdit,
                        canStatus: canStatus,
                        color: _statusColors[items[index].status]!,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.canEdit, required this.canStatus, required this.color});

  final ItemRecord item;
  final bool canEdit;
  final bool canStatus;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<Repository>();
    final dark = context.isDark;
    final waiting = item.pending.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          decoration: item.status == ItemStatus.purchased ? TextDecoration.lineThrough : null,
                          color: item.status == ItemStatus.purchased ? (dark ? Tw.gray400 : Tw.gray500) : null,
                        ),
                      ),
                    ),
                    if (waiting) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.cloud_upload_outlined, size: 14, color: dark ? Tw.gray400 : Tw.gray500),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${context.t('quant')} ${item.quantity}', style: TextStyle(fontSize: 12, color: dark ? Tw.gray400 : Tw.gray500)),
                    const SizedBox(width: 10),
                    StatusPill(text: context.t(item.status.code), color: color),
                  ]),
                ],
              ),
            ),
            if (item.status == ItemStatus.toBuy && canStatus)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: context.t('add_cart'),
                icon: Icon(Icons.add_shopping_cart, color: dark ? Tw.blue500 : Tw.blue600),
                onPressed: () => repository.setStatus(item.listUuid, item.uuid, ItemStatus.inCart),
              ),
            if (item.status == ItemStatus.inCart && canStatus)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: context.t('remove_cart'),
                icon: Icon(Icons.remove_shopping_cart_outlined, color: dark ? Tw.orange500 : Tw.orange600),
                onPressed: () => repository.setStatus(item.listUuid, item.uuid, ItemStatus.toBuy),
              ),
            if (item.status == ItemStatus.toBuy && canEdit)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: context.t('edit'),
                icon: Icon(Icons.edit_outlined, color: dark ? Tw.amber400 : Tw.amber600),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ItemFormScreen(listUuid: item.listUuid, itemUuid: item.uuid)),
                ),
              ),
            // What is in the cart is about to be bought: it cannot be deleted until taken out
            if (canEdit && item.status != ItemStatus.inCart)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: context.t('delete'),
                icon: Icon(Icons.delete_outline, color: dark ? Tw.red400 : Tw.red600),
                onPressed: () async {
                  if (await confirm(context, context.rt('confirm_delete_single'))) {
                    repository.deleteItem(item.listUuid, item.uuid);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

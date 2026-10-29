import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/sync_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'list_detail_screen.dart';

/// Icons for a list's overall state (the web uses the matching Material Design Icons).
IconData stateIcon(ListState state) => switch (state) {
      ListState.noItems => Icons.remove_shopping_cart_outlined,
      ListState.finished => Icons.check_circle_outline,
      ListState.allInCart => Icons.shopping_cart_checkout,
      ListState.shopping => Icons.shopping_cart_outlined,
      ListState.pending => Icons.add_shopping_cart,
      ListState.mixed => Icons.playlist_add_check,
    };

/// The overview: where the shopping stands across every list (the Shopping List tab is where the
/// lists are): totals, what is in the cart, what is still to buy, and how far each list has got.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// How many of the items still to buy are shown.
  static const _toBuyShown = 8;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<Repository>();
    final lists = repository.lists;

    return RefreshIndicator(
      onRefresh: context.read<SyncService>().sync,
      child: lists.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 40),
              children: [
                const SizedBox(height: 32),
                Text(context.t('dashboard_information'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              ],
            )
          : _overview(context, repository, lists),
    );
  }

  Widget _overview(BuildContext context, Repository repository, List<ShoppingListRecord> lists) {
    final dark = context.isDark;
    final muted = dark ? Tw.gray400 : Tw.gray500;

    final items = [
      for (final list in lists)
        for (final item in repository.itemsOf(list.uuid)) (list: list, item: item),
    ];

    final inCart = items.where((e) => e.item.status == ItemStatus.inCart).toList()
      ..sort((a, b) {
        final byList = a.list.name.toLowerCase().compareTo(b.list.name.toLowerCase());
        return byList != 0 ? byList : a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
      });

    // the newest first (an item's name is stamped when it is added)
    final toBuy = items.where((e) => e.item.status == ItemStatus.toBuy).toList()
      ..sort((a, b) => b.item.nameChangedAt.compareTo(a.item.nameChangedAt));

    final progress = lists.where((l) => l.total > 0).toList()
      ..sort((a, b) => ((b.purchased + b.inCart) / b.total).compareTo((a.purchased + a.inCart) / a.total));

    final toBuyCount = lists.fold<int>(0, (sum, l) => sum + l.toBuy);
    final inCartCount = lists.fold<int>(0, (sum, l) => sum + l.inCart);
    final purchasedCount = lists.fold<int>(0, (sum, l) => sum + l.purchased);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: scrollPadding,
      children: [
        Row(children: [
          _tile(context, lists.length, 'dashboard_lists', dark ? Tw.gray300 : Tw.gray700),
          const SizedBox(width: 8),
          _tile(context, toBuyCount, 'pending', dark ? Tw.amber400 : Tw.amber600),
          const SizedBox(width: 8),
          _tile(context, inCartCount, 'in_cart', dark ? Tw.blue500 : Tw.blue600),
          const SizedBox(width: 8),
          _tile(context, purchasedCount, 'purchased', dark ? Tw.green500 : Tw.green600),
        ]),
        const SizedBox(height: 12),
        _section(
          context,
          'dashboard_in_cart',
          inCart.isEmpty
              ? [Text(context.t('dashboard_cart_empty'), style: TextStyle(fontSize: 13, color: muted))]
              : [for (final e in inCart) _itemRow(context, e.list, e.item)],
        ),
        const SizedBox(height: 12),
        _section(
          context,
          'dashboard_to_buy',
          toBuy.isEmpty
              ? [Text(context.t('dashboard_nothing_to_buy'), style: TextStyle(fontSize: 13, color: muted))]
              : [
                  for (final e in toBuy.take(_toBuyShown)) _itemRow(context, e.list, e.item),
                  if (toBuy.length > _toBuyShown)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(context.t('dashboard_more', {'count': toBuy.length - _toBuyShown}), style: TextStyle(fontSize: 12, color: muted)),
                    ),
                ],
        ),
        if (progress.isNotEmpty) ...[
          const SizedBox(height: 12),
          _section(context, 'dashboard_progress', [for (final list in progress) _progressRow(context, list)]),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, int value, String labelKey, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(context.t(labelKey), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: context.isDark ? Tw.gray400 : Tw.gray500)),
          ]),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String titleKey, List<Widget> children) {
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t(titleKey), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, ShoppingListRecord list, ItemRecord item) {
    final muted = context.isDark ? Tw.gray400 : Tw.gray500;

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListDetailScreen(listUuid: list.uuid))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(child: Text('${item.name}  × ${item.quantity}', maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted)),
        ]),
      ),
    );
  }

  Widget _progressRow(BuildContext context, ShoppingListRecord list) {
    final dark = context.isDark;
    final bought = list.purchased / list.total;
    final carted = list.inCart / list.total;

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListDetailScreen(listUuid: list.uuid))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('${list.purchased}/${list.total}', style: TextStyle(fontSize: 12, color: dark ? Tw.gray400 : Tw.gray500)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Row(children: [
                Expanded(flex: (bought * 1000).round(), child: Container(color: Tw.green500)),
                Expanded(flex: (carted * 1000).round(), child: Container(color: Tw.blue500)),
                Expanded(flex: ((1 - bought - carted) * 1000).round().clamp(0, 1000), child: Container(color: dark ? Tw.gray700 : Tw.gray200)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({super.key, required this.list});

  final ShoppingListRecord list;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final state = ListState.of(list);
    final color = Tw.named(state.color);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListDetailScreen(listUuid: list.uuid))),
        child: Stack(
          children: [
            // The big faded icon behind, like the web
            Positioned(
              right: -40,
              top: 24,
              child: Icon(stateIcon(state), size: 150, color: color.withValues(alpha: dark ? 0.14 : 0.16)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: dark ? Tw.gray300 : Tw.gray700),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: list.total == 0
                        ? Center(
                            child: Text(
                              context.t('empty_list'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Tw.gray400 : Tw.gray500),
                            ),
                          )
                        : Row(
                            children: [
                              _stat(context, list.toBuy, 'pending', dark ? Tw.amber400 : Tw.amber600),
                              _stat(context, list.inCart, 'in_cart', dark ? Tw.blue500 : Tw.blue600),
                              _stat(context, list.purchased, 'purchased', dark ? Tw.green500 : Tw.green600),
                              _stat(context, list.total, 'total', dark ? Tw.gray400 : Tw.gray600),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 4, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, int value, String labelKey, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(
            context.t(labelKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: context.isDark ? Tw.gray400 : Tw.gray500),
          ),
        ],
      ),
    );
  }
}

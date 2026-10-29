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

/// The web's dashboard: one card per list with its counters.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lists = context.watch<Repository>().lists;

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
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 720 ? 2 : 1;

                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: scrollPadding,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 190,
                  ),
                  itemCount: lists.length,
                  itemBuilder: (context, index) => DashboardCard(list: lists[index]),
                );
              },
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

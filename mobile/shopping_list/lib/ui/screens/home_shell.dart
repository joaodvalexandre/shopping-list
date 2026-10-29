import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../state/sync_service.dart';
import '../widgets/common.dart';
import '../widgets/top_bar.dart';
import 'dashboard_screen.dart';
import 'family_screen.dart';
import 'lists_screen.dart';

/// The signed-in app: the web's navbar as a top bar, its main pages as tabs (and Family, for a family admin).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final SyncService _sync;

  @override
  void initState() {
    super.initState();
    _sync = context.read<SyncService>()..addListener(_showRejections);
  }

  @override
  void dispose() {
    _sync.removeListener(_showRejections);
    super.dispose();
  }

  /// What the server refused (no permission, the list is gone...) is said out loud, once.
  void _showRejections() {
    final rejections = _sync.takeRejections();
    if (rejections.isEmpty || !mounted) return;

    final texts = rejections.map((r) {
      final key = switch (r.reason) {
        'forbidden' => 'app_rejected_forbidden',
        'not_found' => 'app_rejected_not_found',
        _ => 'app_rejected_invalid',
      };
      return context.rt(key, {'name': r.name});
    }).toList();

    toast(context, texts.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<Repository>().me?.isAdmin ?? false;
    final titles = [context.t('dashboard'), context.t('shopping_list'), if (admin) context.t('family')];
    // A family admin who is demoted while on the Family tab lands on the last one left
    final index = _index.clamp(0, titles.length - 1);

    return Scaffold(
      appBar: appBar(context),
      body: Column(
        children: [
          const SyncBanner(),
          PageHeader(titles[index]),
          Expanded(
            child: IndexedStack(
              index: index,
              children: [const DashboardScreen(), const ListsScreen(), if (admin) const FamilyScreen()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: titles[0]),
          NavigationDestination(icon: const Icon(Icons.list_alt_outlined), selectedIcon: const Icon(Icons.list_alt), label: titles[1]),
          if (admin) NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups), label: titles[2]),
        ],
      ),
    );
  }
}

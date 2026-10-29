import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/sync_service.dart';
import '../widgets/common.dart';
import '../widgets/top_bar.dart';
import 'dashboard_screen.dart';
import 'lists_screen.dart';

/// The signed-in app: the web's navbar as a top bar, its two main pages as tabs.
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
    final titles = [context.t('dashboard'), context.t('shopping_list')];

    return Scaffold(
      appBar: appBar(context),
      body: Column(
        children: [
          const SyncBanner(),
          PageHeader(titles[_index]),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [DashboardScreen(), ListsScreen()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: titles[0]),
          NavigationDestination(icon: const Icon(Icons.list_alt_outlined), selectedIcon: const Icon(Icons.list_alt), label: titles[1]),
        ],
      ),
    );
  }
}

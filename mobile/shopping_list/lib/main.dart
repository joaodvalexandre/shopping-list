import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/shopping_list.dart';
import 'services/shopping_lists_service.dart';
import 'services/connection_manager.dart';
import 'widgets/create_shopping_list_dialog.dart';
import 'widgets/shopping_list_card.dart';
import 'widgets/overall_statistics_card.dart';
import 'widgets/sync_status_widget.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ShoppingListsService()),
        Provider(create: (context) => ConnectionManager()),
      ],
      child: const ShoppingListApp(),
    ),
  );
}

class ShoppingListApp extends StatelessWidget {
  const ShoppingListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shopping Lists',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const ShoppingListsHomePage(),
    );
  }
}

class ShoppingListsHomePage extends StatefulWidget {
  const ShoppingListsHomePage({super.key});

  @override
  State<ShoppingListsHomePage> createState() => _ShoppingListsHomePageState();
}

class _ShoppingListsHomePageState extends State<ShoppingListsHomePage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load data when the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShoppingListsService>().loadFromStorage();
      context.read<ConnectionManager>().initialize();
    });
  }

  void _showCreateShoppingListDialog() async {
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => const CreateShoppingListDialog(),
    );

    if (result != null && mounted) {
      await context.read<ShoppingListsService>().createShoppingList(result);
    }
  }

  void _editShoppingList(ShoppingList shoppingList) async {
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => const CreateShoppingListDialog(),
    );

    if (result != null && mounted) {
      final updatedList = shoppingList.copyWith(name: result);
      await context.read<ShoppingListsService>().updateShoppingList(updatedList);
    }
  }

  void _deleteShoppingList(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shopping List'),
        content: const Text('Are you sure you want to delete this shopping list? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ShoppingListsService>().deleteShoppingList(id);
    }
  }

  void _onShoppingListTap(ShoppingList shoppingList) {
    // TODO: Navigate to shopping list detail page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${shoppingList.name}...'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  List<ShoppingList> _getFilteredLists(ShoppingListsService service) {
    if (_searchQuery.isEmpty) return service.shoppingLists;
    return service.searchShoppingLists(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Lists'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<ConnectionManager>(
            builder: (context, connectionManager, child) {
              return IconButton(
                icon: Icon(
                  connectionManager.isWebappAvailable
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                  color: connectionManager.isWebappAvailable
                      ? Colors.blue
                      : Colors.grey,
                ),
                onPressed: () async {
                  await connectionManager.checkWebappAvailability();
                },
                tooltip: 'Check webapp connection',
              );
            },
          ),
        ],
      ),
      body: Consumer<ShoppingListsService>(
        builder: (context, service, child) {
          final filteredLists = _getFilteredLists(service);
          final statistics = service.getOverallStatistics();

          return Column(
            children: [
              // Sync status widget
              const SyncStatusWidget(),

              // Statistics card
              if (statistics['totalLists']! > 0)
                OverallStatisticsCard(statistics: statistics),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search shopping lists...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Shopping lists
              Expanded(
                child: filteredLists.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.list_alt_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No shopping lists found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              service.shoppingLists.isEmpty
                                  ? 'Create your first shopping list to get started!'
                                  : 'Try adjusting your search',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredLists.length,
                        itemBuilder: (context, index) {
                          final shoppingList = filteredLists[index];
                          return ShoppingListCard(
                            shoppingList: shoppingList,
                            onTap: () => _onShoppingListTap(shoppingList),
                            onDelete: () => _deleteShoppingList(shoppingList.id),
                            onEdit: () => _editShoppingList(shoppingList),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateShoppingListDialog,
        tooltip: 'Create shopping list',
        child: const Icon(Icons.add),
      ),
    );
  }
}

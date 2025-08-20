import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'models/shopping_list.dart';
import 'services/shopping_lists_service.dart';
import 'services/connection_manager.dart';
import 'services/custom_locale_delegate.dart';
import 'widgets/create_shopping_list_dialog.dart';
import 'widgets/shopping_list_card.dart';
import 'widgets/overall_statistics_card.dart';
import 'widgets/sync_status_widget.dart';
import 'screens/shopping_list_detail_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LocaleService()),
        ChangeNotifierProvider(create: (context) => ConnectionManager()),
        ChangeNotifierProxyProvider<ConnectionManager, ShoppingListsService>(
          create: (context) => ShoppingListsService(context.read<ConnectionManager>()),
          update: (context, connectionManager, previous) =>
              previous ?? ShoppingListsService(connectionManager),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleService>(
      builder: (context, localeService, child) {
        return MaterialApp(
          title: 'Smart Shopping',
          localizationsDelegates: [
            const CustomLocaleDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: localeService.currentLocale,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
          home: const ShoppingListsHomePage(),
        );
      },
    );
  }
}



class ShoppingListsHomePage extends StatefulWidget {
  const ShoppingListsHomePage({super.key});

  @override
  State<ShoppingListsHomePage> createState() => _ShoppingListsHomePageState();
}

class _ShoppingListsHomePageState extends State<ShoppingListsHomePage> {

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
      builder: (context) => CreateShoppingListDialog(
        initialName: shoppingList.name,
        isEditing: true,
      ),
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
        title: Text(AppLocalizations.of(context)?.deleteList ?? 'Delete Shopping List'),
        content: Text(AppLocalizations.of(context)?.deleteListConfirm ?? 'Are you sure you want to delete this shopping list? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ShoppingListsService>().deleteShoppingList(id);
    }
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.selectLanguage ?? 'Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇺🇸'),
              title: Text(AppLocalizations.of(context)?.english ?? 'English'),
              onTap: () {
                Navigator.of(context).pop();
                _changeLanguage(const Locale('en'));
              },
            ),
            ListTile(
              leading: const Text('🇵🇹'),
              title: Text(AppLocalizations.of(context)?.portuguese ?? 'Português'),
              onTap: () {
                Navigator.of(context).pop();
                _changeLanguage(const Locale('pt'));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _changeLanguage(Locale locale) {
    context.read<LocaleService>().changeLanguage(locale);
  }

  void _onShoppingListTap(ShoppingList shoppingList) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShoppingListDetailScreen(
          shoppingList: shoppingList,
        ),
      ),
    );
  }

  List<ShoppingList> _getFilteredLists(ShoppingListsService service) {
    return service.shoppingLists;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Shopping'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Language change button
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => _showLanguageDialog(context),
            tooltip: AppLocalizations.of(context)?.changeLanguage ?? 'Change Language',
          ),
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
                tooltip: AppLocalizations.of(context)?.checkWebappConnection ?? 'Check webapp connection',
              );
            },
          ),
        ],
      ),
      body: Consumer<ShoppingListsService>(
        builder: (context, service, child) {
          final filteredLists = _getFilteredLists(service);
          final statistics = service.getOverallStatistics();

          return CustomScrollView(
            slivers: [
              // Sync status widget
              SliverToBoxAdapter(
                child: const SyncStatusWidget(),
              ),

              // Statistics card
              if (statistics['totalLists']! > 0)
                SliverToBoxAdapter(
                  child: OverallStatisticsCard(statistics: statistics),
                ),



              // Shopping lists
              if (filteredLists.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.list_alt_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                                                            Text(
                                      AppLocalizations.of(context)?.noShoppingLists ?? 'No shopping lists found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppLocalizations.of(context)?.noShoppingListsHint ?? 'Create your first shopping list to get started!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _showCreateShoppingListDialog,
                                      icon: const Icon(Icons.add),
                                      label: Text(AppLocalizations.of(context)?.create ?? 'Create'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final shoppingList = filteredLists[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ShoppingListCard(
                            shoppingList: shoppingList,
                            onTap: () => _onShoppingListTap(shoppingList),
                            onDelete: () => _deleteShoppingList(shoppingList.id),
                            onEdit: () => _editShoppingList(shoppingList),
                          ),
                        );
                      },
                      childCount: filteredLists.length,
                    ),
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

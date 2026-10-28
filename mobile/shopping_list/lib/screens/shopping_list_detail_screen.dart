import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';
import '../services/shopping_lists_service.dart';
import '../widgets/add_item_dialog.dart';
import '../widgets/shopping_item_tile.dart';
import '../l10n/app_localizations.dart';

class ShoppingListDetailScreen extends StatefulWidget {
  final ShoppingList shoppingList;

  const ShoppingListDetailScreen({
    super.key,
    required this.shoppingList,
  });

  @override
  State<ShoppingListDetailScreen> createState() => _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends State<ShoppingListDetailScreen> {
  final String _searchQuery = '';

  void _showAddItemDialog() async {
    if (!mounted) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddItemDialog(),
    );

    if (result != null && mounted) {
      final newItem = ShoppingItem(
        id: '',
        name: result['name'] ?? '',
        quantity: result['quantity'] ?? '1',
        status: ItemStatus.toBuy,
        createdAt: DateTime.now(),
      );

      await context.read<ShoppingListsService>().addItemToList(widget.shoppingList.id, newItem);
    }
  }

  void _editItem(ShoppingItem item) async {
    if (!mounted) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AddItemDialog(
        initialName: item.name,
        initialQuantity: item.quantity,
        title: 'Edit Item',
      ),
    );

    if (result != null && mounted) {
      final updatedItem = item.copyWith(
        name: result['name'],
        quantity: result['quantity'],
      );

      await context.read<ShoppingListsService>().updateItemInList(
        widget.shoppingList.id,
        updatedItem,
      );
    }
  }

  void _deleteItem(ShoppingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.deleteItem ?? 'Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
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
      await context.read<ShoppingListsService>().removeItemFromList(
        widget.shoppingList.id,
        item.id,
      );
    }
  }

    void _addToCart(ShoppingItem item) async {
    final updatedItem = item.copyWith(
      status: ItemStatus.inCart,
      updatedAt: DateTime.now(),
    );

    await context.read<ShoppingListsService>().updateItemInList(
      widget.shoppingList.id,
      updatedItem,
    );
  }

  void _removeFromCart(ShoppingItem item) async {
    final updatedItem = item.copyWith(
      status: ItemStatus.toBuy,
      updatedAt: DateTime.now(),
    );

    await context.read<ShoppingListsService>().updateItemInList(
      widget.shoppingList.id,
      updatedItem,
    );
  }

  void _markAllAsPurchased() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.markAllAsPurchased ?? 'Mark All as Purchased'),
        content: Text(AppLocalizations.of(context)?.markAllAsPurchasedConfirm ?? 'Mark all items in cart as purchased?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)?.markAllAsPurchased ?? 'Mark All as Purchased'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final currentList = context.read<ShoppingListsService>().shoppingLists
          .firstWhere((list) => list.id == widget.shoppingList.id,
              orElse: () => widget.shoppingList);

      for (final item in currentList.items) {
        if (item.isInCart) {
          final updatedItem = item.copyWith(
            status: ItemStatus.purchased,
            completedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await context.read<ShoppingListsService>().updateItemInList(
            widget.shoppingList.id,
            updatedItem,
          );
        }
      }
    }
  }

    bool _allItemsInCart(ShoppingList currentList) {
    if (currentList.items.isEmpty) return false;
    return currentList.items.every((item) => item.isInCart || item.isPurchased);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShoppingListsService>(
      builder: (context, service, child) {
                // Get the current version of the shopping list
        final currentList = service.shoppingLists
            .firstWhere((list) => list.id == widget.shoppingList.id,
                orElse: () => widget.shoppingList);

        final toBuyItems = currentList.items.where((item) => item.isToBuy).toList();
        final inCartItems = currentList.items.where((item) => item.isInCart).toList();
        final purchasedItems = currentList.items.where((item) => item.isPurchased).toList();
        final allInCart = _allItemsInCart(currentList);

        return Scaffold(
          appBar: AppBar(
            title: Text(currentList.name),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                        actions: [
              // Mark all as purchased button (only when all items are in cart)
              if (allInCart && inCartItems.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                  onPressed: _markAllAsPurchased,
                  tooltip: AppLocalizations.of(context)?.markAllAsPurchased ?? 'Mark all as purchased',
                ),
            ],
          ),
          body: Column(
            children: [
              // Statistics summary
              if (currentList.items.isNotEmpty)
                Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'To Buy',
                        toBuyItems.length.toString(),
                        Icons.shopping_cart_outlined,
                        Colors.orange,
                      ),
                      _buildStatItem(
                        'In Cart',
                        inCartItems.length.toString(),
                        Icons.shopping_cart,
                        Colors.blue,
                      ),
                      _buildStatItem(
                        'Purchased',
                        purchasedItems.length.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Items list
              Expanded(
                child: currentList.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items in this list',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your first item to get started!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showAddItemDialog,
                              icon: const Icon(Icons.add),
                              label: Text(AppLocalizations.of(context)?.addItem ?? 'Add Item'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          // To Buy items
                          if (toBuyItems.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                '${AppLocalizations.of(context)?.toBuy ?? 'To Buy'} (${toBuyItems.length})',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...toBuyItems.map((item) => ShoppingItemTile(
                              item: item,
                              onTap: () => _addToCart(item),
                              onEdit: () => _editItem(item),
                              onDelete: () => _deleteItem(item),
                            )),
                          ],

                          // In Cart items
                          if (inCartItems.isNotEmpty) ...[
                            if (toBuyItems.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Divider(),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                '${AppLocalizations.of(context)?.inCart ?? 'In Cart'} (${inCartItems.length})',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...inCartItems.map((item) => ShoppingItemTile(
                              item: item,
                              onTap: () => _removeFromCart(item),
                              onEdit: () => _editItem(item),
                              onDelete: () => _deleteItem(item),
                            )),
                          ],

                          // Purchased items
                          if (purchasedItems.isNotEmpty) ...[
                            if (toBuyItems.isNotEmpty || inCartItems.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Divider(),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                '${AppLocalizations.of(context)?.purchased ?? 'Purchased'} (${purchasedItems.length})',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...purchasedItems.map((item) => ShoppingItemTile(
                              item: item,
                              onEdit: () => _editItem(item),
                              onDelete: () => _deleteItem(item),
                            )),
                          ],
                        ],
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddItemDialog,
            tooltip: AppLocalizations.of(context)?.addItem ?? 'Add item',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

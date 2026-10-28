import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';
import 'web_api_service.dart';
import 'connection_manager.dart';

class ShoppingListsService extends ChangeNotifier {
  final List<ShoppingList> _shoppingLists = [];
  static const String _storageKey = 'shopping_lists';
  static const String _offlineChangesKey = 'offline_changes';

  final WebApiService _webApiService = WebApiService();
  final ConnectionManager _connectionManager;

  // Track offline changes for conflict resolution
  List<Map<String, dynamic>> _offlineChanges = [];

  // Constructor now accepts ConnectionManager
  ShoppingListsService(this._connectionManager) {
    // Removed auto-import callback - user must manually choose when to sync
  }

  // Getters
  List<ShoppingList> get shoppingLists => List.unmodifiable(_shoppingLists);

  List<ShoppingList> get activeLists =>
      _shoppingLists.where((list) => !list.isCompleted).toList();

  List<ShoppingList> get completedLists =>
      _shoppingLists.where((list) => list.isCompleted).toList();

  // Lists that need synchronization
  List<ShoppingList> get listsNeedingSync =>
      _shoppingLists.where((list) => list.needsSync).toList();

  // Offline changes that need to be synced
  List<Map<String, dynamic>> get offlineChanges => List.unmodifiable(_offlineChanges);

  // Check if there are pending offline changes
  bool get hasOfflineChanges => _offlineChanges.isNotEmpty;

  // Add new shopping list
  Future<void> createShoppingList(String name) async {
    final shoppingList = ShoppingList(
      id: _generateId(),
      name: name.trim(),
    );

    _shoppingLists.add(shoppingList);
    await _saveToStorage();

    // Try to sync with webapp if available
    if (_connectionManager.isWebappAvailable) {
      try {
        final webList = await _webApiService.createShoppingList(name);
        // Update local list with web ID
        final updatedList = shoppingList.copyWith(
          webId: webList.webId,
          lastSynced: DateTime.now(),
        );
        final index = _shoppingLists.indexWhere((list) => list.id == shoppingList.id);
        if (index != -1) {
          _shoppingLists[index] = updatedList;
          await _saveToStorage();
        }
      } catch (e) {
        if (kDebugMode) {
          // Failed to sync new list with webapp
        }
        // Mark list as needing sync and track offline change
        final index = _shoppingLists.indexWhere((list) => list.id == shoppingList.id);
        if (index != -1) {
          _shoppingLists[index] = shoppingList.copyWith(
            needsSync: true,
          );
          await _saveToStorage();
        }
        // Track offline change for later sync
        _trackOfflineChange('create', shoppingList.id, {'name': name});
      }
    } else {
      // Webapp not available, track offline change
      _trackOfflineChange('create', shoppingList.id, {'name': name});
    }

    notifyListeners();
  }

  // Update shopping list
  Future<void> updateShoppingList(ShoppingList shoppingList) async {
    final index = _shoppingLists.indexWhere((element) => element.id == shoppingList.id);
    if (index != -1) {
      _shoppingLists[index] = shoppingList.copyWith(
        updatedAt: DateTime.now(),
      );
      await _saveToStorage();

      // Automatically sync with webapp if available
      if (_connectionManager.isWebappAvailable && shoppingList.webId != null) {
        try {
          await _webApiService.updateShoppingList(shoppingList);
          // Update last synced time
          _shoppingLists[index] = _shoppingLists[index].copyWith(
            lastSynced: DateTime.now(),
          );
          await _saveToStorage();
        } catch (e) {
          if (kDebugMode) {
            // Failed to sync updated list with webapp
          }
          // Mark list as needing sync
          _shoppingLists[index] = _shoppingLists[index].copyWith(
            needsSync: true,
          );
          await _saveToStorage();
        }
      }

      notifyListeners();
    }
  }

  // Delete shopping list
  Future<void> deleteShoppingList(String id) async {
    final shoppingList = _shoppingLists.firstWhere((list) => list.id == id);
    _shoppingLists.removeWhere((list) => list.id == id);
    await _saveToStorage();

    // Automatically sync deletion with webapp if available
    if (_connectionManager.isWebappAvailable && shoppingList.webId != null) {
      try {
        await _webApiService.deleteShoppingList(shoppingList.webId!);
      } catch (e) {
        if (kDebugMode) {
          // Failed to sync deletion with webapp
        }
        // If deletion fails on webapp, we need to keep the list locally
        // and mark it for later sync
        _shoppingLists.add(shoppingList.copyWith(
          needsSync: true,
        ));
        await _saveToStorage();
        // Track offline change for later sync
        _trackOfflineChange('delete', shoppingList.id, {'webId': shoppingList.webId});
      }
    } else if (shoppingList.webId != null) {
      // Webapp not available, track offline change
      _trackOfflineChange('delete', shoppingList.id, {'webId': shoppingList.webId});
    }

    notifyListeners();
  }

  // Get shopping list by ID
  ShoppingList? getShoppingListById(String id) {
    try {
      return _shoppingLists.firstWhere((list) => list.id == id);
    } catch (e) {
      return null;
    }
  }

  // Load shopping lists from storage
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        try {
          final List<dynamic> jsonList = json.decode(jsonString);
          _shoppingLists.clear();
          _shoppingLists.addAll(jsonList.map((json) => ShoppingList.fromJson(json)));

          // Sort lists
          _shoppingLists.sort((a, b) {
            if (a.isCompleted != b.isCompleted) {
              return a.isCompleted ? 1 : -1;
            }
            return b.createdAt.compareTo(a.createdAt);
          });

          notifyListeners();
          // Loaded shopping lists from storage
        } catch (parseError) {
          // Error parsing stored data, clearing old format
          // Clear old storage format
          await prefs.remove(_storageKey);
          _shoppingLists.clear();
          notifyListeners();
        }
      }

      // Load offline changes
      await _loadOfflineChanges();

      // Removed auto-import - user must manually choose when to sync
    } catch (e) {
      // Error loading from storage
      // Try to clear storage and start fresh
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_storageKey);
        // Cleared corrupted storage data
      } catch (clearError) {
        // Error clearing storage
      }
    }
  }



  // Save shopping lists to storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(_shoppingLists.map((list) => list.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      // Error saving shopping lists
    }
  }

  // Sync with webapp using individual operations
  Future<Map<String, dynamic>> syncWithWebapp() async {
    if (!_connectionManager.isWebappAvailable) {
      return {
        'success': false,
        'message': 'Webapp not available',
        'synced_count': 0,
      };
    }

    try {
      // Get lists that need sync
      final listsToSync = listsNeedingSync;
      if (listsToSync.isEmpty) {
        return {
          'success': true,
          'message': 'All lists are up to date',
          'synced_count': 0,
        };
      }

      int syncedCount = 0;
      List<String> errors = [];

      // Sync each list individually using proper update operations
      for (final list in listsToSync) {
        try {
          if (list.webId != null) {
            // Update existing list on webapp with all items
            final syncedList = await _webApiService.updateShoppingListWithNewItem(list.webId!, list);

            // Mark as synced and update with webapp data
            final index = _shoppingLists.indexWhere((l) => l.id == list.id);
            if (index != -1) {
              _shoppingLists[index] = list.copyWith(
                items: syncedList.items, // Use synced items with webapp IDs
                needsSync: false,
                lastSynced: DateTime.now(),
              );
            }
            syncedCount++;
          } else {
            // Create new list on webapp
            final syncedList = await _webApiService.createShoppingList(list.name);

            // If list has items, update with items
            if (list.items.isNotEmpty) {
              final updatedList = list.copyWith(webId: syncedList.webId);
              final fullySyncedList = await _webApiService.updateShoppingListWithNewItem(
                syncedList.webId!,
                updatedList
              );

              // Update local list with webapp ID and synced items
              final index = _shoppingLists.indexWhere((l) => l.id == list.id);
              if (index != -1) {
                _shoppingLists[index] = list.copyWith(
                  webId: syncedList.webId,
                  items: fullySyncedList.items, // Use synced items with webapp IDs
                  needsSync: false,
                  lastSynced: DateTime.now(),
                );
              }
            } else {
              // Update local list with webapp ID only
              final index = _shoppingLists.indexWhere((l) => l.id == list.id);
              if (index != -1) {
                _shoppingLists[index] = list.copyWith(
                  webId: syncedList.webId,
                  needsSync: false,
                  lastSynced: DateTime.now(),
                );
              }
            }
            syncedCount++;
          }
        } catch (e) {
          errors.add('Failed to sync list "${list.name}": $e');
        }
      }

      await _saveToStorage();
      notifyListeners();

      return {
        'success': errors.isEmpty,
        'message': errors.isEmpty
            ? 'Successfully synced $syncedCount lists'
            : 'Synced $syncedCount lists with ${errors.length} errors',
        'synced_count': syncedCount,
        'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error syncing with webapp: $e',
        'synced_count': 0,
      };
    }
  }

  // Import from webapp
  Future<Map<String, dynamic>> importFromWebapp() async {
    if (!_connectionManager.isWebappAvailable) {
      return {
        'success': false,
        'message': 'Webapp not available',
        'imported_count': 0,
      };
    }

    try {
      final webLists = await _webApiService.fetchShoppingLists();

      // Merge with local lists, avoiding duplicates
      int importedCount = 0;
      for (final webList in webLists) {
        final existingIndex = _shoppingLists.indexWhere((list) =>
            list.webId == webList.webId);

        if (existingIndex != -1) {
          // Update existing list
          _shoppingLists[existingIndex] = webList;
        } else {
          // Add new list
          _shoppingLists.add(webList);
          importedCount++;
        }
      }

      // Sort and save
      _shoppingLists.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      await _saveToStorage();
      notifyListeners();

      return {
        'success': true,
        'message': 'Successfully imported $importedCount new lists',
        'imported_count': importedCount,
        'total_count': _shoppingLists.length,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error importing from webapp: $e',
        'imported_count': 0,
      };
    }
  }

  // Refresh from webapp (force fresh import)
  Future<Map<String, dynamic>> refreshFromWebapp() async {
    if (!_connectionManager.isWebappAvailable) {
      return {
        'success': false,
        'message': 'Webapp not available',
        'imported_count': 0,
      };
    }

    try {
      // Refreshing shopping lists from webapp
      final webLists = await _webApiService.fetchShoppingLists();

      // Clear existing lists and replace with webapp data
      _shoppingLists.clear();
      _shoppingLists.addAll(webLists);

      // Sort and save
      _shoppingLists.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      await _saveToStorage();
      notifyListeners();

      return {
        'success': true,
        'message': 'Successfully refreshed ${webLists.length} lists from webapp',
        'imported_count': webLists.length,
        'total_count': _shoppingLists.length,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error refreshing from webapp: $e',
        'imported_count': 0,
      };
    }
  }

  // Generate unique ID
  String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  // Get overall statistics
  Map<String, int> getOverallStatistics() {
    final totalLists = _shoppingLists.length;
    final activeLists = _shoppingLists.where((list) => !list.isCompleted).length;
    final completedLists = totalLists - activeLists;

    final totalItems = _shoppingLists.fold<int>(0, (sum, list) => sum + list.items.length);
    final completedItems = _shoppingLists.fold<int>(0, (sum, list) =>
        sum + list.items.where((item) => item.isCompleted).length);
    final pendingItems = totalItems - completedItems;

    return {
      'totalLists': totalLists,
      'activeLists': activeLists,
      'completedLists': completedLists,
      'totalItems': totalItems,
      'completedItems': completedItems,
      'pendingItems': pendingItems,
    };
  }

  // Search shopping lists
  List<ShoppingList> searchShoppingLists(String query) {
    if (query.trim().isEmpty) return _shoppingLists;

    final lowercaseQuery = query.toLowerCase();
    return _shoppingLists.where((list) {
      return list.name.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Get sync status
  Map<String, dynamic> getSyncStatus() {
    final totalLists = _shoppingLists.length;
    final syncedLists = _shoppingLists.where((list) => list.isSynced).length;
    final listsNeedingSync = _shoppingLists.where((list) => list.needsSync).length;

    return {
      'totalLists': totalLists,
      'syncedLists': syncedLists,
      'listsNeedingSync': listsNeedingSync,
      'canSync': _connectionManager.isWebappAvailable,
      'lastChecked': DateTime.now(),
    };
  }

  // Item management methods

  // Add item to shopping list
  Future<void> addItemToList(String listId, ShoppingItem item) async {
    final listIndex = _shoppingLists.indexWhere((list) => list.id == listId);
    if (listIndex == -1) return;

    final currentList = _shoppingLists[listIndex];
    final newItem = item.copyWith(
      id: item.id.isEmpty ? _generateId() : item.id,
      createdAt: DateTime.now(),
    );

    final updatedItems = List<ShoppingItem>.from(currentList.items)..add(newItem);
    final updatedList = currentList.copyWith(
      items: updatedItems,
      updatedAt: DateTime.now(),
    );

    _shoppingLists[listIndex] = updatedList;
    await _saveToStorage();

    // Automatically sync with webapp if available
    if (_connectionManager.isWebappAvailable) {
      try {
        // If list doesn't have webId yet, create it on webapp first
        if (currentList.webId == null) {
          final syncedList = await _webApiService.createShoppingList(currentList.name);
          // Update local list with webapp ID
          final listWithWebId = updatedList.copyWith(
            webId: syncedList.webId,
          );
          _shoppingLists[listIndex] = listWithWebId;
          await _saveToStorage();

          // Now update the entire list with items on webapp
          final fullySyncedList = await _webApiService.updateShoppingListWithNewItem(
            syncedList.webId!,
            listWithWebId
          );

          // Update local list with synced data
          _shoppingLists[listIndex] = listWithWebId.copyWith(
            items: fullySyncedList.items, // Use synced items with webapp IDs
            lastSynced: DateTime.now(),
            needsSync: false,
          );
          await _saveToStorage();
        } else {
          // List already exists on webapp, update it with the new items
          final fullySyncedList = await _webApiService.updateShoppingListWithNewItem(
            currentList.webId!,
            updatedList
          );

          // Update local list with synced data
          _shoppingLists[listIndex] = updatedList.copyWith(
            items: fullySyncedList.items, // Use synced items with webapp IDs
            lastSynced: DateTime.now(),
            needsSync: false,
          );
          await _saveToStorage();
        }
                        } catch (e) {
                    if (kDebugMode) {
                      print('Failed to sync new item with webapp: $e');
                    }
                    // Mark list as needing sync
                    _shoppingLists[listIndex] = updatedList.copyWith(
                      needsSync: true,
                    );
                    await _saveToStorage();
                    // Track offline change for later sync
                    _trackOfflineChange('add_item', listId, {'item': item.toJson()});
                  }
    } else {
      // Webapp not available, track offline change
      _trackOfflineChange('add_item', listId, {'item': item.toJson()});
    }

    notifyListeners();
  }

  // Update item in shopping list
  Future<void> updateItemInList(String listId, ShoppingItem updatedItem) async {
    final listIndex = _shoppingLists.indexWhere((list) => list.id == listId);
    if (listIndex == -1) return;

    final currentList = _shoppingLists[listIndex];
    final items = List<ShoppingItem>.from(currentList.items);
    final itemIndex = items.indexWhere((item) => item.id == updatedItem.id);

    if (itemIndex == -1) return;

    items[itemIndex] = updatedItem.copyWith(updatedAt: DateTime.now());
    final updatedList = currentList.copyWith(
      items: items,
      updatedAt: DateTime.now(),
    );

    _shoppingLists[listIndex] = updatedList;
    await _saveToStorage();

    // Automatically sync with webapp if available
    if (_connectionManager.isWebappAvailable && currentList.webId != null) {
      try {
        // Update the entire list on webapp
        final fullySyncedList = await _webApiService.updateShoppingListWithNewItem(
          currentList.webId!,
          updatedList
        );

        // Update local list with synced data
        _shoppingLists[listIndex] = updatedList.copyWith(
          items: fullySyncedList.items, // Use synced items with webapp IDs
          lastSynced: DateTime.now(),
          needsSync: false,
        );
        await _saveToStorage();
      } catch (e) {
        if (kDebugMode) {
          print('Failed to sync updated item with webapp: $e');
        }
        // Mark list as needing sync
        _shoppingLists[listIndex] = updatedList.copyWith(
          needsSync: true,
        );
        await _saveToStorage();
        // Track offline change for later sync
        _trackOfflineChange('update_item', listId, {'item': updatedItem.toJson()});
      }
    } else {
      // Webapp not available, track offline change
      _trackOfflineChange('update_item', listId, {'item': updatedItem.toJson()});
    }

    notifyListeners();
  }

  // Remove item from shopping list
  Future<void> removeItemFromList(String listId, String itemId) async {
    final listIndex = _shoppingLists.indexWhere((list) => list.id == listId);
    if (listIndex == -1) return;

    final currentList = _shoppingLists[listIndex];
    final items = List<ShoppingItem>.from(currentList.items);
    final itemToRemove = items.firstWhere((item) => item.id == itemId);

    items.removeWhere((item) => item.id == itemId);
    final updatedList = currentList.copyWith(
      items: items,
      updatedAt: DateTime.now(),
    );

    _shoppingLists[listIndex] = updatedList;
    await _saveToStorage();

    // Automatically sync with webapp if available
    if (_connectionManager.isWebappAvailable && currentList.webId != null) {
      try {
        // Update the entire list on webapp (without the deleted item)
        final fullySyncedList = await _webApiService.updateShoppingListWithNewItem(
          currentList.webId!,
          updatedList
        );

        // Update local list with synced data
        _shoppingLists[listIndex] = updatedList.copyWith(
          items: fullySyncedList.items, // Use synced items with webapp IDs
          lastSynced: DateTime.now(),
          needsSync: false,
        );
        await _saveToStorage();
      } catch (e) {
        if (kDebugMode) {
          print('Failed to sync item deletion with webapp: $e');
        }
        // Mark list as needing sync
        _shoppingLists[listIndex] = updatedList.copyWith(
          needsSync: true,
        );
        await _saveToStorage();
        // Track offline change for later sync
        _trackOfflineChange('delete_item', listId, {'itemId': itemId, 'item': itemToRemove.toJson()});
      }
    } else {
      // Webapp not available, track offline change
      _trackOfflineChange('delete_item', listId, {'itemId': itemId, 'item': itemToRemove.toJson()});
    }

    notifyListeners();
  }

  // ===== OFFLINE CHANGE TRACKING METHODS =====

  // Load offline changes from storage
  Future<void> _loadOfflineChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final changesJson = prefs.getString(_offlineChangesKey);

      if (changesJson != null) {
        final List<dynamic> changesList = json.decode(changesJson);
        _offlineChanges = changesList.cast<Map<String, dynamic>>();
        print('Loaded ${_offlineChanges.length} offline changes from storage');
      }
    } catch (e) {
      print('Error loading offline changes: $e');
      _offlineChanges.clear();
    }
  }

  // Save offline changes to storage
  Future<void> _saveOfflineChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_offlineChangesKey, json.encode(_offlineChanges));
    } catch (e) {
      print('Error saving offline changes: $e');
    }
  }

  // Track an offline change
  void _trackOfflineChange(String operation, String listId, Map<String, dynamic> data) {
    final change = {
      'id': _generateId(),
      'operation': operation, // 'create', 'update', 'delete', 'add_item', 'update_item', 'delete_item'
      'listId': listId,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': false,
    };

    _offlineChanges.add(change);
    _saveOfflineChanges();
    notifyListeners();

    print('Tracked offline change: $operation for list $listId');
  }

  // Sync all offline changes to webapp
  Future<Map<String, dynamic>> syncOfflineChanges() async {
    if (!_connectionManager.isWebappAvailable) {
      return {
        'success': false,
        'message': 'Webapp not available',
        'syncedCount': 0,
        'errors': ['No internet connection'],
      };
    }

    if (_offlineChanges.isEmpty) {
      return {
        'success': true,
        'message': 'No offline changes to sync',
        'syncedCount': 0,
        'errors': [],
      };
    }

    final errors = <String>[];
    int syncedCount = 0;

    print('Syncing ${_offlineChanges.length} offline changes...');

    for (final change in List.from(_offlineChanges)) {
      try {
        await _processOfflineChange(change);
        syncedCount++;
        _offlineChanges.remove(change);
        print('Successfully synced change: ${change['operation']}');
      } catch (e) {
        final errorMsg = 'Failed to sync ${change['operation']}: $e';
        errors.add(errorMsg);
        print(errorMsg);
      }
    }

    await _saveOfflineChanges();
    notifyListeners();

    return {
      'success': errors.isEmpty,
      'message': 'Synced $syncedCount changes${errors.isNotEmpty ? ' with ${errors.length} errors' : ''}',
      'syncedCount': syncedCount,
      'errors': errors,
    };
  }

  // Process a single offline change
  Future<void> _processOfflineChange(Map<String, dynamic> change) async {
    final operation = change['operation'] as String;
    final listId = change['listId'] as String;
    final data = change['data'] as Map<String, dynamic>;

    switch (operation) {
      case 'create':
        await _syncCreateList(listId, data);
        break;
      case 'update':
        await _syncUpdateList(listId, data);
        break;
      case 'delete':
        await _syncDeleteList(listId, data);
        break;
      case 'add_item':
        await _syncAddItem(listId, data);
        break;
      case 'update_item':
        await _syncUpdateItem(listId, data);
        break;
      case 'delete_item':
        await _syncDeleteItem(listId, data);
        break;
      default:
        throw Exception('Unknown operation: $operation');
    }
  }

  // Sync create list operation
  Future<void> _syncCreateList(String listId, Map<String, dynamic> data) async {
    final localList = _shoppingLists.firstWhere((list) => list.id == listId);
    final webList = await _webApiService.createShoppingList(localList.name);

    // Update local list with web ID
    final index = _shoppingLists.indexWhere((list) => list.id == listId);
    if (index != -1) {
      _shoppingLists[index] = localList.copyWith(
        webId: webList.webId,
        lastSynced: DateTime.now(),
        needsSync: false,
      );
      await _saveToStorage();
    }
  }

  // Sync update list operation
  Future<void> _syncUpdateList(String listId, Map<String, dynamic> data) async {
    final localList = _shoppingLists.firstWhere((list) => list.id == listId);
    if (localList.webId != null) {
      await _webApiService.updateShoppingList(localList);

      // Update last synced time
      final index = _shoppingLists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        _shoppingLists[index] = localList.copyWith(
          lastSynced: DateTime.now(),
          needsSync: false,
        );
        await _saveToStorage();
      }
    }
  }

  // Sync delete list operation
  Future<void> _syncDeleteList(String listId, Map<String, dynamic> data) async {
    final webId = data['webId'] as String?;
    if (webId != null) {
      await _webApiService.deleteShoppingList(webId);
    }
  }

  // Sync add item operation
  Future<void> _syncAddItem(String listId, Map<String, dynamic> data) async {
    final localList = _shoppingLists.firstWhere((list) => list.id == listId);
    if (localList.webId != null) {
      await _webApiService.updateShoppingListWithNewItem(localList.webId!, localList);

      // Update last synced time
      final index = _shoppingLists.indexWhere((list) => list.id == listId);
      if (index != -1) {
        _shoppingLists[index] = localList.copyWith(
          lastSynced: DateTime.now(),
          needsSync: false,
        );
        await _saveToStorage();
      }
    }
  }

  // Sync update item operation
  Future<void> _syncUpdateItem(String listId, Map<String, dynamic> data) async {
    await _syncAddItem(listId, data); // Same as add item for list-level updates
  }

  // Sync delete item operation
  Future<void> _syncDeleteItem(String listId, Map<String, dynamic> data) async {
    await _syncAddItem(listId, data); // Same as add item for list-level updates
  }

  // Force refresh from webapp (overwrites local changes)
  Future<Map<String, dynamic>> forceRefreshFromWebapp() async {
    if (!_connectionManager.isWebappAvailable) {
      return {
        'success': false,
        'message': 'Webapp not available',
        'error': 'No internet connection',
      };
    }

    try {
      // Force refreshing from webapp (this will overwrite local changes)

      // Clear offline changes since we're overwriting everything
      _offlineChanges.clear();
      await _saveOfflineChanges();

      // Refresh all data from webapp
      final result = await refreshFromWebapp();

      return {
        'success': true,
        'message': 'Successfully refreshed from webapp',
        'data': result,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to refresh from webapp',
        'error': e.toString(),
      };
    }
  }

  // Get sync status summary
  Map<String, dynamic> getDetailedSyncStatus() {
    return {
      'totalLists': _shoppingLists.length,
      'listsNeedingSync': _shoppingLists.where((list) => list.needsSync).length,
      'offlineChanges': _offlineChanges.length,
      'lastSync': _shoppingLists
          .where((list) => list.lastSynced != null)
          .map((list) => list.lastSynced!)
          .fold<DateTime?>(null, (a, b) => a?.isAfter(b) == true ? a : b),
      'hasOfflineChanges': _offlineChanges.isNotEmpty,
      'webappAvailable': _connectionManager.isWebappAvailable,
    };
  }
}

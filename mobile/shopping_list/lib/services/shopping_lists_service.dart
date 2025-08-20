import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shopping_list.dart';
import 'web_api_service.dart';
import 'connection_manager.dart';

class ShoppingListsService extends ChangeNotifier {
  List<ShoppingList> _shoppingLists = [];
  static const String _storageKey = 'shopping_lists';

  final WebApiService _webApiService = WebApiService();
  final ConnectionManager _connectionManager = ConnectionManager();

  List<ShoppingList> get shoppingLists => List.unmodifiable(_shoppingLists);

  List<ShoppingList> get activeLists =>
      _shoppingLists.where((list) => !list.isCompleted).toList();

  List<ShoppingList> get completedLists =>
      _shoppingLists.where((list) => list.isCompleted).toList();

  // Lists that need synchronization
  List<ShoppingList> get listsNeedingSync =>
      _shoppingLists.where((list) => list.needsSync).toList();

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
          print('Failed to sync new list with webapp: $e');
        }
      }
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

      // Try to sync with webapp if available
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
            print('Failed to sync updated list with webapp: $e');
          }
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

    // Try to sync deletion with webapp if available
    if (_connectionManager.isWebappAvailable && shoppingList.webId != null) {
      try {
        await _webApiService.deleteShoppingList(shoppingList.webId!);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to sync deletion with webapp: $e');
        }
      }
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
      final listsJson = prefs.getStringList(_storageKey) ?? [];

      _shoppingLists = listsJson
          .map((jsonString) => ShoppingList.fromJson(jsonDecode(jsonString)))
          .toList();

      // Sort lists: active first, then by creation date
      _shoppingLists.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading shopping lists: $e');
      }
    }
  }

  // Save shopping lists to storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listsJson = _shoppingLists
          .map((list) => jsonEncode(list.toJson()))
          .toList();
      await prefs.setStringList(_storageKey, listsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving shopping lists: $e');
      }
    }
  }

  // Sync with webapp
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

      // Sync with webapp
      final result = await _webApiService.syncWithWebapp(listsToSync);

      if (result['success']) {
        // Update local lists with synced data
        final syncedLists = result['synced_lists'] as List<ShoppingList>;
        for (final syncedList in syncedLists) {
          final index = _shoppingLists.indexWhere((list) =>
              list.webId == syncedList.webId || list.id == syncedList.id);
          if (index != -1) {
            _shoppingLists[index] = syncedList;
          }
        }

        await _saveToStorage();
        notifyListeners();

        return {
          'success': true,
          'message': 'Successfully synced ${syncedLists.length} lists',
          'synced_count': syncedLists.length,
          'conflicts': result['conflicts'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to sync with webapp',
          'synced_count': 0,
        };
      }
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
}

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shopping_item.dart';

class ShoppingListService extends ChangeNotifier {
  List<ShoppingItem> _items = [];
  static const String _storageKey = 'shopping_list_items';

  List<ShoppingItem> get items => List.unmodifiable(_items);

  List<ShoppingItem> get pendingItems =>
      _items.where((item) => !item.isCompleted).toList();

  List<ShoppingItem> get completedItems =>
      _items.where((item) => item.isCompleted).toList();

  // Add new item
  Future<void> addItem(String name, String quantity) async {
    final item = ShoppingItem(
      id: _generateId(),
      name: name.trim(),
      quantity: quantity.trim().isEmpty ? '1' : quantity.trim(),
    );

    _items.add(item);
    await _saveToStorage();
    notifyListeners();
  }

  // Update item
  Future<void> updateItem(ShoppingItem item) async {
    final index = _items.indexWhere((element) => element.id == item.id);
    if (index != -1) {
      _items[index] = item;
      await _saveToStorage();
      notifyListeners();
    }
  }

  // Toggle item completion
  Future<void> toggleItem(String id) async {
    final index = _items.indexWhere((element) => element.id == id);
    if (index != -1) {
      final item = _items[index];
      final updatedItem = item.copyWith(
        isCompleted: !item.isCompleted,
        completedAt: !item.isCompleted ? DateTime.now() : null,
      );
      _items[index] = updatedItem;
      await _saveToStorage();
      notifyListeners();
    }
  }

  // Delete item
  Future<void> deleteItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _saveToStorage();
    notifyListeners();
  }

  // Clear completed items
  Future<void> clearCompleted() async {
    _items.removeWhere((item) => item.isCompleted);
    await _saveToStorage();
    notifyListeners();
  }

  // Clear all items
  Future<void> clearAll() async {
    _items.clear();
    await _saveToStorage();
    notifyListeners();
  }

  // Load items from storage
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getStringList(_storageKey) ?? [];

      _items = itemsJson
          .map((jsonString) => ShoppingItem.fromJson(jsonDecode(jsonString)))
          .toList();

      // Sort items: pending first, then by creation date
      _items.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading shopping list: $e');
      }
    }
  }

  // Save items to storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = _items
          .map((item) => jsonEncode(item.toJson()))
          .toList();
      await prefs.setStringList(_storageKey, itemsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving shopping list: $e');
      }
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

  // Search items
  List<ShoppingItem> searchItems(String query) {
    if (query.trim().isEmpty) return _items;

    final lowercaseQuery = query.toLowerCase();
    return _items.where((item) {
      return item.name.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Get statistics
  Map<String, int> getStatistics() {
    final total = _items.length;
    final completed = _items.where((item) => item.isCompleted).length;
    final pending = total - completed;

    return {
      'total': total,
      'completed': completed,
      'pending': pending,
    };
  }
}

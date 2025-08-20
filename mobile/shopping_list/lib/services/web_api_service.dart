import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';

class WebApiService {
  static const String baseUrl = 'http://raspfofs/api'; // Your working URL

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Test connection to webapp
  Future<bool> testConnection() async {
    try {
      // Testing connection to health endpoint
      final response = await http.get(
        Uri.parse('$baseUrl/shopping-lists/health'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      // Health check response received

      return response.statusCode == 200;
    } catch (e) {
      // Connection test failed
      return false;
    }
  }

  // Fetch all shopping lists from webapp
  Future<List<ShoppingList>> fetchShoppingLists() async {
    try {
      // Fetching shopping lists from webapp
      final response = await http.get(
        Uri.parse('$baseUrl/shopping-lists'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      // Fetch response received

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Fetched shopping lists from webapp

        return data.map((json) => ShoppingList.fromWebJson(json)).toList();
      } else {
        throw Exception('Failed to fetch shopping lists: ${response.statusCode}');
      }
    } catch (e) {
      // Error fetching shopping lists
      throw Exception('Error fetching shopping lists: $e');
    }
  }

  // Create shopping list on webapp
  Future<ShoppingList> createShoppingList(String name) async {
    try {
      // Creating shopping list
      final response = await http.post(
        Uri.parse('$baseUrl/shopping-lists'),
        headers: headers,
        body: json.encode({'name': name}),
      ).timeout(const Duration(seconds: 10));

      // Create response received

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return ShoppingList.fromWebJson(data);
      } else {
        throw Exception('Failed to create shopping list: ${response.statusCode}');
      }
    } catch (e) {
      // Error creating shopping list
      throw Exception('Error creating shopping list: $e');
    }
  }

  // Update shopping list on webapp
  Future<ShoppingList> updateShoppingList(ShoppingList shoppingList) async {
    try {
      // Updating shopping list
      final response = await http.put(
        Uri.parse('$baseUrl/shopping-lists/${shoppingList.webId ?? shoppingList.id}'),
        headers: headers,
        body: json.encode({
          'name': shoppingList.name,
          'items': shoppingList.items.map((item) => item.toWebJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 10));

      // Update response received

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ShoppingList.fromWebJson(data);
      } else {
        throw Exception('Failed to update shopping list: ${response.statusCode}');
      }
    } catch (e) {
      // Error updating shopping list
      throw Exception('Error updating shopping list: $e');
    }
  }

  // Delete shopping list on webapp
  Future<void> deleteShoppingList(String webId) async {
    try {
      // Deleting shopping list
      final response = await http.delete(
        Uri.parse('$baseUrl/shopping-lists/$webId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      // Delete response received

      if (response.statusCode != 204) {
        throw Exception('Failed to delete shopping list: ${response.statusCode}');
      }
    } catch (e) {
      // Error deleting shopping list
      throw Exception('Error deleting shopping list: $e');
    }
  }

  // Sync local data with webapp
  Future<Map<String, dynamic>> syncWithWebapp(List<ShoppingList> localLists) async {
    try {
      // Syncing shopping lists with webapp
      final response = await http.post(
        Uri.parse('$baseUrl/shopping-lists/sync'),
        headers: headers,
        body: json.encode({
          'lists': localLists.map((list) => list.toWebJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 15));

      // Sync response received

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'synced_lists': (data['synced_lists'] as List)
              .map((json) => ShoppingList.fromWebJson(json))
              .toList(),
          'conflicts': data['conflicts'] ?? [],
        };
      } else {
        throw Exception('Failed to sync with webapp: ${response.statusCode}');
      }
    } catch (e) {
      // Error syncing with webapp
      throw Exception('Error syncing with webapp: $e');
    }
  }

  // Update shopping list with new item (using list update endpoint)
  Future<ShoppingList> updateShoppingListWithNewItem(String listWebId, ShoppingList updatedList) async {
    try {
      // Updating shopping list with items
      final response = await http.put(
        Uri.parse('$baseUrl/shopping-lists/$listWebId'),
        headers: headers,
        body: json.encode(updatedList.toWebJson()),
      ).timeout(const Duration(seconds: 10));

      // Update list with items response received

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ShoppingList.fromWebJson(data);
      } else {
        throw Exception('Failed to update list with items: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Error updating list with items
      throw Exception('Error updating list with items: $e');
    }
  }

  // Legacy method names for compatibility - now use list update approach
  Future<ShoppingItem> addItemToList(String listWebId, ShoppingItem item) async {
    throw Exception('Use updateShoppingListWithNewItem instead');
  }

  Future<ShoppingItem> updateItemInList(String listWebId, ShoppingItem item) async {
    throw Exception('Use updateShoppingListWithNewItem instead');
  }

  Future<void> deleteItemFromList(String listWebId, String itemWebId) async {
    throw Exception('Use updateShoppingListWithNewItem instead');
  }
}

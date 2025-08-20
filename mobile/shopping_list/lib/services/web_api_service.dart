import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';

class WebApiService {
  static const String baseUrl = 'http://raspfofs/api'; // Your specific URL

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Test connection to webapp
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Fetch all shopping lists from webapp
  Future<List<ShoppingList>> fetchShoppingLists() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shopping-lists'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ShoppingList.fromWebJson(json)).toList();
      } else {
        throw Exception('Failed to fetch shopping lists: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching shopping lists: $e');
    }
  }

  // Create shopping list on webapp
  Future<ShoppingList> createShoppingList(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shopping-lists'),
        headers: headers,
        body: json.encode({'name': name}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return ShoppingList.fromWebJson(data);
      } else {
        throw Exception('Failed to create shopping list: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating shopping list: $e');
    }
  }

  // Update shopping list on webapp
  Future<ShoppingList> updateShoppingList(ShoppingList shoppingList) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/shopping-lists/${shoppingList.webId ?? shoppingList.id}'),
        headers: headers,
        body: json.encode({
          'name': shoppingList.name,
          'items': shoppingList.items.map((item) => item.toWebJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ShoppingList.fromWebJson(data);
      } else {
        throw Exception('Failed to update shopping list: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating shopping list: $e');
    }
  }

  // Delete shopping list on webapp
  Future<void> deleteShoppingList(String webId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/shopping-lists/$webId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 204) {
        throw Exception('Failed to delete shopping list: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting shopping list: $e');
    }
  }

  // Sync local data with webapp
  Future<Map<String, dynamic>> syncWithWebapp(List<ShoppingList> localLists) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shopping-lists/sync'),
        headers: headers,
        body: json.encode({
          'lists': localLists.map((list) => list.toWebJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 15));

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
      throw Exception('Error syncing with webapp: $e');
    }
  }
}

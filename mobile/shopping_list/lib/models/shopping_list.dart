import 'shopping_item.dart';

class ShoppingList {
  String id;
  String name;
  DateTime createdAt;
  DateTime? updatedAt;
  List<ShoppingItem> items;
  String? webId; // ID from webapp for synchronization
  DateTime? lastSynced; // Last time synced with webapp
  bool needsSync; // Whether this list needs to be synced with webapp

  ShoppingList({
    required this.id,
    required this.name,
    DateTime? createdAt,
    this.updatedAt,
    List<ShoppingItem>? items,
    this.webId,
    this.lastSynced,
    this.needsSync = false,
  }) :
    createdAt = createdAt ?? DateTime.now(),
    items = items ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'webId': webId,
      'lastSynced': lastSynced?.toIso8601String(),
      'needsSync': needsSync,
    };
  }

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      items: (json['items'] as List<dynamic>?)
          ?.map((itemJson) => ShoppingItem.fromJson(itemJson))
          .toList() ?? [],
      webId: json['webId'],
      lastSynced: json['lastSynced'] != null
          ? DateTime.parse(json['lastSynced'])
          : null,
      needsSync: json['needsSync'] ?? false,
    );
  }

  // Convert to webapp JSON format
  Map<String, dynamic> toWebJson() {
    return {
      'name': name,
      'items': items.map((item) => item.toWebJson()).toList(),
    };
  }

  // Create from webapp JSON format
  factory ShoppingList.fromWebJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id']?.toString() ?? _generateId(),
      name: json['name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      items: (json['items'] as List<dynamic>?)
          ?.map((itemJson) => ShoppingItem.fromWebJson(itemJson))
          .toList() ?? [],
      webId: json['id']?.toString(),
      lastSynced: DateTime.now(),
      needsSync: false, // Fresh from webapp, no sync needed
    );
  }

  // Generate a temporary ID for local use
  static String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return String.fromCharCodes(
      Iterable.generate(8, (i) => chars.codeUnitAt(random % chars.length)),
    );
  }

  ShoppingList copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ShoppingItem>? items,
    String? webId,
    DateTime? lastSynced,
    bool? needsSync,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
      webId: webId ?? this.webId,
      lastSynced: lastSynced ?? this.lastSynced,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  // Get statistics for this shopping list
  Map<String, int> getStatistics() {
    final total = items.length;
    final completed = items.where((item) => item.isCompleted).length;
    final pending = total - completed;

    return {
      'total': total,
      'completed': completed,
      'pending': pending,
    };
  }

  // Get completion percentage
  double get completionPercentage {
    if (items.isEmpty) return 0.0;
    return (items.where((item) => item.isCompleted).length / items.length) * 100;
  }

  // Check if list is empty
  bool get isEmpty => items.isEmpty;

  // Check if list is completed
  bool get isCompleted => items.isNotEmpty && items.every((item) => item.isCompleted);

  // Check if list is synced with webapp
  bool get isSynced => webId != null && lastSynced != null;

}

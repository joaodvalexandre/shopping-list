enum ItemStatus { toBuy, inCart, purchased }

class ShoppingItem {
  String id;
  String name;
  String quantity;
  ItemStatus status;
  DateTime createdAt;
  DateTime? completedAt;
  DateTime? updatedAt;
  String? webId; // ID from webapp for synchronization

  ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.status = ItemStatus.toBuy,
    DateTime? createdAt,
    this.completedAt,
    this.updatedAt,
    this.webId,
  }) : createdAt = createdAt ?? DateTime.now();

  // Helper getters for status checks
  bool get isToBuy => status == ItemStatus.toBuy;
  bool get isInCart => status == ItemStatus.inCart;
  bool get isPurchased => status == ItemStatus.purchased;
  bool get isCompleted => status == ItemStatus.purchased; // For backwards compatibility

  // Convert status to string for webapp
  String get statusString {
    switch (status) {
      case ItemStatus.toBuy:
        return 'to_buy';
      case ItemStatus.inCart:
        return 'in_cart';
      case ItemStatus.purchased:
        return 'purchased';
    }
  }

  // Convert string to status
  static ItemStatus statusFromString(String statusString) {
    switch (statusString) {
      case 'to_buy':
        return ItemStatus.toBuy;
      case 'in_cart':
        return ItemStatus.inCart;
      case 'purchased':
        return ItemStatus.purchased;
      default:
        return ItemStatus.toBuy;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'status': statusString,
      'isCompleted': isCompleted, // For backwards compatibility
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'webId': webId,
    };
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'],
      name: json['name'],
      quantity: json['quantity'],
      status: json['status'] != null
          ? statusFromString(json['status'])
          : (json['isCompleted'] == true ? ItemStatus.purchased : ItemStatus.toBuy), // Backwards compatibility
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      webId: json['webId'],
    );
  }

  // Convert to webapp JSON format
  Map<String, dynamic> toWebJson() {
    return {
      'name': name,
      'quantity': quantity, // Keep as string as Laravel expects
      'status': statusString,
    };
  }

  // Create from webapp JSON format
  factory ShoppingItem.fromWebJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id']?.toString() ?? _generateId(),
      name: json['name'] ?? '',
      quantity: json['quantity']?.toString() ?? '1', // Convert int to string
      status: statusFromString(json['status'] ?? 'to_buy'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      completedAt: json['status'] == 'purchased' && json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      webId: json['id']?.toString(),
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

  ShoppingItem copyWith({
    String? id,
    String? name,
    String? quantity,
    ItemStatus? status,
    bool? isCompleted, // For backwards compatibility
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? updatedAt,
    String? webId,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      status: status ?? (isCompleted != null ? (isCompleted ? ItemStatus.purchased : ItemStatus.toBuy) : this.status),
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      webId: webId ?? this.webId,
    );
  }
}

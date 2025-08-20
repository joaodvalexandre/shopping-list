class ShoppingItem {
  String id;
  String name;
  String quantity;
  bool isCompleted;
  DateTime createdAt;
  DateTime? completedAt;
  String? webId; // ID from webapp for synchronization

  ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.isCompleted = false,
    DateTime? createdAt,
    this.completedAt,
    this.webId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'webId': webId,
    };
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'],
      name: json['name'],
      quantity: json['quantity'],
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      webId: json['webId'],
    );
  }

  // Convert to webapp JSON format
  Map<String, dynamic> toWebJson() {
    return {
      'name': name,
      'quantity': quantity,
      'status': isCompleted ? 'purchased' : 'to_buy',
    };
  }

  // Create from webapp JSON format
  factory ShoppingItem.fromWebJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id']?.toString() ?? _generateId(),
      name: json['name'],
      quantity: json['quantity'] ?? '1',
      isCompleted: json['status'] == 'purchased',
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
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    String? webId,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      webId: webId ?? this.webId,
    );
  }
}

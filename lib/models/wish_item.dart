class WishItem {
  final String id;
  final String title;
  final String description;
  final double price;
  final String imageUrl;
  final int priority;
  bool isPurchased;
  final DateTime createdAt;
  final String? addedBy; // Кто добавил (опционально)

  WishItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.priority,
    this.isPurchased = false,
    required this.createdAt,
    this.addedBy,
  });

  factory WishItem.createNew({
    required String title,
    required String description,
    required double price,
    required String imageUrl,
    required int priority,
    String? addedBy,
  }) {
    return WishItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      price: price,
      imageUrl: imageUrl,
      priority: priority,
      createdAt: DateTime.now(),
      addedBy: addedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'priority': priority,
      'isPurchased': isPurchased,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'addedBy': addedBy, // Сохраняем кто добавил
    };
  }

  factory WishItem.fromMap(Map<String, dynamic> map) {
    return WishItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      priority: map['priority'] ?? 1,
      isPurchased: map['isPurchased'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      addedBy: map['addedBy'],
    );
  }
}
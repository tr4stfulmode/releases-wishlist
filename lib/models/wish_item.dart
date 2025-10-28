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

  factory WishItem.fromMap(Map<String, dynamic> map, String id) {
    return WishItem(
      id: id,
      title: map['title'] as String,
      description: map['description'] as String,
      price: (map['price'] as num).toDouble(),
      imageUrl: map['imageUrl'] as String,
      priority: map['priority'] as int,
      isPurchased: map['isPurchased'] as bool? ?? false,
      addedBy: map['addedBy'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}
class SharedWishlist {
  final String id;
  final String wishlistId;
  final String sharedWithId;
  final String ownerId;
  final String shareToken;
  final DateTime sharedAt;
  final bool isActive;
  final String type; // 'shared' или 'personal'

  SharedWishlist({
    required this.id,
    required this.wishlistId,
    required this.sharedWithId,
    required this.ownerId,
    required this.shareToken,
    required this.sharedAt,
    required this.isActive,
    required this.type,
  });

  factory SharedWishlist.fromMap(Map<String, dynamic> map) {
    return SharedWishlist(
      id: map['id'] as String,
      wishlistId: map['wishlistId'] as String,
      sharedWithId: map['sharedWithId'] as String,
      sharedAt: DateTime.fromMillisecondsSinceEpoch(map['sharedAt'] as int),
      isActive: map['isActive'] as bool? ?? true, ownerId: '', shareToken: '', type: '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wishlistId': wishlistId,
      'sharedWithId': sharedWithId,
      'sharedAt': sharedAt.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }
}
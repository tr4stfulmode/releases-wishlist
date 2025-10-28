class SharedWishlist {
  final String id;
  final String ownerId;
  final String sharedWithId;
  final String shareToken;
  final DateTime sharedAt;
  final bool isActive;

  SharedWishlist({
    required this.id,
    required this.ownerId,
    required this.sharedWithId,
    required this.shareToken,
    required this.sharedAt,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'sharedWithId': sharedWithId,
      'shareToken': shareToken,
      'sharedAt': sharedAt.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  factory SharedWishlist.fromMap(Map<String, dynamic> map) {
    return SharedWishlist(
      id: map['id'],
      ownerId: map['ownerId'],
      sharedWithId: map['sharedWithId'],
      shareToken: map['shareToken'],
      sharedAt: DateTime.fromMillisecondsSinceEpoch(map['sharedAt']),
      isActive: map['isActive'],
    );
  }
}
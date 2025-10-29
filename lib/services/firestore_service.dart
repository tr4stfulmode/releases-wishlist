import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_wishlist/models/wish_item.dart';
import 'package:app_wishlist/models/user_profile.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Метод для получения текущего пользователя
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Добавление предмета
  Future<void> addWishItem(WishItem item) async {
    await _firestore.collection('wish_items').doc(item.id).set(item.toMap());
  }

  // Получение предметов текущего пользователя
  Stream<List<WishItem>> getWishItems() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('wish_items')
        .where('addedBy', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => WishItem.fromMap(doc.data()!, doc.id))
        .toList());
  }

  Future<void> togglePurchased(String itemId, bool isPurchased) async {
    await _firestore
        .collection('wish_items')
        .doc(itemId)
        .update({'isPurchased': isPurchased});
  }

  Future<void> deleteWishItem(String itemId) async {
    await _firestore.collection('wish_items').doc(itemId).delete();
  }

  // Профили пользователей
  Future<void> createUserProfile(UserProfile profile) async {
    await _firestore
        .collection('user_profiles')
        .doc(profile.uid)
        .set(profile.toMap());
  }

  Stream<UserProfile> getCurrentUserProfile() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('user_profiles')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        final newProfile = UserProfile(
          uid: user.uid,
          email: user.email ?? 'unknown@email.com',
          displayName: user.displayName ?? user.email?.split('@').first ?? 'Пользователь',
          createdAt: DateTime.now(),
          shareToken: DateTime.now().millisecondsSinceEpoch.toString(),
        );
        createUserProfile(newProfile);
        return newProfile;
      }
      return UserProfile.fromMap(snapshot.data()!);
    });
  }

  Future<UserProfile> getUserProfile(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('user_profiles')
          .doc(uid)
          .get();

      if (snapshot.exists) {
        return UserProfile.fromMap(snapshot.data()!);
      }

      // Если профиль не найден, создаем базовый
      final user = _auth.currentUser;
      final basicProfile = UserProfile(
        uid: uid,
        email: user?.email ?? 'unknown@email.com',
        displayName: 'Пользователь',
        createdAt: DateTime.now(),
        shareToken: 'default_$uid',
      );
      return basicProfile;
    } catch (e) {
      return UserProfile(
        uid: uid,
        email: 'error@email.com',
        displayName: 'Пользователь',
        createdAt: DateTime.now(),
        shareToken: 'error_$uid',
      );
    }
  }

  // Получение ID доступных вишлистов
  Stream<List<String>> getAccessibleWishlistIds() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('shared_wishlists')
        .where('sharedWithId', isEqualTo: currentUser.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final List<String> ownerIds = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('ownerId')) {
          ownerIds.add(data['ownerId'] as String);
        }
      }
      return ownerIds;
    });
  }

  // ОСНОВНОЙ МЕТОД: Получение общих вишлистов - УПРОЩЕННАЯ ВЕРСИЯ

  Stream<List<WishItem>> getSharedWishItems() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Сначала создаем запись о своем вишлисте если ее нет
    _ensureOwnWishlistExists(currentUser.uid);

    return _firestore
        .collection('shared_wishlists')
        .where('sharedWithId', isEqualTo: currentUser.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((sharedSnapshot) async {
      try {
        final sharedWishlists = sharedSnapshot.docs;
        final accessibleUserIds = <String>{currentUser.uid};

        for (final doc in sharedWishlists) {
          final data = doc.data();
          final ownerId = data['ownerId'] as String?;
          if (ownerId != null) {
            accessibleUserIds.add(ownerId);
          }
        }

        if (accessibleUserIds.isEmpty) {
          return <WishItem>[];
        }

        // Получаем предметы одним запросом
        final itemsSnapshot = await _firestore
            .collection('wish_items')
            .where('addedBy', whereIn: accessibleUserIds.toList())
            .orderBy('createdAt', descending: true)
            .get();

        return itemsSnapshot.docs
            .map((doc) => WishItem.fromMap(doc.data(), doc.id))
            .toList();
      } catch (e) {
        print('❌ Ошибка в getSharedWishItems: $e');
        return <WishItem>[];
      }
    });
  }

  // Автоматическое создание записи о своем вишлисте
  Future<void> _ensureOwnWishlistExists(String userId) async {
    try {
      final existingConnection = await _firestore
          .collection('shared_wishlists')
          .where('ownerId', isEqualTo: userId)
          .where('sharedWithId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (existingConnection.docs.isEmpty) {
        final ownWishlist = {
          'id': _firestore.collection('shared_wishlists').doc().id,
          'ownerId': userId,
          'sharedWithId': userId,
          'shareToken': 'self_$userId',
          'sharedAt': DateTime.now(),
          'isActive': true,
        };

        await _firestore
            .collection('shared_wishlists')
            .doc(ownWishlist['id'] as String)
            .set(ownWishlist);
      }
    } catch (e) {
      print('Ошибка создания собственного вишлиста: $e');
    }
  }

  // Получение всех предметов (для отладки)
  Stream<List<WishItem>> getAllWishItems() {
    return _firestore
        .collection('wish_items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => WishItem.fromMap(doc.data()!, doc.id))
        .toList());
  }

  // Получение пользователей, которые имеют доступ к моему вишлисту
  Stream<List<UserProfile>> getSharedWithUsers() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('shared_wishlists')
        .where('ownerId', isEqualTo: currentUser.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final userIds = snapshot.docs
          .map((doc) => doc.data()['sharedWithId'] as String)
          .where((id) => id != currentUser.uid)
          .toList();

      if (userIds.isEmpty) return <UserProfile>[];

      final profilesSnapshot = await _firestore
          .collection('user_profiles')
          .where('uid', whereIn: userIds)
          .get();

      return profilesSnapshot.docs
          .map((doc) => UserProfile.fromMap(doc.data()))
          .toList();
    });
  }
}
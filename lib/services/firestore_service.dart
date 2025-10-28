import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_wishlist/models/wish_item.dart';
import 'package:app_wishlist/models/user_profile.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Существующие методы для WishItem
  Future<void> addWishItem(WishItem item) async {
    await _firestore.collection('wish_items').doc(item.id).set(item.toMap());
  }

  Stream<List<WishItem>> getWishItems() {
    return _firestore
        .collection('wish_items')
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

  // Методы для UserProfile
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
      final data = snapshot.data();
      if (data == null) {
        throw Exception('Профиль пользователя не найден');
      }
      return UserProfile.fromMap(data);
    });
  }

  Future<UserProfile> getUserProfile(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('user_profiles')
          .doc(uid)
          .get();

      if (snapshot.exists && snapshot.data() != null) {
        return UserProfile.fromMap(snapshot.data()!);
      }
      throw Exception('Профиль пользователя не найден');
    } catch (e) {
      print('Ошибка получения профиля: $e');
      throw Exception('Не удалось загрузить профиль пользователя');
    }
  }

  // НОВЫЙ МЕТОД: Получение ID доступных вишлистов
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

  // НОВЫЙ МЕТОД: Получение вишлистов с учетом shared доступов
  Stream<List<WishItem>> getWishItemsWithAccess() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return getAccessibleWishlistIds().asyncExpand((accessibleIds) {
      // Добавляем ID текущего пользователя + доступные вишлисты
      final userIds = {currentUser.uid, ...accessibleIds};

      if (userIds.isEmpty) return const Stream.empty();

      // Получаем предметы всех доступных пользователей
      return _firestore
          .collection('wish_items')
          .where('addedBy', whereIn: userIds.toList())
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => WishItem.fromMap(doc.data()!, doc.id))
          .toList());
    });
  }

  // Дополнительные методы для работы с shared вишлистами
  Future<List<String>> getSharedWithUserIds() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      final snapshot = await _firestore
          .collection('shared_wishlists')
          .where('ownerId', isEqualTo: currentUser.uid)
          .where('isActive', isEqualTo: true)
          .get();

      final List<String> userIds = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('sharedWithId')) {
          userIds.add(data['sharedWithId'] as String);
        }
      }
      return userIds;
    } catch (e) {
      print('Ошибка получения shared пользователей: $e');
      return [];
    }
  }

  // Получение всех пользователей, которые имеют доступ к моему вишлисту
  Stream<List<UserProfile>> getSharedWithUsers() {
    return Stream.fromFuture(getSharedWithUserIds()).asyncExpand((userIds) {
      if (userIds.isEmpty) return const Stream.empty();

      return _firestore
          .collection('user_profiles')
          .where('uid', whereIn: userIds)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => UserProfile.fromMap(doc.data()))
          .toList());
    });
  }

  // Простой метод для получения всех вишлистов (без фильтрации по доступу)
  Stream<List<WishItem>> getAllWishItems() {
    return _firestore
        .collection('wish_items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => WishItem.fromMap(doc.data()!, doc.id))
        .toList());
  }
}
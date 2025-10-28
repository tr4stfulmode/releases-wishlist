import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_wishlist/models/shared_wishlist.dart';
import 'package:app_wishlist/models/user_profile.dart';

class ShareService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Генерация ссылки для приглашения
  String generateShareLink(String shareToken) {
    return 'https://yourapp.com/wishlist/$shareToken';
  }

  // Получение профиля пользователя по токену
  Future<UserProfile?> getUserByToken(String shareToken) async {
    try {
      final snapshot = await _firestore
          .collection('user_profiles')
          .where('shareToken', isEqualTo: shareToken)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return UserProfile.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Ошибка поиска пользователя: $e');
      return null;
    }
  }

  // Подключение к чужому вишлисту
  Future<void> connectToWishlist(String shareToken) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Пользователь не авторизован');

      final userProfile = await getUserByToken(shareToken);
      if (userProfile == null) throw Exception('Вишлист не найден');

      // Проверяем, не подключены ли уже
      final existingConnection = await _firestore
          .collection('shared_wishlists')
          .where('sharedWithId', isEqualTo: currentUser.uid)
          .where('ownerId', isEqualTo: userProfile.uid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (existingConnection.docs.isNotEmpty) {
        throw Exception('Вы уже подключены к этому вишлисту');
      }

      // Создаем запись о shared вишлисте
      final sharedWishlist = SharedWishlist(
        id: _firestore.collection('shared_wishlists').doc().id,
        ownerId: userProfile.uid,
        sharedWithId: currentUser.uid,
        shareToken: shareToken,
        sharedAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection('shared_wishlists')
          .doc(sharedWishlist.id)
          .set(sharedWishlist.toMap());

    } catch (e) {
      print('Ошибка подключения: $e');
      rethrow;
    }
  }

  // Получение всех shared вишлистов пользователя
  Stream<List<SharedWishlist>> getSharedWishlists() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('shared_wishlists')
        .where('sharedWithId', isEqualTo: currentUser.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => SharedWishlist.fromMap(doc.data()))
        .toList());
  }

  // Отключение от shared вишлиста
  Future<void> disconnectFromWishlist(String sharedWishlistId) async {
    await _firestore
        .collection('shared_wishlists')
        .doc(sharedWishlistId)
        .update({'isActive': false});
  }

  // Получение вишлистов, к которым пользователь имеет доступ
  Stream<List<String>> getAccessibleWishlistIds() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('shared_wishlists')
        .where('sharedWithId', isEqualTo: currentUser.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => doc.data()['ownerId'] as String)
        .toList());
  }
}
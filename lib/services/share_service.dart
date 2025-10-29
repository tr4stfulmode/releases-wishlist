import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_wishlist/models/shared_wishlist.dart';
import 'package:app_wishlist/models/user_profile.dart';

class ShareService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Получение собственного shareToken
  Future<String> getMyShareToken() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Пользователь не авторизован');

    try {
      final snapshot = await _firestore
          .collection('user_profiles')
          .doc(currentUser.uid)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        return data['shareToken'] as String;
      }

      // Если профиль не существует, создаем его
      final newProfile = UserProfile(
        uid: currentUser.uid,
        email: currentUser.email ?? 'unknown@email.com',
        displayName: currentUser.displayName ?? currentUser.email?.split('@').first ?? 'Пользователь',
        createdAt: DateTime.now(),
        shareToken: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      await _firestore
          .collection('user_profiles')
          .doc(currentUser.uid)
          .set(newProfile.toMap());

      return newProfile.shareToken;
    } catch (e) {
      print('❌ Ошибка получения shareToken: $e');
      throw Exception('Не удалось получить ссылку для приглашения');
    }
  }

  // Генерация ссылки для текущего пользователя
  Future<String> generateMyShareLink() async {
    final token = await getMyShareToken();
    return generateShareLink(token);
  }

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
      print('❌ Ошибка поиска пользователя по токену: $e');
      return null;
    }
  }

  Future<void> connectToWishlist(String shareToken) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Пользователь не авторизован');

      final userProfile = await getUserByToken(shareToken);
      if (userProfile == null) throw Exception('Вишлист не найден');

      // Проверяем, не подключаемся ли к себе
      if (userProfile.uid == currentUser.uid) {
        throw Exception('Нельзя подключиться к собственному вишлисту');
      }

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

      print('✅ Успешно подключен к вишлисту пользователя: ${userProfile.uid}');

    } catch (e) {
      print('❌ Ошибка подключения к вишлисту: $e');
      rethrow;
    }
  }

  // Получение всех shared вишлистов пользователя - УПРОЩЕННАЯ ВЕРСИЯ
  Stream<List<SharedWishlist>> getSharedWishlists() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('shared_wishlists')
        .where('sharedWithId', isEqualTo: currentUser.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => SharedWishlist.fromMap(doc.data()))
            .toList();
      } catch (e) {
        print('❌ Ошибка преобразования SharedWishlist: $e');
        return <SharedWishlist>[];
      }
    });
  }

  // Отключение от shared вишлиста
  Future<void> disconnectFromWishlist(String sharedWishlistId) async {
    try {
      await _firestore
          .collection('shared_wishlists')
          .doc(sharedWishlistId)
          .update({'isActive': false});
      print('✅ Успешно отключен от вишлиста: $sharedWishlistId');
    } catch (e) {
      print('❌ Ошибка отключения от вишлиста: $e');
      rethrow;
    }
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
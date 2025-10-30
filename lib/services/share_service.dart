import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_wishlist/models/shared_wishlist.dart';

class ShareService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Константа для общего вишлиста
  static const String _sharedWishlistId = 'main_shared_wishlist';
  static const String _shareToken = 'main_shared_wishlist_token';

  // Генерация ОДНОЙ общей ссылки
  String generateSharedLink() {
    return 'https://yourapp.com/wishlist/$_shareToken';
  }

  // Получить персональную ссылку пользователя
  Future<String?> getPersonalShareLink() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final snapshot = await _firestore
          .collection('personal_share_links')
          .doc(currentUser.uid)
          .get();

      if (snapshot.exists) {
        return snapshot.data()?['shareLink'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения персональной ссылки: $e');
      return null;
    }
  }

  // Сгенерировать уникальную персональную ссылку
  Future<void> generatePersonalShareLink() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Пользователь не авторизован');

      final personalToken = 'personal_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final personalShareLink = 'https://yourapp.com/wishlist/$personalToken';

      await _firestore
          .collection('personal_share_links')
          .doc(currentUser.uid)
          .set({
        'shareLink': personalShareLink,
        'token': personalToken,
        'createdAt': FieldValue.serverTimestamp(),
        'ownerId': currentUser.uid,
      });

      print('✅ Персональная ссылка создана: $personalShareLink');
    } catch (e) {
      print('❌ Ошибка создания персональной ссылки: $e');
      rethrow;
    }
  }

  // Подключиться по ссылке
  Future<void> connectByShareLink(String shareLink) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Пользователь не авторизован');

      // Извлекаем токен из ссылки
      final uri = Uri.parse(shareLink);
      final segments = uri.pathSegments;
      if (segments.length < 2) throw Exception('Неверный формат ссылки');

      final token = segments.last;

      // Проверяем тип ссылки
      if (token == _shareToken) {
        // Это общая ссылка
        await connectToSharedWishlist();
      } else if (token.startsWith('personal_')) {
        // Это персональная ссылка
        await _connectToPersonalWishlist(token, currentUser.uid);
      } else {
        throw Exception('Неизвестный тип ссылки');
      }
    } catch (e) {
      print('❌ Ошибка подключения по ссылке: $e');
      rethrow;
    }
  }

  // Подключиться к персональному вишлисту
  Future<void> _connectToPersonalWishlist(String token, String currentUserId) async {
    try {
      // Находим владельца по токену
      final snapshot = await _firestore
          .collection('personal_share_links')
          .where('token', isEqualTo: token)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Ссылка недействительна или удалена');
      }

      final ownerData = snapshot.docs.first.data();
      final ownerId = ownerData['ownerId'] as String;

      if (ownerId == currentUserId) {
        throw Exception('Нельзя подключиться к своему собственному вишлисту');
      }

      // Проверяем, не подключен ли уже
      final existingConnection = await _firestore
          .collection('shared_wishlists')
          .where('sharedWithId', isEqualTo: currentUserId)
          .where('ownerId', isEqualTo: ownerId)
          .where('type', isEqualTo: 'personal')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (existingConnection.docs.isNotEmpty) {
        throw Exception('Вы уже подключены к этому вишлисту');
      }

      // Создаем подключение
      final personalWishlist = SharedWishlist(
        id: 'personal_${ownerId}_$currentUserId',
        wishlistId: 'personal_$ownerId',
        sharedWithId: currentUserId,
        ownerId: ownerId,
        shareToken: token,
        sharedAt: DateTime.now(),
        isActive: true,
        type: 'personal',
      );

      await _firestore
          .collection('shared_wishlists')
          .doc(personalWishlist.id)
          .set(personalWishlist.toMap());

      print('✅ Подключено к персональному вишлисту пользователя $ownerId');
    } catch (e) {
      print('❌ Ошибка подключения к персональному вишлисту: $e');
      rethrow;
    }
  }

  // Проверить подключение к общему вишлисту
  Future<bool> isUserConnectedToShared() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final snapshot = await _firestore
          .collection('shared_wishlists')
          .where('sharedWithId', isEqualTo: currentUser.uid)
          .where('wishlistId', isEqualTo: _sharedWishlistId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Ошибка проверки подключения к общему вишлисту: $e');
      return false;
    }
  }

  // Получить все подключенные вишлисты
  Stream<List<SharedWishlist>> getConnectedWishlists() {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return Stream.value([]);
      }

      return _firestore
          .collection('shared_wishlists')
          .where('sharedWithId', isEqualTo: currentUser.uid)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => SharedWishlist.fromMap(doc.data()))
            .toList();
      });
    } catch (e) {
      print('❌ Ошибка получения подключенных вишлистов: $e');
      return Stream.value([]);
    }
  }

  // Подключение к общему вишлисту
  Future<void> connectToSharedWishlist() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Пользователь не авторизован');

      // Проверяем, не подключен ли уже пользователь
      final existingConnection = await _firestore
          .collection('shared_wishlists')
          .where('sharedWithId', isEqualTo: currentUser.uid)
          .where('wishlistId', isEqualTo: _sharedWishlistId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (existingConnection.docs.isNotEmpty) {
        throw Exception('Вы уже подключены к общему вишлисту');
      }

      // Создаем запись о подключении
      final sharedWishlist = SharedWishlist(
        id: '${_sharedWishlistId}_${currentUser.uid}',
        wishlistId: _sharedWishlistId,
        sharedWithId: currentUser.uid,
        ownerId: 'system', // Владелец общего вишлиста - система
        shareToken: _shareToken,
        sharedAt: DateTime.now(),
        isActive: true,
        type: 'shared',
      );

      await _firestore
          .collection('shared_wishlists')
          .doc(sharedWishlist.id)
          .set(sharedWishlist.toMap());

      print('✅ Пользователь подключен к общему вишлисту');

    } catch (e) {
      print('❌ Ошибка подключения к общему вишлисту: $e');
      rethrow;
    }
  }

  // Получение всех пользователей, подключенных к общему вишлисту
  Stream<List<SharedWishlist>> getSharedWishlists() {
    try {
      return _firestore
          .collection('shared_wishlists')
          .where('wishlistId', isEqualTo: _sharedWishlistId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => SharedWishlist.fromMap(doc.data()))
            .toList();
      });
    } catch (e) {
      print('❌ Ошибка преобразования SharedWishlist: $e');
      return Stream.value(<SharedWishlist>[]);
    }
  }

  // Получение ID всех пользователей в общем вишлисте
  Stream<List<String>> getAccessibleUserIds() {
    try {
      return _firestore
          .collection('shared_wishlists')
          .where('wishlistId', isEqualTo: _sharedWishlistId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => doc.data()['sharedWithId'] as String)
          .toList());
    } catch (e) {
      print('❌ Ошибка получения доступных пользователей: $e');
      return Stream.value(<String>[]);
    }
  }

  // Отключение от вишлиста
  Future<void> disconnectFromWishlist(String wishlistId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('shared_wishlists')
          .doc(wishlistId)
          .update({'isActive': false});

      print('✅ Пользователь отключен от вишлиста');
    } catch (e) {
      print('❌ Ошибка отключения от вишлиста: $e');
      rethrow;
    }
  }

  // Проверка, подключен ли пользователь к общему вишлисту
  Future<bool> isUserConnected() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final snapshot = await _firestore
          .collection('shared_wishlists')
          .where('sharedWithId', isEqualTo: currentUser.uid)
          .where('wishlistId', isEqualTo: _sharedWishlistId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Ошибка проверки подключения: $e');
      return false;
    }
  }
}
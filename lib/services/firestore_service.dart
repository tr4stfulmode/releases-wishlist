import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_wishlist/models/wish_item.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _wishlistCollection {
    return _firestore.collection('wishlist');
  }

  // Добавить предмет в вишлист
  Future<void> addWishItem(WishItem item) async {
    try {
      await _wishlistCollection.doc(item.id).set(item.toMap());
      print('Предмет добавлен: ${item.title}');
    } catch (e) {
      throw Exception('Ошибка добавления: $e');
    }
  }

  // Получить все предметы
  Stream<List<WishItem>> getWishItems() {
    return _wishlistCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return WishItem.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Обновить статус покупки
  Future<void> togglePurchased(String itemId, bool isPurchased) async {
    try {
      await _wishlistCollection.doc(itemId).update({
        'isPurchased': isPurchased,
      });
    } catch (e) {
      throw Exception('Ошибка обновления: $e');
    }
  }

  // Удалить предмет
  Future<void> deleteWishItem(String itemId) async {
    try {
      await _wishlistCollection.doc(itemId).delete();
    } catch (e) {
      throw Exception('Ошибка удаления: $e');
    }
  }
}
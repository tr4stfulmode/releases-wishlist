import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_wishlist/models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Регистрация с созданием профиля
  Future<User> createUserWithEmailAndPassword(
      String email,
      String password,
      ) async {
    try {
      // Создаем пользователя в Firebase Auth
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User user = result.user!;

      // Создаем профиль пользователя
      final profile = UserProfile(
        uid: user.uid,
        email: email,
        displayName: email.split('@').first, // Используем часть email как имя
        createdAt: DateTime.now(),
        shareToken: _generateShareToken(user.uid),
      );

      await _firestore
          .collection('user_profiles')
          .doc(user.uid)
          .set(profile.toMap());

      return user;
    } catch (e) {
      print('Ошибка регистрации: $e');
      rethrow;
    }
  }

  // Вход
  Future<User> signInWithEmailAndPassword(
      String email,
      String password,
      ) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user!;
    } catch (e) {
      print('Ошибка входа: $e');
      rethrow;
    }
  }

  // Выход
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Генерация уникального токена для ссылки
  String _generateShareToken(String uid) {
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${uid.substring(0, 8)}';
  }

  // Получение текущего пользователя
  User? get currentUser => _auth.currentUser;

  // Слушатель состояния аутентификации
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
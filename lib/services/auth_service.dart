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
      print('🔄 Начинаем регистрацию пользователя: $email');

      // Создаем пользователя в Firebase Auth
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User user = result.user!;
      print('✅ Пользователь создан в Auth: ${user.uid}');

      // Создаем профиль пользователя в Firestore
      final profile = UserProfile(
        uid: user.uid,
        email: email,
        displayName: _getDisplayNameFromEmail(email),
        createdAt: DateTime.now(),
        shareToken: _generateShareToken(user.uid),
      );

      print('🔄 Создаем профиль в Firestore...');
      await _createUserProfile(profile);
      print('✅ Профиль создан успешно!');

      return user;

    } on FirebaseAuthException catch (e) {
      print('❌ Ошибка Firebase Auth: ${e.code} - ${e.message}');
      rethrow;
    } on FirebaseException catch (e) {
      print('❌ Ошибка Firestore: ${e.code} - ${e.message}');
      throw Exception('Ошибка базы данных: ${e.message}');
    } catch (e) {
      print('❌ Неизвестная ошибка: $e');
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

      final User user = result.user!;

      // Проверяем, есть ли профиль пользователя
      await _ensureUserProfileExists(user);

      return user;
    } catch (e) {
      print('Ошибка входа: $e');
      rethrow;
    }
  }

  // Создание профиля пользователя
  Future<void> _createUserProfile(UserProfile profile) async {
    try {
      await _firestore
          .collection('user_profiles')
          .doc(profile.uid)
          .set(profile.toMap());
      print('📝 Профиль создан для: ${profile.email}');
    } catch (e) {
      print('❌ Ошибка создания профиля: $e');
      rethrow;
    }
  }

  // Проверка и создание профиля если его нет
  Future<void> _ensureUserProfileExists(User user) async {
    try {
      final profileDoc = await _firestore
          .collection('user_profiles')
          .doc(user.uid)
          .get();

      if (!profileDoc.exists) {
        print('⚠️ Профиль не найден, создаем...');

        final profile = UserProfile(
          uid: user.uid,
          email: user.email!,
          displayName: _getDisplayNameFromEmail(user.email!),
          createdAt: DateTime.now(),
          shareToken: _generateShareToken(user.uid),
        );

        await _createUserProfile(profile);
        print('✅ Профиль создан для существующего пользователя');
      } else {
        print('✅ Профиль найден');
      }
    } catch (e) {
      print('❌ Ошибка проверки профиля: $e');
    }
  }

  // Получение имени из email
  String _getDisplayNameFromEmail(String email) {
    return email.split('@').first;
  }

  // Генерация уникального токена для ссылки
  String _generateShareToken(String uid) {
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${uid.substring(0, 8)}';
  }

  // Выход
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Получение текущего пользователя
  User? get currentUser => _auth.currentUser;

  // Слушатель состояния аутентификации
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
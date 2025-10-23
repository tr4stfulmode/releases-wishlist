import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static bool _isInitialized = false;

  // Инициализация уведомлений
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Инициализация Firebase
      await Firebase.initializeApp();

      // Настройка для Android
      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      // Настройка для iOS
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Обработка нажатия на уведомление
          _onNotificationTap(response.payload);
        },
      );

      // Создаем канал для уведомлений (Android)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'wishlist_channel',
        'Wishlist Updates',
        description: 'Notifications for new wishlist items',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Настройка FCM
      await _setupFCM();

      print('Уведомления инициализированы');
      _isInitialized = true;
    } catch (e) {
      print('Ошибка инициализации уведомлений: $e');
    }
  }

  // Настройка Firebase Cloud Messaging
  static Future<void> _setupFCM() async {
    try {
      // Запрос разрешений
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('Разрешения на уведомления: ${settings.authorizationStatus}');

      // Получение FCM токена
      String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      // Обработка фоновых сообщений
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);

      // Обработка сообщений когда приложение в foreground
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Обработка сообщений когда приложение в background но открыто
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    } catch (e) {
      print('Ошибка настройки FCM: $e');
    }
  }

  // Обработчик фоновых сообщений (должен быть статической функцией)
  @pragma('vm:entry-point')
  static Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
    await Firebase.initializeApp();

    print("Обработка фонового сообщения: ${message.messageId}");

    // Показываем локальное уведомление
    if (message.notification != null) {
      await _showNotificationFromFCM(message);
    }
  }

  // Обработка сообщений в foreground
  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    print("Получено сообщение в foreground: ${message.messageId}");

    if (message.notification != null) {
      await _showNotificationFromFCM(message);
    }
  }

  // Обработка открытия уведомления когда приложение в background
  static Future<void> _onMessageOpenedApp(RemoteMessage message) async {
    print("Уведомление открыто из background: ${message.messageId}");
    _handleNotificationTap(message.data);
  }

  // Показать уведомление из FCM
  static Future<void> _showNotificationFromFCM(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    String title = notification?.title ?? '🎁 Новый предмет в вишлисте!';
    String body = notification?.body ?? data['body'] ?? 'Новое обновление';
    String addedBy = data['addedBy'] ?? 'Пользователь';
    String itemTitle = data['itemTitle'] ?? 'новый предмет';

    await showNewItemNotification(itemTitle, addedBy, data: data);
  }

  // Обработка нажатия на уведомление
  static void _onNotificationTap(String? payload) {
    print('Уведомление нажато: $payload');
    // Здесь можно добавить навигацию к конкретному экрану
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    print('Обработка данных уведомления: $data');
    // Обработка данных при открытии уведомления
  }

  // Обновленный метод показа уведомления
  static Future<void> showNewItemNotification(
      String itemTitle,
      String addedBy, {
        Map<String, dynamic>? data,
      }) async {
    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'wishlist_channel',
        'Wishlist Updates',
        channelDescription: 'Notifications for new wishlist items',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        autoCancel: true,
        channelShowBadge: true,
        styleInformation: BigTextStyleInformation(
          '$addedBy добавил(а): "$itemTitle"',
          contentTitle: '🎁 Новый предмет в вишлисте!',
        ),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🎁 Новый предмет в вишлисте!',
        '$addedBy добавил(а): "$itemTitle"',
        details,
      );

      print('Уведомление показано: $itemTitle от $addedBy');
    } catch (e) {
      print('Ошибка показа уведомления: $e');
    }
  }

  // Получить FCM токен для отправки с сервера
  static Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('Ошибка получения FCM токена: $e');
      return null;
    }
  }

  // Подписка на топики (опционально)
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Подписались на топик: $topic');
    } catch (e) {
      print('Ошибка подписки на топик: $e');
    }
  }

  // Отписка от топиков
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Отписались от топика: $topic');
    } catch (e) {
      print('Ошибка отписки от топика: $e');
    }
  }

  // Проверить разрешения на уведомления
  static Future<bool> requestPermissions() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      print('Ошибка запроса разрешений: $e');
      return false;
    }
  }
}
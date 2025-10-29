import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Добавьте этот импорт
import 'package:app_wishlist/services/share_service.dart';
import 'package:app_wishlist/services/firestore_service.dart';
import 'package:app_wishlist/models/shared_wishlist.dart';
import 'package:app_wishlist/models/user_profile.dart';
import 'package:clipboard/clipboard.dart';

class WishlistManagerPage extends StatefulWidget {
  const WishlistManagerPage({super.key});

  @override
  State<WishlistManagerPage> createState() => _WishlistManagerPageState();
}

class _WishlistManagerPageState extends State<WishlistManagerPage> {
  final ShareService _shareService = ShareService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance; // Добавьте эту строку
  final TextEditingController _linkController = TextEditingController();
  bool _isConnecting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Управление вишлистами',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: Column(
        children: [
          // Секция "Мой вишлист"
          _buildMyWishlistSection(),

          // Секция "Подключиться по ссылке"
          _buildConnectSection(),

          // Секция "Доступные вишлисты"
          _buildSharedWishlistsSection(),
        ],
      ),
    );
  }

  Widget _buildMyWishlistSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.link, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  'МОЯ ССЫЛКА ДЛЯ ПРИГЛАШЕНИЯ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<String>(
              future: _shareService.generateMyShareLink(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Ошибка: ${snapshot.error}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasData) {
                  final shareLink = snapshot.data!;

                  return Column(
                    children: [
                      // Ссылка в красивом контейнере
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Ваша персональная ссылка:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _showFullLinkDialog(context, shareLink),
                              child: Text(
                                shareLink,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Poppins',
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Нажмите чтобы увидеть полностью',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Кнопки действий
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _copyToClipboard(context, shareLink),
                              icon: const Icon(Icons.copy, size: 20),
                              label: const Text(
                                'КОПИРОВАТЬ',
                                style: TextStyle(fontFamily: 'Poppins'),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _shareLink(shareLink),
                              icon: const Icon(Icons.share, size: 20),
                              label: const Text(
                                'ПОДЕЛИТЬСЯ',
                                style: TextStyle(fontFamily: 'Poppins'),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Подсказка
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Отправьте эту ссылку друзьям, чтобы они могли видеть ваш вишлист и добавлять свои желания! 🎁',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            height: 1.4,
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  );
                }

                return const Text(
                  'Данные не найдены',
                  style: TextStyle(fontFamily: 'Poppins'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedWishlistsSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8, left: 8),
              child: Text(
                'ПОДКЛЮЧЕННЫЕ ВИШЛИСТЫ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<SharedWishlist>>(
                stream: _shareService.getSharedWishlists(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    print('❌ Ошибка загрузки shared wishlists: ${snapshot.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 50, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Ошибка загрузки подключенных вишлистов',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text(
                              'Попробовать снова',
                              style: TextStyle(fontFamily: 'Poppins'),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final sharedWishlists = snapshot.data ?? [];
                  final currentUser = _auth.currentUser; // Используем _auth

                  // Фильтруем только чужие вишлисты (не свои)
                  final otherWishlists = sharedWishlists.where((wishlist) {
                    return wishlist.ownerId != currentUser?.uid;
                  }).toList();

                  if (otherWishlists.isNotEmpty) {
                    return ListView.builder(
                      itemCount: otherWishlists.length,
                      itemBuilder: (context, index) {
                        final sharedWishlist = otherWishlists[index];
                        return _buildSharedWishlistCard(sharedWishlist);
                      },
                    );
                  }

                  // Пустой список
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Нет подключенных вишлистов',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Подключитесь к вишлистам друзей с помощью ссылок-приглашений',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.add_link, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'ПОДКЛЮЧИТЬСЯ К ВИШЛИСТУ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Вставьте ссылку приглашения от друга',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                hintText: 'https://yourapp.com/wishlist/abc123...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.link),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isConnecting ? null : _connectToWishlist,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isConnecting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'ПОДКЛЮЧИТЬСЯ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedWishlistCard(SharedWishlist sharedWishlist) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: FutureBuilder<UserProfile>(
        future: _firestoreService.getUserProfile(sharedWishlist.ownerId),
        builder: (context, snapshot) {
          final isLoaded = snapshot.connectionState == ConnectionState.done && snapshot.hasData;
          final owner = snapshot.data;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: isLoaded && owner != null
                  ? Text(
                owner.displayName.isNotEmpty
                    ? owner.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.blue),
              )
                  : const CircularProgressIndicator(),
            ),
            title: Text(
              isLoaded && owner != null ? owner.displayName : 'Загрузка...',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
            subtitle: Text(
              isLoaded && owner != null ? owner.email : 'ID: ${sharedWishlist.ownerId}',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () => _disconnectWishlist(sharedWishlist.id),
              tooltip: 'Отключиться от вишлиста',
            ),
          );
        },
      ),
    );
  }

  // ========== ФУНКЦИОНАЛЬНЫЕ МЕТОДЫ ==========

  Future<void> _shareLink(String link) async {
    try {
      final text = '''
Привет! 👋

Присоединяйся к моему вишлисту! Ты сможешь:
🎁 Видеть мои желания
➕ Добавлять свои желания
👀 Следить за обновлениями

Перейди по ссылке: $link

Будем собирать вишлист вместе! ✨''';

      await Share.share(
        text,
        subject: 'Приглашение в мой вишлист 🎁',
      );
    } catch (e) {
      // Если шеринг не работает, показываем диалог с ссылкой
      _showShareDialogWithLink(link);
    }
  }

  void _showShareDialogWithLink(String link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.share, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Поделиться ссылкой',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Скопируйте ссылку и отправьте друзьям:',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Закрыть',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard(context, link);
              Navigator.pop(context);
            },
            child: const Text(
              'Копировать ссылку',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullLinkDialog(BuildContext context, String link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Полная ссылка',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ваша ссылка для приглашения:',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Закрыть',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard(context, link);
              Navigator.pop(context);
            },
            child: const Text(
              'Копировать',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Ссылка скопирована в буфер обмена! 📋',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка копирования: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _connectToWishlist() async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      final url = _linkController.text.trim();
      if (url.isEmpty) {
        throw Exception('Введите ссылку приглашения');
      }

      final token = _extractTokenFromUrl(url);
      if (token.isEmpty) {
        throw Exception('Неверный формат ссылки');
      }

      await _shareService.connectToWishlist(token);
      _linkController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Успешно подключено к вишлисту!',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Ошибка: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  String _extractTokenFromUrl(String url) {
    try {
      // Убираем пробелы и лишние символы
      final cleanUrl = url.trim();

      // Если это полная ссылка
      if (cleanUrl.contains('http')) {
        final uri = Uri.parse(cleanUrl);
        final segments = uri.pathSegments;

        // Ищем токен в пути
        for (int i = 0; i < segments.length; i++) {
          if (segments[i] == 'wishlist' && i + 1 < segments.length) {
            return segments[i + 1];
          }
        }

        // Если не нашли в пути, проверяем параметры
        final tokenFromQuery = uri.queryParameters['token'];
        if (tokenFromQuery != null) {
          return tokenFromQuery;
        }
      }

      // Если это не ссылка, а просто токен
      return cleanUrl;
    } catch (e) {
      // В случае ошибки возвращаем исходный текст
      return url;
    }
  }

  Future<void> _disconnectWishlist(String sharedWishlistId) async {
    try {
      await _shareService.disconnectFromWishlist(sharedWishlistId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🔗 Доступ к вишлисту отключен',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Ошибка отключения: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }
}
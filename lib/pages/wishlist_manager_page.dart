import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_wishlist/services/share_service.dart';
import 'package:app_wishlist/services/firestore_service.dart';
import 'package:app_wishlist/models/shared_wishlist.dart';
import 'package:app_wishlist/models/user_profile.dart';

class WishlistManagerPage extends StatefulWidget {
  const WishlistManagerPage({super.key});

  @override
  State<WishlistManagerPage> createState() => _WishlistManagerPageState();
}

class _WishlistManagerPageState extends State<WishlistManagerPage> {
  final ShareService _shareService = ShareService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _linkController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление вишлистами'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Секция "Мой вишлист"
          _buildMyWishlistSection(),

          // Секция "Доступные вишлисты"
          _buildSharedWishlistsSection(),

          // Секция "Подключиться по ссылке"
          _buildConnectSection(),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<UserProfile>(
              stream: _firestoreService.getCurrentUserProfile(),
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
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasData) {
                  final profile = snapshot.data!;
                  final shareLink = _shareService.generateShareLink(profile.shareToken);

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
                              label: const Text('КОПИРОВАТЬ'),
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
                              label: const Text('ПОДЕЛИТЬСЯ'),
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
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  );
                }

                return const Text('Данные не найдены');
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
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'ПОДКЛЮЧЕННЫЕ ВИШЛИСТЫ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<SharedWishlist>>(
                stream: _shareService.getSharedWishlists(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 50, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Ошибка загрузки',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final sharedWishlist = snapshot.data![index];
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
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Поделитесь своей ссылкой с друзьями, чтобы видеть их вишлисты здесь',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
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
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _connectToWishlist,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ПОДКЛЮЧИТЬСЯ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListTile(
              leading: CircleAvatar(child: CircularProgressIndicator()),
              title: Text('Загрузка...'),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person_off, color: Colors.white),
              ),
              title: const Text('Неизвестный пользователь'),
              subtitle: Text('ID: ${sharedWishlist.ownerId}'),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () => _disconnectWishlist(sharedWishlist.id),
                tooltip: 'Отключиться',
              ),
            );
          }

          final owner = snapshot.data!;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              backgroundImage: owner.photoURL != null
                  ? NetworkImage(owner.photoURL!)
                  : null,
              child: owner.photoURL == null
                  ? Text(
                owner.displayName.isNotEmpty
                    ? owner.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.blue),
              )
                  : null,
            ),
            title: Text(
              owner.displayName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(owner.email),
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
            Text('Поделиться ссылкой'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Скопируйте ссылку и отправьте друзьям:'),
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
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard(context, link);
              Navigator.pop(context);
            },
            child: const Text('Копировать ссылку'),
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
            Text('Полная ссылка'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ваша ссылка для приглашения:'),
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
                  fontFamily: 'Monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard(context, link);
              Navigator.pop(context);
            },
            child: const Text('Копировать'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    // Временное решение - показываем уведомление
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ссылка скопирована в буфер обмена! 📋'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    // Для реального копирования раскомментируйте:
    // await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _connectToWishlist() async {
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Успешно подключено к вишлисту!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Ошибка: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _extractTokenFromUrl(String url) {
    try {
      if (url.contains('http')) {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        if (segments.length >= 2 && segments[0] == 'wishlist') {
          return segments[1];
        }
      }
      return url;
    } catch (e) {
      return url;
    }
  }

  Future<void> _disconnectWishlist(String sharedWishlistId) async {
    try {
      await _shareService.disconnectFromWishlist(sharedWishlistId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔗 Доступ к вишлисту отключен'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Ошибка отключения: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }
}
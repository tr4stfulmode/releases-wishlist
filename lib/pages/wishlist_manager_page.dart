import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _personalLinkController = TextEditingController();
  final TextEditingController _connectLinkController = TextEditingController();
  bool _isConnecting = false;
  bool _isGeneratingPersonalLink = false;

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
          // Секция "Мой персональный вишлист"
          _buildPersonalWishlistSection(),

          // Секция "Подключиться к вишлисту по ссылке"
          _buildConnectSection(),

          // Секция "Общий вишлист"
          _buildSharedWishlistSection(),

          // Секция "Доступные вишлисты"
          _buildConnectedWishlistsSection(),
        ],
      ),
    );
  }

  Widget _buildPersonalWishlistSection() {
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
                Icon(Icons.person, color: Colors.purple, size: 24),
                SizedBox(width: 8),
                Text(
                  'МОЙ ПЕРСОНАЛЬНЫЙ ВИШЛИСТ',
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
              'Создайте свою уникальную ссылку для приглашения друзей',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Генерация персональной ссылки
            FutureBuilder<String?>(
              future: _shareService.getPersonalShareLink(),
              builder: (context, snapshot) {
                final hasPersonalLink = snapshot.hasData && snapshot.data != null;
                final personalLink = snapshot.data;

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                return Column(
                  children: [
                    if (!hasPersonalLink)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isGeneratingPersonalLink ? null : _generatePersonalLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                          child: _isGeneratingPersonalLink
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text(
                            'СОЗДАТЬ ПЕРСОНАЛЬНУЮ ССЫЛКУ',
                            style: TextStyle(fontFamily: 'Poppins'),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple[200]!),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Ваша персональная ссылка:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => _showFullLinkDialog(context, personalLink!),
                                  child: Text(
                                    personalLink!,
                                    style: const TextStyle(
                                      color: Colors.purple,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _shareLink(personalLink),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.share),
                                      SizedBox(width: 8),
                                      Text('Поделиться', style: TextStyle(fontFamily: 'Poppins')),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _copyToClipboard(context, personalLink),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.purple,
                                    side: const BorderSide(color: Colors.purple),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.copy),
                                      SizedBox(width: 8),
                                      Text('Копировать', style: TextStyle(fontFamily: 'Poppins')),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                );
              },
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
                Icon(Icons.add_link, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'ПОДКЛЮЧИТЬСЯ ПО ССЫЛКЕ',
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
            TextField(
              controller: _connectLinkController,
              decoration: const InputDecoration(
                labelText: 'Вставьте ссылку-приглашение',
                hintText: 'https://yourapp.com/share/...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isConnecting ? null : _connectByLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
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
                  'ПОДКЛЮЧИТЬСЯ К ВИШЛИСТУ',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedWishlistSection() {
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
                Icon(Icons.group, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  'ОБЩИЙ ВИШЛИСТ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Общий вишлист для всех пользователей',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Общая ссылка
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  const Text(
                    'Общая ссылка для всех:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showFullLinkDialog(context, _shareService.generateSharedLink()),
                    child: Text(
                      _shareService.generateSharedLink(),
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Кнопка подключения к общему вишлисту
            FutureBuilder<bool>(
              future: _shareService.isUserConnectedToShared(),
              builder: (context, snapshot) {
                final isConnected = snapshot.data ?? false;

                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isConnected ? null : _connectToSharedWishlist,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? Colors.grey : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: isConnected
                        ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle),
                        SizedBox(width: 8),
                        Text('ПОДКЛЮЧЕН К ОБЩЕМУ'),
                      ],
                    )
                        : const Text('ПОДКЛЮЧИТЬСЯ К ОБЩЕМУ ВИШЛИСТУ'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedWishlistsSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8, left: 8),
              child: Text(
                'МОИ ПОДКЛЮЧЕННЫЕ ВИШЛИСТЫ',
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
                stream: _shareService.getConnectedWishlists(),
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
                            'Ошибка загрузки вишлистов',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final wishlists = snapshot.data ?? [];

                  if (wishlists.isNotEmpty) {
                    return ListView.builder(
                      itemCount: wishlists.length,
                      itemBuilder: (context, index) {
                        final wishlist = wishlists[index];
                        return _buildWishlistCard(wishlist);
                      },
                    );
                  }

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

  Widget _buildWishlistCard(SharedWishlist wishlist) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: FutureBuilder<UserProfile?>(
        future: _firestoreService.getUserProfile(wishlist.ownerId),
        builder: (context, snapshot) {
          final owner = snapshot.data;
          final isPersonal = wishlist.type == 'personal';
          final isShared = wishlist.type == 'shared';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isPersonal ? Colors.purple[100] : Colors.green[100],
              child: Icon(
                isPersonal ? Icons.person : Icons.group,
                color: isPersonal ? Colors.purple : Colors.green,
              ),
            ),
            title: Text(
              isPersonal
                  ? '${owner?.displayName ?? 'Пользователь'} (Персональный)'
                  : 'Общий вишлист',
              style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
            ),
            subtitle: Text(
              isPersonal
                  ? owner?.email ?? 'ID: ${wishlist.ownerId}'
                  : 'Общий для всех пользователей',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () => _disconnectWishlist(wishlist.id),
              tooltip: 'Отключиться от вишлиста',
            ),
          );
        },
      ),
    );
  }

  // ========== ФУНКЦИОНАЛЬНЫЕ МЕТОДЫ ==========

  Future<void> _generatePersonalLink() async {
    setState(() {
      _isGeneratingPersonalLink = true;
    });

    try {
      await _shareService.generatePersonalShareLink();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Персональная ссылка создана!',
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
              '❌ Ошибка создания ссылки: $e',
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
          _isGeneratingPersonalLink = false;
        });
      }
    }
  }

  Future<void> _connectByLink() async {
    final link = _connectLinkController.text.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Введите ссылку для подключения',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      await _shareService.connectByShareLink(link);
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
        _connectLinkController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Ошибка подключения: $e',
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

  Future<void> _connectToSharedWishlist() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      await _shareService.connectToSharedWishlist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Подключено к общему вишлисту!',
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
              '❌ Ошибка подключения: $e',
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

  Future<void> _disconnectWishlist(String wishlistId) async {
    try {
      await _shareService.disconnectFromWishlist(wishlistId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🔗 Отключено от вишлиста',
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

  // Остальные методы (_shareLink, _showFullLinkDialog, _copyToClipboard) остаются без изменений
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
            Text('Поделиться ссылкой', style: TextStyle(fontFamily: 'Poppins')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Скопируйте ссылку и отправьте друзьям:', style: TextStyle(fontFamily: 'Poppins')),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(color: Colors.blue, fontSize: 12, fontFamily: 'Poppins'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть', style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard(context, link);
              Navigator.pop(context);
            },
            child: const Text('Копировать', style: TextStyle(fontFamily: 'Poppins')),
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
            Text('Полная ссылка', style: TextStyle(fontFamily: 'Poppins')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ваша ссылка для приглашения:', style: TextStyle(fontFamily: 'Poppins')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(color: Colors.blue, fontSize: 12, fontFamily: 'Poppins'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть', style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard(context, link);
              Navigator.pop(context);
            },
            child: const Text('Копировать', style: TextStyle(fontFamily: 'Poppins')),
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
          const SnackBar(
            content: Text(
              'Ссылка скопирована в буфер обмена! 📋',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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

  @override
  void dispose() {
    _personalLinkController.dispose();
    _connectLinkController.dispose();
    super.dispose();
  }
}
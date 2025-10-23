import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_wishlist/models/wish_item.dart';
import 'package:app_wishlist/widgets/wish_item_card.dart';
import 'package:app_wishlist/services/auth_service.dart';
import 'package:app_wishlist/services/firestore_service.dart';
import 'package:app_wishlist/services/notification_service.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Для отслеживания уже показанных уведомлений
  final Set<String> _notifiedItems = {};

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startNotificationListener();
  }

  @override
   void dispose() {
    // Отписываемся от слушателей при закрытии страницы
    NotificationService.dispose();
    super.dispose();
  }

  void _initializeNotifications() async {
    await NotificationService.initialize();
    await NotificationService.requestPermissions();
  }

  void _startNotificationListener() {
    // Слушатель для новых предметов в реальном времени
    _firestoreService.getWishItems().listen((items) {
      _checkForNewItems(items);
    });
  }

  void _checkForNewItems(List<WishItem> items) {
    final currentUserEmail = _auth.currentUser?.email;

    for (final item in items) {
      // Если предмет добавлен другим пользователем и мы еще не уведомляли о нем
      if (item.addedBy != null &&
          item.addedBy != currentUserEmail &&
          !_notifiedItems.contains(item.id)) {

        // Проверяем, что предмет новый (создан не более 2 минут назад)
        final twoMinutesAgo = DateTime.now().subtract(const Duration(minutes: 2));
        if (item.createdAt.isAfter(twoMinutesAgo)) {

          // Показываем СИСТЕМНОЕ уведомление
          NotificationService.showNewItemNotification(
            item.title,
            item.addedBy!,
          );

          // Также показываем SnackBar уведомление в приложении
          _showNewItemSnackBar(item.title, item.addedBy!);

          // Помечаем как уведомленный
          _notifiedItems.add(item.id);

          print('✅ Показано уведомление для предмета: ${item.title}');
        }
      }
    }
  }

  void _showNewItemSnackBar(String itemTitle, String addedBy) {
    final userName = addedBy.split('@').first;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎁 Новый предмет!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: 4),
            Text(
              '$userName добавил(а): "$itemTitle"',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _addNewWish() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final imageUrlController = TextEditingController();
    int priority = 3;

    final List<String> defaultImages = [
      'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400',
      'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400',
      'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400',
      'https://images.unsplash.com/photo-1546868871-7041f2a55e12?w=400',
      'https://images.unsplash.com/photo-1560769629-975ec94e6a86?w=400',
      'https://images.unsplash.com/photo-1572569511254-d8f925fe2cbb?w=400',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Добавить новое желание',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Название предмета*',
                        border: OutlineInputBorder(),
                        hintText: 'Введите название',
                      ),
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Описание*',
                        border: OutlineInputBorder(),
                        hintText: 'Введите описание предмета',
                      ),
                      style: const TextStyle(fontFamily: 'Poppins'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Цена*',
                        prefixText: '₽',
                        border: OutlineInputBorder(),
                        hintText: '0.00',
                      ),
                      style: const TextStyle(fontFamily: 'Poppins'),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: imageUrlController,
                      decoration: InputDecoration(
                        labelText: 'Ссылка на изображение (опционально)',
                        border: const OutlineInputBorder(),
                        hintText: 'Оставьте пустым для случайного изображения',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.shuffle),
                          onPressed: () {
                            final randomIndex = (priority - 1) % defaultImages.length;
                            imageUrlController.text = defaultImages[randomIndex];
                            setDialogState(() {});
                          },
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Приоритет',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  priority = index + 1;
                                });
                              },
                              icon: Icon(
                                index < priority ? Icons.star : Icons.star_border,
                                color: Theme.of(context).colorScheme.primary,
                                size: 32,
                              ),
                            );
                          }),
                        ),
                        Center(
                          child: Text(
                            '$priority из 5',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Отмена',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty) {
                      _showErrorSnackBar('Пожалуйста, введите название');
                      return;
                    }

                    if (priceController.text.isEmpty) {
                      _showErrorSnackBar('Пожалуйста, введите цену');
                      return;
                    }

                    final price = double.tryParse(priceController.text);
                    if (price == null || price <= 0) {
                      _showErrorSnackBar('Пожалуйста, введите корректную цену');
                      return;
                    }

                    try {
                      final newWish = WishItem.createNew(
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        price: price,
                        imageUrl: imageUrlController.text.trim().isEmpty
                            ? defaultImages[priority - 1]
                            : imageUrlController.text.trim(),
                        priority: priority,
                        addedBy: _auth.currentUser?.email,
                      );

                      await _firestoreService.addWishItem(newWish);

                      Navigator.pop(context);
                      _showSuccessSnackBar('«${newWish.title}» добавлен в вишлист!');

                    } catch (e) {
                      _showErrorSnackBar('Ошибка при добавлении: $e');
                    }
                  },
                  child: Text(
                    'Добавить',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _checkForNewItems(List<WishItem> items) {
    final currentUserEmail = _auth.currentUser?.email;

    for (final item in items) {
      // Если предмет добавлен другим пользователем и мы еще не уведомляли о нем
      if (item.addedBy != null &&
          item.addedBy != currentUserEmail &&
          !_notifiedItems.contains(item.id)) {

        // Проверяем, что предмет новый (создан не более 2 минут назад)
        final twoMinutesAgo = DateTime.now().subtract(const Duration(minutes: 2));
        if (item.createdAt.isAfter(twoMinutesAgo)) {

          // Показываем СИСТЕМНОЕ уведомление
          NotificationService.showNewItemNotification(
            item.title,
            item.addedBy!,
          );

          // Помечаем как уведомленный
          _notifiedItems.add(item.id);

          print('Показано уведомление для предмета: ${item.title}');
        }
      }
    }
  }

// Добавьте новый метод для SnackBar уведомлений
  void _showNewItemSnackBar(String itemTitle, String addedBy) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎁 Новый предмет!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '$addedBy добавил(а): "$itemTitle"',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _togglePurchased(WishItem item) async {
    try {
      await _firestoreService.togglePurchased(item.id, !item.isPurchased);
    } catch (e) {
      _showErrorSnackBar('Ошибка при обновлении: $e');
    }
  }

  void _deleteWishItem(String itemId) async {
    try {
      await _firestoreService.deleteWishItem(itemId);
      _showSuccessSnackBar('Предмет удален');
    } catch (e) {
      _showErrorSnackBar('Ошибка при удалении: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _logout() async {
    await _authService.signOut();
  }

  double _calculateTotalPrice(List<WishItem> items) {
    return items.fold(0.0, (sum, item) => sum + item.price);
  }

  int _calculatePurchasedCount(List<WishItem> items) {
    return items.where((item) => item.isPurchased).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Общий Вишлист',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: StreamBuilder<List<WishItem>>(
        stream: _firestoreService.getWishItems(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка загрузки: ${snapshot.error}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.red,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final wishItems = snapshot.data ?? [];

          // Проверяем новые предметы от других пользователей
          _checkForNewItems(wishItems);

          return Column(
            children: [
              // Статистика
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Общий вишлист',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${wishItems.length} предметов • ₽${_calculateTotalPrice(wishItems).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_calculatePurchasedCount(wishItems) > 0)
                      Text(
                        'Куплено: ${_calculatePurchasedCount(wishItems)}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                      ),
                  ],
                ),
              ),

              // Список желаний
              Expanded(
                child: wishItems.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: wishItems.length,
                  itemBuilder: (context, index) {
                    final item = wishItems[index];
                    return WishItemCard(
                      item: item,
                      onTap: () => _togglePurchased(item),
                      onDelete: () => _deleteWishItem(item.id),
                      showAddedBy: true,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewWish,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

// Виджет для пустого состояния
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'Вишлист пуст',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Нажмите + чтобы добавить первый предмет',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
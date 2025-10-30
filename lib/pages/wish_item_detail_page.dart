import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:app_wishlist/models/wish_item.dart';
import 'package:app_wishlist/services/firestore_service.dart';
import 'dart:convert';

class WishItemDetailPage extends StatefulWidget {
  final WishItem item;
  final FirestoreService firestoreService;

  const WishItemDetailPage({
    super.key,
    required this.item,
    required this.firestoreService,
  });

  @override
  State<WishItemDetailPage> createState() => _WishItemDetailPageState();
}

class _WishItemDetailPageState extends State<WishItemDetailPage> {
  late WishItem _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Аппбар с изображением
          SliverAppBar(
            expandedHeight: 300,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Основное изображение (Base64 или Network)
                  _buildDetailImage(),

                  // Градиент поверх изображения
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  // Приоритет в углу
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_currentItem.priority}/5',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pinned: true,

          ),

          // Контент
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок и статус
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentItem.title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Статус покупки
                      GestureDetector(
                        onTap: () => _togglePurchased(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _currentItem.isPurchased
                                ? Colors.green
                                : Colors.blue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currentItem.isPurchased ? 'КУПЛЕНО' : 'НЕ КУПЛЕНО',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Цена
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_money,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentItem.price.toStringAsFixed(2)} ₽',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue,
                          ),
                        ),
                        const Spacer(),
                        // Звезды приоритета
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              Icons.star,
                              size: 20,
                              color: index < _currentItem.priority
                                  ? Colors.amber
                                  : Colors.grey[300],
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Описание
                  if (_currentItem.description.isNotEmpty) ...[
                    const Text(
                      'Описание',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        _currentItem.description,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Информация о добавлении
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Информация о предмете',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.person,
                          'Добавил:',
                          _currentItem.addedBy?.split('@').first ?? 'Неизвестно',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Добавлено:',
                          _formatDate(_currentItem.createdAt),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.category,
                          'Приоритет:',
                          '${_currentItem.priority} из 5',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.image,
                          'Тип изображения:',
                          _currentItem.base64Image != null ? 'Локальное' : 'Ссылка',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Кнопки действий
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _viewFullImage(context),
                          icon: const Icon(Icons.fullscreen),
                          label: const Text('Полный размер'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.blue.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _togglePurchased(context),
                          icon: Icon(
                            _currentItem.isPurchased
                                ? Icons.remove_shopping_cart
                                : Icons.shopping_cart_checkout,
                          ),
                          label: Text(
                            _currentItem.isPurchased
                                ? 'Отменить покупку'
                                : 'Отметить купленным',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentItem.isPurchased
                                ? Colors.orange
                                : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Кнопка редактирования
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _editItem(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('Редактировать предмет'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Плавающая кнопка удаления
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDeleteDialog(context),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        child: const Icon(Icons.delete),
      ),
    );
  }

  Widget _buildDetailImage() {
    // Если есть Base64 изображение
    if (_currentItem.base64Image != null && _currentItem.base64Image!.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(_currentItem.base64Image!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorImage();
          },
        );
      } catch (e) {
        return _buildErrorImage();
      }
    }

    // Если есть URL изображение
    if (_currentItem.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _currentItem.imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => _buildErrorImage(),
      );
    }

    // Если нет изображения
    return _buildPlaceholderImage();
  }

  Widget _buildErrorImage() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'Ошибка загрузки изображения',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'Нет изображения',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} в '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void _togglePurchased(BuildContext context) async {
    try {
      await widget.firestoreService.togglePurchased(
          _currentItem.id,
          !_currentItem.isPurchased
      );

      setState(() {
        _currentItem = _currentItem.copyWith(
          isPurchased: !_currentItem.isPurchased,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _currentItem.isPurchased
                ? 'Предмет отмечен как купленный! 🎉'
                : 'Покупка отменена',
          ),
          backgroundColor: _currentItem.isPurchased ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // Полноразмерное изображение
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildFullSizeImage(),
              ),
            ),

            // Кнопка закрытия
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullSizeImage() {
    if (_currentItem.base64Image != null && _currentItem.base64Image!.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(_currentItem.base64Image!),
          fit: BoxFit.contain,
        );
      } catch (e) {
        return _buildErrorImage();
      }
    }

    if (_currentItem.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _currentItem.imageUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => _buildErrorImage(),
      );
    }

    return _buildPlaceholderImage();
  }

  void _editItem(BuildContext context) {
    // Здесь можно реализовать редактирование предмета
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция редактирования будет добавлена позже'),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить предмет?'),
        content: Text('Вы уверены, что хотите удалить «${_currentItem.title}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(BuildContext context) async {
    try {
      await widget.firestoreService.deleteWishItem(_currentItem.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Предмет удален'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareItem(BuildContext context) {
    final shareText = '🎁 ${_currentItem.title}\n'
        '💵 Цена: ${_currentItem.price} ₽\n'
        '⭐ Приоритет: ${_currentItem.priority}/5\n'
        '${_currentItem.description.isNotEmpty ? '📝 ${_currentItem.description}' : ''}';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция шеринга будет добавлена позже'),
      ),
    );
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:app_wishlist/models/wish_item.dart';
import 'dart:convert';

import '../models/user_profile.dart';
import '../services/firestore_service.dart';

class WishItemCard extends StatelessWidget {
  final WishItem item;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showAddedBy;

  const WishItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onDelete,
    this.showAddedBy = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMyItem = currentUser != null && item.addedBy == currentUser.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Изображение (Base64 или Network)
              _buildImageWidget(),
              const SizedBox(width: 16),

              // Информация
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₽${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const Spacer(),
                        // Приоритет
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              Icons.star,
                              size: 16,
                              color: index < item.priority
                                  ? Colors.amber
                                  : Colors.grey[300],
                            );
                          }),
                        ),
                      ],
                    ),

                    // Информация о том, кто добавил
                    if (showAddedBy && item.addedBy != null) ...[
                      const SizedBox(height: 4),
                      FutureBuilder<UserProfile>(
                        future: FirestoreService().getUserProfile(item.addedBy!),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final owner = snapshot.data!;
                            return Row(
                              children: [
                                Icon(
                                  isMyItem ? Icons.person : Icons.group,
                                  size: 12,
                                  color: isMyItem ? Colors.blue : Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isMyItem ? 'Мой предмет' : 'Добавил: ${owner.displayName}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMyItem ? Colors.blue : Colors.green,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ],
                  ],
                ),
              ),

              // Статус покупки
              IconButton(
                onPressed: onTap,
                icon: Icon(
                  item.isPurchased
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: item.isPurchased ? Colors.green : Colors.grey,
                  size: 28,
                ),
              ),

              // Кнопка удаления (только для своих предметов)
              if (isMyItem && onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    // Если есть Base64 изображение - используем его
    if (item.base64Image != null && item.base64Image!.isNotEmpty) {
      try {
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: MemoryImage(base64Decode(item.base64Image!)),
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (e) {
        // Если ошибка декодирования Base64, показываем иконку ошибки
        return _buildErrorImage();
      }
    }

    // Если есть URL изображение - используем его
    if (item.imageUrl.isNotEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: NetworkImage(item.imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: item.imageUrl.contains('unsplash.com')
            ? null
            : _buildImageLoadingIndicator(),
      );
    }

    // Если нет изображения - показываем placeholder
    return _buildPlaceholderImage();
  }

  Widget _buildImageLoadingIndicator() {
    return FutureBuilder<bool>(
      future: _checkImageUrl(item.imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == false) {
          return _buildErrorImage();
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: const Icon(
        Icons.photo,
        color: Colors.grey,
        size: 24,
      ),
    );
  }

  Widget _buildErrorImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: const Icon(
        Icons.error_outline,
        color: Colors.red,
        size: 24,
      ),
    );
  }

  Future<bool> _checkImageUrl(String url) async {
    try {
      if (url.isEmpty) return false;

      // Для Base64 URL (заглушки)
      if (url.startsWith('base64://')) return true;

      // Для обычных URL проверяем валидность
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return false;

      return true;
    } catch (e) {
      return false;
    }
  }
}
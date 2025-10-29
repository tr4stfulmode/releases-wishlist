import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:app_wishlist/models/wish_item.dart';

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
              // Изображение
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(item.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
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
}
import 'package:flutter/material.dart';
import 'package:app_wishlist/models/wish_item.dart';

class WishItemCard extends StatelessWidget {
  final WishItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool showAddedBy;

  const WishItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    this.showAddedBy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
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
        title: Text(
          item.title,
          style: TextStyle(
            decoration: item.isPurchased ? TextDecoration.lineThrough : null,
            color: item.isPurchased ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('₽${item.price.toStringAsFixed(2)}'),
                const Spacer(),
                ...List.generate(5, (index) {
                  return Icon(
                    Icons.star,
                    size: 16,
                    color: index < item.priority ? Colors.orange : Colors.grey[300],
                  );
                }),
              ],
            ),
            if (showAddedBy && item.addedBy != null) ...[
              const SizedBox(height: 4),
              Text(
                'Добавил: ${item.addedBy}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                item.isPurchased ? Icons.check_circle : Icons.radio_button_unchecked,
                color: item.isPurchased ? Colors.green : Colors.grey,
              ),
              onPressed: onTap,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
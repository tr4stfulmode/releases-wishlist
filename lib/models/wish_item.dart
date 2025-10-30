import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WishItem {
  final String? base64Image;
  final String id;
  final String title;
  final String description;
  final double price;
  final String imageUrl;
  final int priority;
  bool isPurchased;
  final DateTime createdAt;
  final String? addedBy;

  WishItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.priority,
    this.isPurchased = false,
    required this.createdAt,
    this.addedBy,
    this.base64Image,
  });

  factory WishItem.createNew({
    required String title,
    required String description,
    required double price,
    required String imageUrl,
    required int priority,
    String? addedBy,
    String? base64Image,
  }) {
    return WishItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      price: price,
      imageUrl: imageUrl,
      priority: priority,
      createdAt: DateTime.now(),
      addedBy: addedBy,
      base64Image: base64Image,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'priority': priority,
      'isPurchased': isPurchased,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'addedBy': addedBy,
      'base64Image': base64Image, // Добавляем base64Image в toMap
    };
  }

  factory WishItem.fromMap(Map<String, dynamic> map, String id) {
    return WishItem(
      id: id,
      title: map['title'] as String,
      description: map['description'] as String,
      price: (map['price'] as num).toDouble(),
      imageUrl: map['imageUrl'] as String,
      priority: map['priority'] as int,
      isPurchased: map['isPurchased'] as bool? ?? false,
      addedBy: map['addedBy'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      base64Image: map['base64Image'] as String?, // Исправлено: используем map вместо data
    );
  }

  // Для совместимости с Firestore
  Map<String, dynamic> toFirestore() {
    return toMap();
  }

  factory WishItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WishItem.fromMap(data, doc.id);
  }

  // Метод для получения изображения (Base64 или URL)
  Widget getImageWidget({double height = 150, BoxFit fit = BoxFit.cover}) {
    if (base64Image != null && base64Image!.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(base64Image!),
          height: height,
          width: double.infinity,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            // Если Base64 невалидный, показываем стандартное изображение
            return _buildDefaultImage(height, fit);
          },
        );
      } catch (e) {
        // В случае ошибки декодирования Base64
        return _buildDefaultImage(height, fit);
      }
    } else if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        height: height,
        width: double.infinity,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            width: double.infinity,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultImage(height, fit);
        },
      );
    } else {
      return _buildDefaultImage(height, fit);
    }
  }

  Widget _buildDefaultImage(double height, BoxFit fit) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey[200],
      child: Icon(
        Icons.photo,
        size: 40,
        color: Colors.grey[400],
      ),
    );
  }

  // Копирование объекта с обновленными полями
  WishItem copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? imageUrl,
    int? priority,
    bool? isPurchased,
    DateTime? createdAt,
    String? addedBy,
    String? base64Image,
  }) {
    return WishItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      priority: priority ?? this.priority,
      isPurchased: isPurchased ?? this.isPurchased,
      createdAt: createdAt ?? this.createdAt,
      addedBy: addedBy ?? this.addedBy,
      base64Image: base64Image ?? this.base64Image,
    );
  }

  @override
  String toString() {
    return 'WishItem(id: $id, title: $title, price: $price, base64Image: ${base64Image != null ? "${base64Image!.substring(0, 20)}..." : "null"})';
  }
}
import 'package:flutter/material.dart';
import 'package:app_wishlist/models/wish_item.dart';

class AddWishForm extends StatefulWidget {
  final Function(WishItem) onWishAdded;

  const AddWishForm({super.key, required this.onWishAdded});

  @override
  State<AddWishForm> createState() => _AddWishFormState();
}

class _AddWishFormState extends State<AddWishForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  int _priority = 3;

  // Список предустановленных изображений
  final List<String> _defaultImages = [
    'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400', // Наушники
    'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400', // Часы
    'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400', // Рюкзак
    'https://images.unsplash.com/photo-1546868871-7041f2a55e12?w=400', // Смартфон
    'https://images.unsplash.com/photo-1560769629-975ec94e6a86?w=400', // Кроссовки
    'https://images.unsplash.com/photo-1572569511254-d8f925fe2cbb?w=400', // Книги
  ];

  // Публичный метод для отправки формы
  void submitForm() {
    if (_formKey.currentState!.validate()) {
      final newWish = WishItem.createNew(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text) ?? 0.0,
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? _defaultImages[_priority - 1]
            : _imageUrlController.text.trim(),
        priority: _priority,
      );

      widget.onWishAdded(newWish);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название предмета',
                border: OutlineInputBorder(),
                hintText: 'Введите название',
              ),
              style: const TextStyle(fontFamily: 'Poppins'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите название';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
                hintText: 'Введите описание предмета',
              ),
              style: const TextStyle(fontFamily: 'Poppins'),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите описание';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Цена',
                prefixText: '₽',
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
              style: const TextStyle(fontFamily: 'Poppins'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите цену';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Пожалуйста, введите корректную цену';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrlController,
              decoration: InputDecoration(
                labelText: 'Ссылка на изображение (опционально)',
                border: const OutlineInputBorder(),
                hintText: 'Оставьте пустым для случайного изображения',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.shuffle),
                  onPressed: () {
                    final randomIndex = (_priority - 1) % _defaultImages.length;
                    _imageUrlController.text = _defaultImages[randomIndex];
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
                        setState(() {
                          _priority = index + 1;
                        });
                      },
                      icon: Icon(
                        index < _priority ? Icons.star : Icons.star_border,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                    );
                  }),
                ),
                Center(
                  child: Text(
                    '$_priority из 5',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }
}
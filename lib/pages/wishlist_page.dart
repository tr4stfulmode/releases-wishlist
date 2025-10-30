import 'package:app_wishlist/pages/wishlist_manager_page.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_wishlist/models/wish_item.dart';
import 'package:app_wishlist/widgets/wish_item_card.dart';
import 'package:app_wishlist/services/auth_service.dart';
import 'package:app_wishlist/services/firestore_service.dart';
import 'package:app_wishlist/services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_wishlist/pages/wish_item_detail_page.dart';

import '../services/rustore_update_service.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Set<String> _notifiedItems = {};
  bool _isProcessingImage = false;

  // Проверка версии Android
  Future<bool> _isAndroid13OrHigher() async {
    try {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      return deviceInfo.version.sdkInt >= 33;
    } catch (e) {
      return false;
    }
  }

  // Диалог для перехода в настройки
  void _showPermissionSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Требуется разрешение',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        content: Text(
          'Разрешение на $permissionName было отклонено навсегда. '
              'Пожалуйста, предоставьте разрешение в настройках приложения.',
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(
              'Настройки',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startNotificationListener();
    _startNewItemsListener();
    _checkForAppUpdate();
  }

  void _checkForAppUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await RuStoreUpdateService.checkForUpdate();
      }
    });
  }

  void _startNewItemsListener() {
    _firestoreService.getSharedWishItems().listen((items) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForNewItems(items);
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _initializeNotifications() async {
    await NotificationService.initialize();
    await NotificationService.requestPermissions();
  }

  void _startNotificationListener() {
    _firestoreService.getSharedWishItems().listen((items) {
      _checkForNewItems(items);
    });
  }

  void _checkForNewItems(List<WishItem> items) {
    final currentUserUid = _auth.currentUser?.uid;

    for (final item in items) {
      if (item.addedBy != null &&
          item.addedBy != currentUserUid &&
          !_notifiedItems.contains(item.id)) {
        final twoMinutesAgo = DateTime.now().subtract(const Duration(minutes: 2));
        if (item.createdAt.isAfter(twoMinutesAgo)) {
          _getUserInfoForNotification(item.addedBy!, item.title);
          _notifiedItems.add(item.id);
        }
      }
    }
  }

  void _getUserInfoForNotification(String userUid, String itemTitle) async {
    try {
      final userProfile = await _firestoreService.getUserProfile(userUid);
      final userName = userProfile.displayName;

      NotificationService.showNewItemNotification(
        itemTitle,
        userName,
      );

      _showNewItemSnackBar(itemTitle, userName);

    } catch (e) {
      NotificationService.showNewItemNotification(
        itemTitle,
        'Другой пользователь',
      );
      _showNewItemSnackBar(itemTitle, 'Другой пользователь');
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
            const SizedBox(height: 4),
            Text(
              '$userName добавил(а): "$itemTitle"',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        backgroundColor: _Colors.glassPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        duration: const Duration(seconds: 4),
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

  // Конвертация изображения в Base64
  Future<String?> _convertImageToBase64(XFile imageFile) async {
    try {
      setState(() {
        _isProcessingImage = true;
      });

      // Читаем файл как байты
      final bytes = await imageFile.readAsBytes();

      // Конвертируем в Base64
      final base64String = base64Encode(bytes);

      // Проверяем размер (Firestore ограничение 1MB на документ)
      if (base64String.length > 900000) { // ~1MB в Base64
        _showErrorSnackBar('Изображение слишком большое. Выберите файл меньше 700KB');
        return null;
      }

      setState(() {
        _isProcessingImage = false;
      });

      return base64String;
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
      });
      _showErrorSnackBar('Ошибка обработки изображения: $e');
      return null;
    }
  }

  void _addNewWish() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final imageUrlController = TextEditingController();
    int priority = 3;
    XFile? _selectedImage;
    String? _base64Image;

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
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF8F9FA),
                      Color(0xFFE9ECEF),
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Заголовок с стеклянным эффектом
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.7),
                            border: Border.all(color: Colors.white.withOpacity(0.9)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Добавить новое желание',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: _Colors.glassPrimary,
                              ),
                            ),
                          ),
                        ),

                        // Индикатор обработки
                        if (_isProcessingImage)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: _Colors.glassPrimary.withOpacity(0.1),
                            ),
                            child: Row(
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(_Colors.glassPrimary),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Обрабатываем изображение...',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: _Colors.glassPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_selectedImage != null)
                          Container(
                            height: 150,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                image: FileImage(File(_selectedImage!.path)),
                                fit: BoxFit.cover,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      color: Colors.white,
                                      onPressed: () {
                                        setDialogState(() {
                                          _selectedImage = null;
                                          _base64Image = null;
                                          imageUrlController.clear();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Изображение из галереи',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (imageUrlController.text.isNotEmpty)
                          Container(
                            height: 150,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                image: NetworkImage(imageUrlController.text),
                                fit: BoxFit.cover,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                          ),

                        // Кнопки выбора изображения
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.6),
                            border: Border.all(color: Colors.white.withOpacity(0.8)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _GlassButton(
                                  onPressed: _isProcessingImage ? null : () async {
                                    final ImagePicker picker = ImagePicker();

                                    if (await _isAndroid13OrHigher()) {
                                      final status = await Permission.photos.request();
                                      if (status.isGranted) {
                                        final XFile? image = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          maxWidth: 800,
                                          maxHeight: 800,
                                          imageQuality: 70, // Уменьшаем качество для экономии места
                                        );
                                        if (image != null) {
                                          setDialogState(() {
                                            _selectedImage = image;
                                            imageUrlController.clear();
                                          });
                                        }
                                      } else if (status.isPermanentlyDenied) {
                                        _showPermissionSettingsDialog('доступу к галерее');
                                      } else {
                                        _showErrorSnackBar('Разрешение на доступ к галерее не предоставлено');
                                      }
                                    } else {
                                      final status = await Permission.storage.request();
                                      if (status.isGranted) {
                                        final XFile? image = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          maxWidth: 800,
                                          maxHeight: 800,
                                          imageQuality: 70,
                                        );
                                        if (image != null) {
                                          setDialogState(() {
                                            _selectedImage = image;
                                            imageUrlController.clear();
                                          });
                                        }
                                      } else if (status.isPermanentlyDenied) {
                                        _showPermissionSettingsDialog('доступу к хранилищу');
                                      } else {
                                        _showErrorSnackBar('Разрешение на доступ к хранилищу не предоставлено');
                                      }
                                    }
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.photo_library, color: _isProcessingImage ? Colors.grey : _Colors.glassPrimary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Галерея',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: _isProcessingImage ? Colors.grey : _Colors.glassPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _GlassButton(
                                  onPressed: _isProcessingImage ? null : () async {
                                    final ImagePicker picker = ImagePicker();
                                    final status = await Permission.camera.request();
                                    if (status.isGranted) {
                                      final XFile? image = await picker.pickImage(
                                        source: ImageSource.camera,
                                        maxWidth: 800,
                                        maxHeight: 800,
                                        imageQuality: 70,
                                      );
                                      if (image != null) {
                                        setDialogState(() {
                                          _selectedImage = image;
                                          imageUrlController.clear();
                                        });
                                      }
                                    } else {
                                      _showErrorSnackBar('Разрешение на камеру не предоставлено');
                                    }
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt, color: _isProcessingImage ? Colors.grey : _Colors.glassPrimary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Камера',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: _isProcessingImage ? Colors.grey : _Colors.glassPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Поля ввода
                        _GlassInputField(
                          controller: titleController,
                          labelText: 'Название предмета',
                          hintText: 'Введите название',
                        ),
                        const SizedBox(height: 16),
                        _GlassInputField(
                          controller: descriptionController,
                          labelText: 'Описание',
                          hintText: 'Введите описание предмета',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _GlassInputField(
                          controller: priceController,
                          labelText: 'Цена (опционально)',
                          hintText: '0.00',
                          prefixText: '₽',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 16),
                        _GlassInputField(
                          controller: imageUrlController,
                          labelText: 'Ссылка на товар (опционально)',
                          suffixIcon: IconButton(
                            icon: Icon(Icons.shuffle, color: _Colors.glassPrimary),
                            onPressed: () {
                              final randomIndex = (priority - 1) % defaultImages.length;
                              setDialogState(() {
                                imageUrlController.text = defaultImages[randomIndex];
                                _selectedImage = null;
                                _base64Image = null;
                              });
                            },
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              setDialogState(() {
                                _selectedImage = null;
                                _base64Image = null;
                              });
                            }
                          },
                          hintText: '',
                        ),

                        if (_selectedImage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: _Colors.glassPrimary.withOpacity(0.1),
                              border: Border.all(color: _Colors.glassPrimary.withOpacity(0.3)),
                            ),
                            child: Text(
                              '✅ Изображение будет сохранено и доступно всем пользователям',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: _Colors.glassPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Приоритет
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.6),
                            border: Border.all(color: Colors.white.withOpacity(0.8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Приоритет',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _Colors.glassPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
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
                                      index < priority
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: _Colors.glassPrimary,
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
                                    color: _Colors.glassPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                              child: _GlassButton(
                                onPressed: _isProcessingImage ? null : () => Navigator.pop(context),
                                child: Text(
                                  'Отмена',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: _isProcessingImage ? Colors.grey : _Colors.glassPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: _isProcessingImage
                                      ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                                      : const LinearGradient(
                                    colors: [
                                      _Colors.glassPrimary,
                                      _Colors.glassSecondary,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _Colors.glassPrimary.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: _isProcessingImage ? null : () async {
                                      if (titleController.text.isEmpty) {
                                        _showErrorSnackBar('Пожалуйста, введите название');
                                        return;
                                      }

                                      // Обработка цены (необязательная)
                                      double? price;
                                      if (priceController.text.isNotEmpty) {
                                        price = double.tryParse(priceController.text);
                                        if (price == null || price <= 0) {
                                          _showErrorSnackBar('Пожалуйста, введите корректную цену');
                                          return;
                                        }
                                      }
                                      // Если цена не указана - price останется null

                                      try {
                                        String imageUrl;
                                        String? base64Image;

                                        // Если выбрано локальное изображение, конвертируем в Base64
                                        if (_selectedImage != null) {
                                          final base64 = await _convertImageToBase64(_selectedImage!);
                                          if (base64 == null) {
                                            _showErrorSnackBar('Не удалось обработать изображение');
                                            return;
                                          }
                                          base64Image = base64;
                                          imageUrl = 'base64://${_selectedImage!.name}'; // Заглушка для URL
                                        }
                                        // Если введена ссылка, используем её
                                        else if (imageUrlController.text.isNotEmpty) {
                                          imageUrl = imageUrlController.text.trim();
                                        }
                                        // Иначе используем стандартное изображение
                                        else {
                                          imageUrl = defaultImages[priority - 1];
                                        }

                                        final newWish = WishItem.createNew(
                                          title: titleController.text.trim(),
                                          description: descriptionController.text.trim(),
                                          imageUrl: imageUrl,
                                          price: price ?? 0.0, // Если цена null, используем 0.0
                                          priority: priority,
                                          addedBy: _auth.currentUser?.uid,
                                          base64Image: base64Image,
                                        );

                                        await _firestoreService.addWishItem(newWish);

                                        Navigator.pop(context);
                                        _showSuccessSnackBar('«${newWish.title}» добавлен в вишлист!');
                                      } catch (e) {
                                        _showErrorSnackBar('Ошибка при добавлении: $e');
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                      child: Center(
                                        child: _isProcessingImage
                                            ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                            : Text(
                                          'Добавить',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: _Colors.glassPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          borderRadius: BorderRadius.circular(20),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _logout() async {
    await _authService.signOut();
  }

  void _openItemDetail(BuildContext context, WishItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WishItemDetailPage(
          item: item,
          firestoreService: _firestoreService,
        ),
      ),
    );
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
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Общий Вишлист',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _Colors.glassPrimary,
                _Colors.glassSecondary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _Colors.glassPrimary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: IconButton(
              icon: const Icon(Icons.group, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const WishlistManagerPage()),
              ),
              tooltip: 'Управление вишлистами',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
              tooltip: 'Выйти',
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<WishItem>>(
        stream: _firestoreService.getSharedWishItems(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_Colors.glassPrimary),
                ),
              ),
            );
          }

          final wishItems = snapshot.data ?? [];

          return Column(
            children: [
              // Заголовок с статистикой
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 30),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _Colors.glassPrimary,
                      _Colors.glassSecondary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Общий вишлист',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${wishItems.length} предметов • ₽${_calculateTotalPrice(wishItems).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          StreamBuilder<List<String>>(
                            stream: _firestoreService.getAccessibleWishlistIds(),
                            builder: (context, accessibleSnapshot) {
                              if (accessibleSnapshot.hasData) {
                                final accessibleIds = accessibleSnapshot.data!;
                                final connectedCount = accessibleIds.length;

                                return Column(
                                  children: [
                                    if (_calculatePurchasedCount(wishItems) > 0)
                                      Text(
                                        'Куплено: ${_calculatePurchasedCount(wishItems)}',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    if (connectedCount > 0)
                                      Text(
                                        'Подключено к $connectedCount вишлистам',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                  ],
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: wishItems.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: wishItems.length,
                  itemBuilder: (context, index) {
                    final item = wishItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: WishItemCard(
                        item: item,
                        onTap: () => _openItemDetail(context, item),
                        onDelete: () => _deleteWishItem(item.id),
                        showAddedBy: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton(
          onPressed: _addNewWish,
          backgroundColor: Colors.white,
          foregroundColor: _Colors.glassPrimary,
          elevation: 10,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  _Colors.glassPrimary,
                  _Colors.glassSecondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.add, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    String errorMessage = 'Произошла ошибка';

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          errorMessage = 'Нет доступа к данным. Проверьте настройки безопасности.';
          break;
        case 'unavailable':
          errorMessage = 'Нет подключения к интернету';
          break;
        default:
          errorMessage = 'Ошибка Firebase: ${error.message}';
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 20),
            Text(
              'Ошибка загрузки',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _Colors.glassPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {});
              },
              child: Text(
                'Попробовать снова',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.white.withOpacity(0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.9)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _Colors.glassPrimary.withOpacity(0.1),
                  border: Border.all(color: _Colors.glassPrimary.withOpacity(0.3)),
                ),
                child: Icon(
                  Icons.favorite_border_rounded,
                  size: 60,
                  color: _Colors.glassPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Вишлист пуст',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _Colors.glassPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Нажмите + чтобы добавить первый предмет',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Кастомные цвета для стеклянного дизайна
class _Colors {
  static const glassPrimary = Color(0xFF6366F1);
  static const glassSecondary = Color(0xFF8B5CF6);
  static const glassSurface = Color(0xFFF8FAFC);
}

// Стеклянная кнопка
class _GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _GlassButton({
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Стеклянное поле ввода
class _GlassInputField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final String? prefixText;
  final int? maxLines;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const _GlassInputField({
    required this.controller,
    required this.labelText,
    required this.hintText,
    this.prefixText,
    this.maxLines = 1,
    this.keyboardType,
    this.suffixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(fontFamily: 'Poppins', color: Colors.black87),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixText: prefixText,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            fontFamily: 'Poppins',
            color: _Colors.glassPrimary,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.grey,
          ),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
      ),
    );
  }
}
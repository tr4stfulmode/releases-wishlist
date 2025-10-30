import 'dart:math';
import 'dart:developer' hide log;

import 'package:flutter/material.dart';
import 'package:flutter_rustore_update/flutter_rustore_update.dart';
import 'package:url_launcher/url_launcher.dart';

class RuStoreUpdateService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static get FlutterRustoreUpdate => null;

  // Основной метод для проверки обновлений
  static Future<void> checkForUpdate() async {
    try {
      print('🔍 RuStoreUpdateService: Checking for updates...');

      // Инициализация RuStore Update
      await FlutterRustoreUpdate.init();

      // Проверка доступности обновлений
      final updateInfo = await FlutterRustoreUpdate.getUpdateInfo();
      print('📋 Update info: $updateInfo');

      if (updateInfo != null && updateInfo.isUpdateAvailable == true) {
        print('✅ Update available: ${updateInfo.versionName}');
        _showUpdateDialog(updateInfo);
      } else {
        print('📌 No updates available');
      }
    } catch (e) {
      print('❌ RuStore update check error: $e');
      // Не показываем диалог ошибки, чтобы не беспокоить пользователя
    }
  }

  // Диалог обновления через RuStore
  static void _showUpdateDialog(dynamic updateInfo) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('❌ Context is null, cannot show update dialog');
      return;
    }
    final versionName = updateInfo.versionName ?? 'Новая версия';
    final installSize = updateInfo.installSize;

    showDialog(
      context: context,
      barrierDismissible: true, // Разрешаем закрытие
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.update, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Text(
                'Доступно обновление',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Новая версия ${versionName} уже ждет вас!',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Что нового:',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureItem('🎯 Улучшена производительность'),
                      _buildFeatureItem('🐛 Исправлены ошибки'),
                      _buildFeatureItem('✨ Новые функции'),
                      _buildFeatureItem('🔔 Улучшены уведомления'),
                    ],
                  ),
                ),
                if (installSize != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Размер обновления: ${_formatFileSize(installSize)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                print('📌 User postponed update');
              },
              child: const Text(
                'Напомнить позже',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startRuStoreUpdate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Обновить',
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
  }

  // Запуск обновления через RuStore
  static Future<void> _startRuStoreUpdate() async {
    try {
      print('🔄 Starting RuStore update...');
      await FlutterRustoreUpdate.update();
    } catch (e) {
      print('❌ RuStore update error: $e');
      _openRuStore(); // Если автоматическое обновление не сработало, открываем RuStore
    }
  }

  // Открытие RuStore
  static Future<void> _openRuStore() async {
    try {
      // Замените на ваш реальный package name
      const packageName = 'com.yourapp.wishlist';

      // Пытаемся открыть через схему RuStore
      const rustoreUrl = 'rustore://details?id=$packageName';
      if (await canLaunchUrl(Uri.parse(rustoreUrl))) {
        await launchUrl(Uri.parse(rustoreUrl));
      } else {
        // Если схема не работает, открываем веб-версию
        const webUrl = 'https://apps.rustore.ru/app/$packageName';
        if (await canLaunchUrl(Uri.parse(webUrl))) {
          await launchUrl(
            Uri.parse(webUrl),
            mode: LaunchMode.externalApplication,
          );
        } else {
          throw Exception('Could not launch RuStore');
        }
      }
    } catch (e) {
      print('❌ Error opening RuStore: $e');
    }
  }

  // Форматирование размера файла
  static String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  static Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
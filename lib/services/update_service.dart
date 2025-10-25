import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class UpdateService {
  // ⚠️ ЗАМЕНИТЕ на ваш репозиторий!
  static const String repoUrl =
      'https://api.github.com/repos/tr4stfulmode/releases-wishlist/releases/latest';

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _isChecking = false;
  static bool _updateShown = false;

  static Future<void> checkAndUpdate({bool forceCheck = false}) async {
    if (_isChecking && !forceCheck) return;
    _isChecking = true;

    try {
      print('🔍 Checking for updates...');
      final response = await http.get(
        Uri.parse(repoUrl),
        headers: {'User-Agent': 'Wishlist-App'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name']?.toString().replaceAll('v', '') ?? '';
        final downloadUrl = _findApkUrl(data);
        final releaseNotes = data['body'] ?? 'Новое обновление доступно';
        final isMandatory = _checkIfMandatory(data);

        print('📦 Latest: $latestVersion, URL: ${downloadUrl.isNotEmpty}');

        if (await _shouldUpdate(latestVersion) && downloadUrl.isNotEmpty) {
          if (!_updateShown || forceCheck) {
            _updateShown = true;
            _showUpdateDialog(downloadUrl, releaseNotes, isMandatory);
          }
        } else {
          print('✅ App is up to date');
          if (forceCheck) {
            _showUpToDateSnackBar();
          }
        }
      } else {
        print('❌ GitHub API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Update check failed: $e');
    } finally {
      _isChecking = false;
    }
  }

  static String _findApkUrl(Map<String, dynamic> data) {
    if (data['assets'] != null) {
      for (var asset in data['assets']) {
        if (asset['name']?.toString().endsWith('.apk') == true) {
          return asset['browser_download_url'];
        }
      }
    }
    return '';
  }

  static bool _checkIfMandatory(Map<String, dynamic> data) {
    final notes = (data['body'] ?? '').toLowerCase();
    return notes.contains('[mandatory]') || notes.contains('[critical]');
  }

  static Future<bool> _shouldUpdate(String latestVersion) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    return _compareVersions(currentVersion, latestVersion) < 0;
  }

  static int _compareVersions(String version1, String version2) {
    try {
      final v1 = version1.split('.').map(int.parse).toList();
      final v2 = version2.split('.').map(int.parse).toList();

      for (int i = 0; i < v1.length; i++) {
        if (i >= v2.length) return 1;
        if (v1[i] > v2[i]) return 1;
        if (v1[i] < v2[i]) return -1;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static void _showUpdateDialog(String downloadUrl, String releaseNotes, bool isMandatory) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            isMandatory ? 'Требуется обновление' : 'Доступно обновление',
            style: TextStyle(
              color: isMandatory ? Colors.red : Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Что нового:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  releaseNotes.length > 200
                      ? '${releaseNotes.substring(0, 200)}...'
                      : releaseNotes,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                if (isMandatory)
                  Text(
                    'Это критическое обновление. Приложение может не работать без него.',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (!isMandatory)
              TextButton(
                onPressed: () {
                  _updateShown = false;
                  Navigator.of(context).pop();
                },
                child: const Text('ПОЗЖЕ'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstall(downloadUrl);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isMandatory ? Colors.red : Colors.blue,
              ),
              child: Text(isMandatory ? 'ОБНОВИТЬ СЕЙЧАС' : 'ОБНОВИТЬ'),
            ),
          ],
        );
      },
    );
  }

  static void _showUpToDateSnackBar() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Приложение обновлено до последней версии'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  static Future<void> _downloadAndInstall(String url) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('❌ Context is null, cannot show download dialog');
      return;
    }

    try {
      // Показываем индикатор загрузки
      showDialog(
        context: context, // Теперь context гарантированно не null
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Загрузка обновления...'),
              const SizedBox(height: 8),
              Text(
                'Не закрывайте приложение',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );

      // Запрашиваем разрешения
      if (await Permission.storage.request().isGranted) {
        print('📥 Downloading update from: $url');
        final response = await http.get(Uri.parse(url));

        // Сохраняем файл
        final directory = await getExternalStorageDirectory();
        final file = File('${directory?.path}/update_${DateTime.now().millisecondsSinceEpoch}.apk');

        await file.writeAsBytes(response.bodyBytes);
        print('✅ Update downloaded: ${file.path}');

        // Закрываем диалог загрузки
        if (navigatorKey.currentContext != null) {
          Navigator.of(navigatorKey.currentContext!).pop();
        }

        // Устанавливаем APK
        await OpenFile.open(file.path);
        print('🚀 Opening installer...');

      } else {
        if (navigatorKey.currentContext != null) {
          Navigator.of(navigatorKey.currentContext!).pop();
        }
        _showErrorSnackBar('Разрешение на запись не предоставлено');
      }
    } catch (e) {
      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }
      print('❌ Download failed: $e');
      _showErrorSnackBar('Ошибка загрузки: $e');
    }
  }

  static void _showErrorSnackBar(String message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Метод для ручной проверки (можно вызвать из кнопки)
  static Future<void> manualCheck() async {
    await checkAndUpdate(forceCheck: true);
  }
}
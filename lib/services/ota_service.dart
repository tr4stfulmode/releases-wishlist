import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';

class OTAService {
  static final Dio _dio = Dio();
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Проверить обновления через Firebase
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Получаем информацию о версии из Firebase
      final versionInfo = await _getVersionInfo();
      if (versionInfo == null) return null;

      final latestVersion = versionInfo['version'];

      if (_isNewerVersion(latestVersion, currentVersion)) {
        return {
          'latest_version': latestVersion,
          'apk_url': await _getApkUrl(latestVersion),
          'changelog': versionInfo['changelog'],
          'force_update': versionInfo['force_update'] ?? false,
          'file_size': versionInfo['file_size'],
          'release_date': versionInfo['release_date'],
        };
      }
      return null;
    } catch (e) {
      print('❌ OTA Check Error: $e');
      return null;
    }
  }

  // Получить информацию о версии
  static Future<Map<String, dynamic>?> _getVersionInfo() async {
    try {
      final ref = _storage.ref('ota/version.json');
      final data = await ref.getData();
      return _parseVersionData(String.fromCharCodes(data!));
    } catch (e) {
      print('❌ Version info error: $e');
      return null;
    }
  }

  static Map<String, dynamic> _parseVersionData(String data) {
    return {
      'version': '1.0.1',
      'force_update': false,
      'file_size': '15.2 MB',
      'release_date': '2024-01-15',
      'changelog': [
        '🎨 Новая иконка приложения',
        '🚀 Улучшена производительность',
        '🔔 Добавлены системные уведомления',
        '🐛 Исправлены критические ошибки',
        '📱 Оптимизация для новых устройств'
      ]
    };
  }

  // Получить URL APK
  static Future<String> _getApkUrl(String version) async {
    try {
      final ref = _storage.ref('ota/app_v$version.apk');
      return await ref.getDownloadURL();
    } catch (e) {
      print('❌ APK URL error: $e');
      rethrow;
    }
  }

  // Сравнение версий
  static bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Скачать APK
  static Future<String> downloadApk(String apkUrl, {
    required Function(double) onProgress,
  }) async {
    try {
      // Запрашиваем разрешения
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission denied');
      }

      // Создаем директорию для загрузок
      final tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/app_update_${DateTime.now().millisecondsSinceEpoch}.apk';

      // Скачиваем с прогрессом
      await _dio.download(
        apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
          }
        },
        deleteOnError: true,
      );

      return filePath;
    } catch (e) {
      print('❌ Download error: $e');
      rethrow;
    }
  }

  // Установить APK
  static Future<void> installApk(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Failed to open APK file');
      }
      print('✅ APK installation started');
    } catch (e) {
      print('❌ Installation error: $e');
      rethrow;
    }
  }

  // Получить историю версий
  static Future<List<Map<String, dynamic>>> getVersionHistory() async {
    try {
      final ref = _storage.ref('ota/version_history.json');
      final data = await ref.getData();
      final history = _parseVersionHistory(String.fromCharCodes(data!));
      return history;
    } catch (e) {
      print('❌ Version history error: $e');
      return [];
    }
  }

  static List<Map<String, dynamic>> _parseVersionHistory(String data) {
    return [
      {
        'version': '1.0.1',
        'date': '2024-01-15',
        'changes': ['Новая иконка', 'Системные уведомления']
      },
      {
        'version': '1.0.0',
        'date': '2024-01-01',
        'changes': ['Первоначальный релиз']
      }
    ];
  }
}
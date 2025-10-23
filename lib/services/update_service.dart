import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateService {
  // ЗАМЕНИТЕ на ваш реальный URL!
  static const String repoUrl =
      'https://api.github.com/tr4stfulmode/app-wishlist/releases/latest';

  static Future<void> checkAndUpdate() async {
    try {
      final response = await http.get(Uri.parse(repoUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name']?.toString().replaceAll('v', '') ?? '';
        final downloadUrl = _findApkUrl(data);

        if (await _shouldUpdate(latestVersion) && downloadUrl.isNotEmpty) {
          _showUpdateDialog(downloadUrl, data['body'] ?? '');
        }
      }
    } catch (e) {
      print('Update check failed: $e');
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

  static Future<bool> _shouldUpdate(String latestVersion) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    // Простое сравнение версий
    return latestVersion != currentVersion;
  }

  static void _showUpdateDialog(String downloadUrl, String releaseNotes) {
    // Здесь будет диалог обновления
    _downloadAndInstall(downloadUrl);
  }

  static Future<void> _downloadAndInstall(String url) async {
    try {
      // Запрашиваем разрешение на запись
      if (await Permission.storage.request().isGranted) {
        final response = await http.get(Uri.parse(url));
        final dir = await getExternalStorageDirectory();
        final file = File('${dir?.path}/update.apk');

        await file.writeAsBytes(response.bodyBytes);
        await OpenFile.open(file.path);
      }
    } catch (e) {
      print('Download failed: $e');
    }
  }
}
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class SimpleUpdateService {
  static const String repoUrl = 'https://api.github.com/repos/tr4stfulmode/releases-wishlist/releases/latest';
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _isDownloading = false;

  static Future<void> checkForUpdate() async {
    try {
      print('🎯 SIMPLE: Starting update check...');

      final response = await http.get(Uri.parse(repoUrl));
      print('🎯 SIMPLE: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name']?.toString().replaceAll('v', '') ?? '';
        final downloadUrl = _findApkUrl(data);
        final releaseNotes = data['body'] ?? 'Доступно обновление';
        final isMandatory = _checkIfMandatory(data);

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        print('🎯 SIMPLE: Current: $currentVersion, Latest: $latestVersion');
        print('🎯 SIMPLE: Download URL: ${downloadUrl.isNotEmpty}');

        if (currentVersion != latestVersion && downloadUrl.isNotEmpty) {
          print('🎯 SIMPLE: ✅ UPDATE AVAILABLE! Showing dialog...');
          _showUpdateDialog(downloadUrl, releaseNotes, isMandatory);
        } else {
          print('🎯 SIMPLE: ❌ No update needed');
        }
      }
    } catch (e) {
      print('🎯 SIMPLE: ❌ Error: $e');
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

  static void _showUpdateDialog(String downloadUrl, String releaseNotes, bool isMandatory) {
    final context = navigatorKey.currentContext;

    if (context == null) {
      print('❌ DIALOG: Cannot show dialog - no context!');
      return;
    }

    print('✅ DIALOG: Showing update dialog...');

    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (BuildContext context) {
        return _UpdateDialog(
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          isMandatory: isMandatory,
        );
      },
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String downloadUrl;
  final String releaseNotes;
  final bool isMandatory;

  const _UpdateDialog({
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isMandatory,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  bool _downloadComplete = false;

  Future<void> _downloadAndInstall() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      print('📥 Starting download from: ${widget.downloadUrl}');

      final client = http.Client();
      final request = await client.send(http.Request('GET', Uri.parse(widget.downloadUrl)));

      final contentLength = request.contentLength;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/update_${DateTime.now().millisecondsSinceEpoch}.apk');

      final ios = file.openWrite();
      int received = 0;

      await for (var data in request.stream) {
        received += data.length;
        ios.add(data);

        if (contentLength != null) {
          setState(() {
            _downloadProgress = received / contentLength;
          });
        }
      }

      await ios.close();
      client.close();

      setState(() {
        _downloadComplete = true;
        _isDownloading = false;
      });

      print('✅ Download complete: ${file.path}');

      // Устанавливаем APK
      await OpenFile.open(file.path);
      print('🚀 Opening installer...');

    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      print('❌ Download failed: $e');
      _showError('Ошибка загрузки: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _downloadComplete ? Icons.check_circle :
            widget.isMandatory ? Icons.warning_amber : Icons.system_update,
            color: _downloadComplete ? Colors.green :
            widget.isMandatory ? Colors.orange : Colors.blue,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _downloadComplete ? 'Готово к установке!' :
              widget.isMandatory ? 'Требуется обновление' : 'Доступно обновление',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _downloadComplete ? Colors.green :
                widget.isMandatory ? Colors.orange : Colors.blue,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_downloadComplete) ...[
              const Text(
                'Что нового:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.releaseNotes.length > 200
                      ? '${widget.releaseNotes.substring(0, 200)}...'
                      : widget.releaseNotes,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
              if (widget.isMandatory) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Это критическое обновление',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            if (_isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 8),
              Text(
                'Загрузка: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ],

            if (_downloadComplete) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'APK успешно скачан!\nНажмите "Установить" для обновления.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_downloadComplete && !_isDownloading && !widget.isMandatory)
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('ПОЗЖЕ'),
          ),
        ElevatedButton(
          onPressed: _isDownloading ? null : _downloadAndInstall,
          style: ElevatedButton.styleFrom(
            backgroundColor: _downloadComplete ? Colors.green :
            widget.isMandatory ? Colors.orange : Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text(
            _downloadComplete ? 'УСТАНОВИТЬ' :
            _isDownloading ? 'ЗАГРУЗКА...' :
            widget.isMandatory ? 'ОБНОВИТЬ СЕЙЧАС' : 'ОБНОВИТЬ',
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:app_wishlist/services/ota_service.dart';

class OTAUpdateDialog extends StatefulWidget {
  final Map<String, dynamic> updateInfo;

  const OTAUpdateDialog({super.key, required this.updateInfo});

  @override
  State<OTAUpdateDialog> createState() => _OTAUpdateDialogState();
}

class _OTAUpdateDialogState extends State<OTAUpdateDialog> {
  OTAUpdateState _state = OTAUpdateState.ready;
  double _downloadProgress = 0.0;
  String _downloadPath = '';

  Future<void> _startUpdate() async {
    setState(() {
      _state = OTAUpdateState.downloading;
      _downloadProgress = 0.0;
    });

    try {
      // Скачиваем APK
      final filePath = await OTAService.downloadApk(
        widget.updateInfo['apk_url'],
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      setState(() {
        _state = OTAUpdateState.installing;
        _downloadPath = filePath;
      });

      // Устанавливаем APK
      await OTAService.installApk(filePath);

      setState(() {
        _state = OTAUpdateState.completed;
      });

    } catch (e) {
      setState(() {
        _state = OTAUpdateState.error;
      });
      print('❌ Update error: $e');
    }
  }

  String _getStateText() {
    switch (_state) {
      case OTAUpdateState.ready:
        return 'Готов к обновлению';
      case OTAUpdateState.downloading:
        return 'Скачивание...';
      case OTAUpdateState.installing:
        return 'Установка...';
      case OTAUpdateState.completed:
        return 'Обновление завершено!';
      case OTAUpdateState.error:
        return 'Ошибка обновления';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isForceUpdate = widget.updateInfo['force_update'] ?? false;

    return WillPopScope(
      onWillPop: () async => !isForceUpdate && _state == OTAUpdateState.ready,
      child: AlertDialog(
        title: _buildTitle(),
        content: _buildContent(),
        actions: _buildActions(isForceUpdate),
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        _getStateIcon(),
        const SizedBox(width: 8),
        Text(
          _getTitleText(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    );
  }

  Widget _getStateIcon() {
    switch (_state) {
      case OTAUpdateState.ready:
        return const Icon(Icons.system_update, color: Colors.blue);
      case OTAUpdateState.downloading:
        return const Icon(Icons.download, color: Colors.orange);
      case OTAUpdateState.installing:
        return const Icon(Icons.install_desktop, color: Colors.purple);
      case OTAUpdateState.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case OTAUpdateState.error:
        return const Icon(Icons.error, color: Colors.red);
    }
  }

  String _getTitleText() {
    switch (_state) {
      case OTAUpdateState.ready:
        return 'Доступно обновление! 🚀';
      case OTAUpdateState.downloading:
        return 'Скачивание... 📥';
      case OTAUpdateState.installing:
        return 'Установка... ⚙️';
      case OTAUpdateState.completed:
        return 'Готово! ✅';
      case OTAUpdateState.error:
        return 'Ошибка! ❌';
    }
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_state == OTAUpdateState.ready) ..._buildUpdateInfo(),
          if (_state == OTAUpdateState.downloading) ..._buildDownloadProgress(),
          if (_state == OTAUpdateState.installing) _buildInstalling(),
          if (_state == OTAUpdateState.completed) _buildCompleted(),
          if (_state == OTAUpdateState.error) _buildError(),
        ],
      ),
    );
  }

  List<Widget> _buildUpdateInfo() {
    return [
      Text('Версия ${widget.updateInfo['latest_version']}'),
      if (widget.updateInfo['file_size'] != null)
        Text('Размер: ${widget.updateInfo['file_size']}'),
      const SizedBox(height: 12),
      const Text('Что нового:', style: TextStyle(fontWeight: FontWeight.bold)),
      ..._buildChangelog(),
    ];
  }

  List<Widget> _buildDownloadProgress() {
    return [
      Text(_getStateText()),
      const SizedBox(height: 16),
      LinearProgressIndicator(value: _downloadProgress),
      const SizedBox(height: 8),
      Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
      const SizedBox(height: 8),
      Text(
        'Не закрывайте приложение во время загрузки',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    ];
  }

  Widget _buildInstalling() {
    return Column(
      children: [
        const Text('Запуск установки...'),
        const SizedBox(height: 16),
        const CircularProgressIndicator(),
        const SizedBox(height: 8),
        Text(
          'Следуйте инструкциям установщика',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCompleted() {
    return const Column(
      children: [
        Icon(Icons.check_circle, color: Colors.green, size: 48),
        SizedBox(height: 16),
        Text('Обновление успешно установлено!'),
        Text('Приложение будет перезапущено.'),
      ],
    );
  }

  Widget _buildError() {
    return const Column(
      children: [
        Icon(Icons.error_outline, color: Colors.red, size: 48),
        SizedBox(height: 16),
        Text('Произошла ошибка при обновлении.'),
        Text('Попробуйте позже или установите вручную.'),
      ],
    );
  }

  List<Widget> _buildChangelog() {
    final changelog = widget.updateInfo['changelog'] as List<dynamic>?;
    if (changelog == null) return [const Text('• Улучшения и исправления')];

    return changelog
        .map<Widget>((item) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('• $item'),
    ))
        .toList();
  }

  List<Widget> _buildActions(bool isForceUpdate) {
    switch (_state) {
      case OTAUpdateState.ready:
        return [
          if (!isForceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ПОЗЖЕ'),
            ),
          ElevatedButton(
            onPressed: _startUpdate,
            child: const Text('ОБНОВИТЬ'),
          ),
        ];

      case OTAUpdateState.downloading:
      case OTAUpdateState.installing:
        return [const LinearProgressIndicator()];

      case OTAUpdateState.completed:
        return [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ];

      case OTAUpdateState.error:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            onPressed: _startUpdate,
            child: const Text('ПОВТОРИТЬ'),
          ),
        ];
    }
  }
}

enum OTAUpdateState {
  ready,
  downloading,
  installing,
  completed,
  error,
}
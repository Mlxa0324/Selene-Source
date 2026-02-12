import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 移动端后台下载前台服务桥接（当前仅 Android 生效）
class MobileBackgroundDownloadService {
  static const MethodChannel _channel =
      MethodChannel('org.moontechlab.selene/background_download');

  static bool get _isAndroidMobile => !kIsWeb && Platform.isAndroid;

  static Future<void> syncForegroundService({
    required int downloadingCount,
    required int queuedCount,
  }) async {
    if (!_isAndroidMobile) return;

    try {
      if (downloadingCount > 0 || queuedCount > 0) {
        await _channel.invokeMethod('startForegroundDownloadService', {
          'downloadingCount': downloadingCount,
          'queuedCount': queuedCount,
        });
      } else {
        await _channel.invokeMethod('stopForegroundDownloadService');
      }
    } catch (e) {
      debugPrint('同步 Android 后台下载前台服务失败: $e');
    }
  }
}

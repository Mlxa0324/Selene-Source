import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SleepTimerService {
  static const MethodChannel _channel =
      MethodChannel('org.moontechlab.selene/sleep_timer');

  static bool get supportsAppExit => Platform.isAndroid;

  static bool get supportsScreenOffPlayback =>
      Platform.isAndroid || Platform.isIOS;

  static String get timeoutActionLabel => supportsAppExit ? '退出应用' : '停止播放';

  static Future<bool> closeApp() async {
    if (!supportsAppExit) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('closeApp');
      return result ?? false;
    } catch (e) {
      debugPrint('关闭应用失败: $e');
      return false;
    }
  }
}

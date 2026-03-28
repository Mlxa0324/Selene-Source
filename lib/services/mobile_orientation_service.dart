import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:selene/utils/fullscreen_orientation_policy.dart';

abstract class MobileOrientationServiceProtocol {
  Future<bool?> getSystemAutoRotateEnabled();
  Future<MobileInterfaceOrientation> getCurrentInterfaceOrientation();
}

class MobileOrientationService implements MobileOrientationServiceProtocol {
  const MobileOrientationService();

  static const MethodChannel _channel = MethodChannel('selene/orientation');

  @override
  Future<bool?> getSystemAutoRotateEnabled() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      return await _channel.invokeMethod<bool>('getSystemAutoRotateEnabled');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MobileInterfaceOrientation> getCurrentInterfaceOrientation() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return MobileInterfaceOrientation.unknown;
    }
    try {
      final raw = await _channel.invokeMethod<String>(
        'getCurrentInterfaceOrientation',
      );
      return MobileInterfaceOrientation.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => MobileInterfaceOrientation.unknown,
      );
    } catch (_) {
      return MobileInterfaceOrientation.unknown;
    }
  }
}

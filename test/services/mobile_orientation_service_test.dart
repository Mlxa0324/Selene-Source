import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/mobile_orientation_service.dart';
import 'package:selene/utils/fullscreen_orientation_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns null when Android auto-rotate cannot be read', () async {
    const channel = MethodChannel('selene/orientation');
    final invokedMethods = <String>[];

    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      invokedMethods.add(call.method);
      throw PlatformException(code: 'unavailable');
    });

    expect(
      await const MobileOrientationService().getSystemAutoRotateEnabled(),
      isNull,
    );
    expect(invokedMethods, ['getSystemAutoRotateEnabled']);
  });

  test('returns true when Android auto-rotate is enabled', () async {
    const channel = MethodChannel('selene/orientation');
    final invokedMethods = <String>[];

    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      invokedMethods.add(call.method);
      if (call.method == 'getSystemAutoRotateEnabled') {
        return true;
      }
      return null;
    });

    expect(
      await const MobileOrientationService().getSystemAutoRotateEnabled(),
      isTrue,
    );
    expect(invokedMethods, ['getSystemAutoRotateEnabled']);
  });

  test('returns false when Android auto-rotate is disabled', () async {
    const channel = MethodChannel('selene/orientation');
    final invokedMethods = <String>[];

    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      invokedMethods.add(call.method);
      if (call.method == 'getSystemAutoRotateEnabled') {
        return false;
      }
      return null;
    });

    expect(
      await const MobileOrientationService().getSystemAutoRotateEnabled(),
      isFalse,
    );
    expect(invokedMethods, ['getSystemAutoRotateEnabled']);
  });

  test('maps channel orientation strings into enum values', () async {
    const channel = MethodChannel('selene/orientation');
    final invokedMethods = <String>[];

    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      invokedMethods.add(call.method);
      if (call.method == 'getCurrentInterfaceOrientation') {
        return 'landscapeLeft';
      }
      return null;
    });

    expect(
      await const MobileOrientationService().getCurrentInterfaceOrientation(),
      MobileInterfaceOrientation.landscapeLeft,
    );
    expect(invokedMethods, ['getCurrentInterfaceOrientation']);
  });

  test('reads current interface orientation on iOS through channel', () async {
    const channel = MethodChannel('selene/orientation');
    final invokedMethods = <String>[];

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      invokedMethods.add(call.method);
      if (call.method == 'getCurrentInterfaceOrientation') {
        return 'portraitUp';
      }
      return null;
    });

    expect(
      await const MobileOrientationService().getCurrentInterfaceOrientation(),
      MobileInterfaceOrientation.portraitUp,
    );
    expect(invokedMethods, ['getCurrentInterfaceOrientation']);
  });

  test('returns unknown when current interface orientation cannot be read',
      () async {
    const channel = MethodChannel('selene/orientation');
    final invokedMethods = <String>[];

    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      invokedMethods.add(call.method);
      throw PlatformException(code: 'unavailable');
    });

    expect(
      await const MobileOrientationService().getCurrentInterfaceOrientation(),
      MobileInterfaceOrientation.unknown,
    );
    expect(invokedMethods, ['getCurrentInterfaceOrientation']);
  });

  test('maps physical orientation stream strings into enum values', () async {
    const channel = EventChannel('selene/physical_orientation');
    final events = <ByteData?>[
      const StandardMethodCodec().encodeSuccessEnvelope('portraitUp'),
      const StandardMethodCodec().encodeSuccessEnvelope('landscapeRight'),
      const StandardMethodCodec().encodeSuccessEnvelope('landscapeRight'),
      const StandardMethodCodec().encodeSuccessEnvelope('unknown'),
    ];

    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel.name, null);
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel.name, (message) async {
      for (final event in events) {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(channel.name, event, (_) {});
      }
      return const StandardMethodCodec().encodeSuccessEnvelope(null);
    });

    await expectLater(
      const MobileOrientationService().watchPhysicalDeviceOrientation(),
      emitsInOrder([
        MobileInterfaceOrientation.portraitUp,
        MobileInterfaceOrientation.landscapeRight,
      ]),
    );
  });

  test('reads physical orientation stream on iOS', () async {
    const channel = EventChannel('selene/physical_orientation');
    final events = <ByteData?>[
      const StandardMethodCodec().encodeSuccessEnvelope('landscapeLeft'),
    ];

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel.name, null);
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel.name, (message) async {
      for (final event in events) {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(channel.name, event, (_) {});
      }
      return const StandardMethodCodec().encodeSuccessEnvelope(null);
    });

    await expectLater(
      const MobileOrientationService().watchPhysicalDeviceOrientation(),
      emits(MobileInterfaceOrientation.landscapeLeft),
    );
  });
}

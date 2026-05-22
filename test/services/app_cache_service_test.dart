import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/app_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formats cache bytes for settings display', () {
    expect(AppCacheService.formatBytes(0), '0 B');
    expect(AppCacheService.formatBytes(512), '512 B');
    expect(AppCacheService.formatBytes(1536), '1.5 KB');
    expect(AppCacheService.formatBytes(5 * 1024 * 1024), '5.0 MB');
  });

  test('disables image disk cache when available storage is below threshold',
      () async {
    final service = AppCacheService(
      availableStorageLoader: () async =>
          AppCacheService.lowStorageThresholdBytes - 1,
    );

    expect(await service.shouldUseImageDiskCache(), isFalse);
  });

  test('keeps image disk cache when storage cannot be resolved', () async {
    final service = AppCacheService(
      availableStorageLoader: () async => null,
    );

    expect(await service.shouldUseImageDiskCache(), isTrue);
  });

  test('calculates cache size from injected cache directories', () async {
    final tempDir = await Directory.systemTemp.createTemp('selene_cache_test_');
    final nestedDir = Directory('${tempDir.path}/nested');
    await nestedDir.create();
    await File('${tempDir.path}/a.bin').writeAsBytes(List.filled(8, 1));
    await File('${nestedDir.path}/b.bin').writeAsBytes(List.filled(12, 1));

    final service = AppCacheService(
      cacheDirectoriesLoader: () async => [tempDir],
    );

    expect(await service.calculateCacheSizeBytes(), 20);

    await tempDir.delete(recursive: true);
  });

  test('startup cleanup clears business caches but preserves image disk cache',
      () async {
    var businessCleared = false;
    var imageCleared = false;
    final service = AppCacheService(
      businessCacheClearer: () async {
        businessCleared = true;
      },
      imageDiskCacheClearer: () async {
        imageCleared = true;
      },
      availableStorageLoader: () async =>
          AppCacheService.lowStorageThresholdBytes + 1,
    );

    await service.prepareBeforeAppEnter();

    expect(businessCleared, isTrue);
    expect(imageCleared, isFalse);
  });

  test('startup cleanup clears image disk cache when storage is low', () async {
    var imageCleared = false;
    final service = AppCacheService(
      businessCacheClearer: () async {},
      imageDiskCacheClearer: () async {
        imageCleared = true;
      },
      availableStorageLoader: () async =>
          AppCacheService.lowStorageThresholdBytes - 1,
    );

    await service.prepareBeforeAppEnter();

    expect(imageCleared, isTrue);
  });
}

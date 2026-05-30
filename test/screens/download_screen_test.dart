import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selene/models/download_task.dart';
import 'package:selene/models/play_record.dart';
import 'package:selene/screens/download_screen.dart';
import 'package:selene/services/app_cache_service.dart';
import 'package:selene/services/download_service.dart';
import 'package:selene/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'resolveContinueTaskForDownloadGroup prefers the latest saved play record',
      () {
    final first = DownloadTask(
      id: 'ep1',
      url: 'https://example.com/1.m3u8',
      title: '测试剧',
      subtitle: '第1集',
      episodeIndex: 0,
      cover: 'https://example.com/cover.jpg',
      savePath: '/tmp/1',
      createdAt: DateTime(2026, 5, 5),
      status: DownloadStatus.completed,
    );
    final second = DownloadTask(
      id: 'ep2',
      url: 'https://example.com/2.m3u8',
      title: '测试剧',
      subtitle: '第2集',
      episodeIndex: 1,
      cover: 'https://example.com/cover.jpg',
      savePath: '/tmp/2',
      createdAt: DateTime(2026, 5, 5),
      status: DownloadStatus.completed,
    );

    final result = resolveContinueTaskForDownloadGroup(
      group: [first, second],
      records: [
        PlayRecord(
          id: 'ep1',
          source: 'local',
          title: '测试剧',
          sourceName: '本地缓存',
          year: '',
          cover: '',
          index: 1,
          totalEpisodes: 2,
          playTime: 120,
          totalTime: 1500,
          saveTime: 100,
          searchTitle: '',
        ),
        PlayRecord(
          id: 'ep2',
          source: 'local',
          title: '测试剧',
          sourceName: '本地缓存',
          year: '',
          cover: '',
          index: 2,
          totalEpisodes: 2,
          playTime: 30,
          totalTime: 1500,
          saveTime: 200,
          searchTitle: '',
        ),
      ],
    );

    expect(result?.id, 'ep2');
  });

  test('resolveContinueTaskForDownloadGroup falls back to first episode', () {
    final first = DownloadTask(
      id: 'ep1',
      url: 'https://example.com/1.m3u8',
      title: '测试剧',
      subtitle: '第1集',
      episodeIndex: 0,
      cover: 'https://example.com/cover.jpg',
      savePath: '/tmp/1',
      createdAt: DateTime(2026, 5, 5),
      status: DownloadStatus.completed,
    );
    final second = DownloadTask(
      id: 'ep2',
      url: 'https://example.com/2.m3u8',
      title: '测试剧',
      subtitle: '第2集',
      episodeIndex: 1,
      cover: 'https://example.com/cover.jpg',
      savePath: '/tmp/2',
      createdAt: DateTime(2026, 5, 5),
      status: DownloadStatus.completed,
    );

    final result = resolveContinueTaskForDownloadGroup(
      group: [first, second],
      records: const [],
    );

    expect(result?.id, 'ep1');
  });

  testWidgets('shows delete group action and confirmation for completed tasks',
      (tester) async {
    final downloadService = DownloadService();
    await downloadService.deleteTasks(
      downloadService.tasks.map((task) => task.id).toList(),
    );
    await downloadService.addTask(_buildTask(
      id: 'ep1',
      title: '测试剧',
      subtitle: '第1集',
      status: DownloadStatus.completed,
    ));
    await downloadService.addTask(_buildTask(
      id: 'ep2',
      title: '测试剧',
      subtitle: '第2集',
      status: DownloadStatus.completed,
    ));

    await _pumpDownloadScreen(tester, downloadService);

    await tester.tap(find.text('已完成 (2)'));
    await _pumpFrames(tester);

    expect(find.text('删除整部'), findsOneWidget);
    await tester.tap(find.text('删除整部'));
    await _pumpFrames(tester);

    expect(find.text('删除整部'), findsNWidgets(2));
    expect(find.textContaining('确定要删除 "测试剧" 的 2 集缓存吗？'), findsOneWidget);
  });

  testWidgets('shows storage summary and low space warning', (tester) async {
    final downloadService = DownloadService();
    await downloadService.deleteTasks(
      downloadService.tasks.map((task) => task.id).toList(),
    );

    await _pumpDownloadScreen(tester, downloadService);

    expect(find.text('剩余 300.0 MB / 总量 64.0 GB'), findsOneWidget);
    expect(find.textContaining('剩余空间低于 500.0 MB'), findsOneWidget);
  });
}

Future<void> _pumpDownloadScreen(
  WidgetTester tester,
  DownloadService downloadService,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>(
          create: (_) => ThemeService(),
        ),
        ChangeNotifierProvider<DownloadService>.value(value: downloadService),
      ],
      child: MaterialApp(
        home: DownloadScreen(
          storageSummaryLoader: () async => const AppStorageSummary(
            availableBytes: 300 * 1024 * 1024,
            totalBytes: 64 * 1024 * 1024 * 1024,
            lowStorageThresholdBytes: AppCacheService.lowStorageThresholdBytes,
          ),
        ),
      ),
    ),
  );
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

DownloadTask _buildTask({
  required String id,
  required String title,
  required String subtitle,
  required DownloadStatus status,
}) {
  return DownloadTask(
    id: id,
    url: 'https://example.com/$id.m3u8',
    title: title,
    subtitle: subtitle,
    episodeIndex: 0,
    cover: 'https://example.com/cover.jpg',
    savePath: '/tmp/$id',
    createdAt: DateTime(2026, 5, 30),
    status: status,
  );
}

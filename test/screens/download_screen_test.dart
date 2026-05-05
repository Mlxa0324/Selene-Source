import 'package:flutter_test/flutter_test.dart';

import 'package:selene/models/download_task.dart';
import 'package:selene/models/play_record.dart';
import 'package:selene/screens/download_screen.dart';

void main() {
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
}

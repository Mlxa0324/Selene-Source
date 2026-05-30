import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selene/models/download_task.dart';
import 'package:selene/services/download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleteTasks deletes multiple tasks with a single state refresh',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('selene_download_delete_');
    final firstDir = Directory('${tempDir.path}/ep1');
    final secondDir = Directory('${tempDir.path}/ep2');
    final keepDir = Directory('${tempDir.path}/keep');

    await firstDir.create(recursive: true);
    await secondDir.create(recursive: true);
    await keepDir.create(recursive: true);
    await File('${firstDir.path}/index.m3u8').writeAsString('#EXTM3U');
    await File('${secondDir.path}/index.m3u8').writeAsString('#EXTM3U');
    await File('${keepDir.path}/index.m3u8').writeAsString('#EXTM3U');

    final tasks = [
      _buildTask(
          id: 'ep1', savePath: firstDir.path, status: DownloadStatus.paused),
      _buildTask(
          id: 'ep2', savePath: secondDir.path, status: DownloadStatus.failed),
      _buildTask(
          id: 'keep', savePath: keepDir.path, status: DownloadStatus.paused),
    ];

    SharedPreferences.setMockInitialValues({
      'download_tasks': jsonEncode(
        tasks.map((task) => task.toJson()).toList(),
      ),
    });

    final service = DownloadService();
    await service.init();

    var notifyCount = 0;
    service.addListener(() {
      notifyCount++;
    });

    await service.deleteTasks(['ep1', 'ep2']);

    expect(service.tasks.map((task) => task.id).toList(), ['keep']);
    expect(await firstDir.exists(), isFalse);
    expect(await secondDir.exists(), isFalse);
    expect(await keepDir.exists(), isTrue);
    expect(notifyCount, 1);

    final prefs = await SharedPreferences.getInstance();
    final storedJson = prefs.getString('download_tasks');
    expect(storedJson, isNotNull);
    final storedTasks = (jsonDecode(storedJson!) as List<dynamic>)
        .map((json) => DownloadTask.fromJson(json as Map<String, dynamic>))
        .toList();
    expect(storedTasks.map((task) => task.id).toList(), ['keep']);

    await tempDir.delete(recursive: true);
  });
}

/// 构建下载任务测试数据，保持持久化字段与真实任务一致。
DownloadTask _buildTask({
  required String id,
  required String savePath,
  DownloadStatus status = DownloadStatus.queued,
}) {
  return DownloadTask(
    id: id,
    url: 'https://example.com/$id.m3u8',
    title: '测试剧集',
    subtitle: '第$id集',
    episodeIndex: 0,
    cover: 'https://example.com/cover.jpg',
    status: status,
    savePath: savePath,
    createdAt: DateTime(2026, 5, 30),
  );
}

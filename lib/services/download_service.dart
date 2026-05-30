import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_task.dart';
import 'mobile_background_download_service.dart';

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final List<DownloadTask> _tasks = [];
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, int> _retryCounts = {};
  final Map<String, Future<String>> _localPlaybackPathResolutions = {};

  static const int _maxRetryCount = 3;

  void _syncBackgroundService() {
    final downloadingCount =
        _tasks.where((t) => t.status == DownloadStatus.downloading).length;
    final queuedCount =
        _tasks.where((t) => t.status == DownloadStatus.queued).length;

    unawaited(
      MobileBackgroundDownloadService.syncForegroundService(
        downloadingCount: downloadingCount,
        queuedCount: queuedCount,
      ),
    );
  }

  bool _isRetriableError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return true;
      }
      final errText = error.error?.toString().toLowerCase() ?? '';
      if (errText.contains('socket') || errText.contains('network')) {
        return true;
      }
      return false;
    }

    final text = error.toString().toLowerCase();
    return text.contains('socket') || text.contains('network');
  }

  Future<String?> _findFfmpeg() async {
    try {
      final result = await Process.run(
        'ffmpeg',
        ['-version'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        return 'ffmpeg';
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _concatSegmentsToTs(DownloadTask task, int totalSegments) async {
    try {
      final segmentFiles = <File>[];
      for (var i = 0; i < totalSegments; i++) {
        final segFile = File("${task.savePath}/seg_$i.ts");
        if (await segFile.exists()) {
          segmentFiles.add(segFile);
        }
      }
      return await _concatSegmentFilesToTs(task.savePath, segmentFiles);
    } catch (e) {
      debugPrint('合并成 ts 失败: $e');
      return false;
    }
  }

  Future<bool> _concatSegmentFilesToTs(
    String savePath,
    List<File> segmentFiles,
  ) async {
    if (segmentFiles.isEmpty) {
      return false;
    }

    IOSink? sink;
    final tempOutputFile = File("$savePath/merged.ts.part");
    final outputFile = File("$savePath/merged.ts");

    try {
      if (await tempOutputFile.exists()) {
        await tempOutputFile.delete();
      }
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      sink = tempOutputFile.openWrite();
      for (final segmentFile in segmentFiles) {
        await sink.addStream(segmentFile.openRead());
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (!await tempOutputFile.exists()) {
        return false;
      }

      await tempOutputFile.rename(outputFile.path);
      return await outputFile.exists();
    } catch (e) {
      debugPrint('合并 ts 分片失败: $e');
      try {
        await sink?.close();
      } catch (_) {}
      if (await tempOutputFile.exists()) {
        await tempOutputFile.delete();
      }
      return false;
    }
  }

  Future<List<File>> _listSegmentFiles(String savePath) async {
    final directory = Directory(savePath);
    if (!await directory.exists()) {
      return const <File>[];
    }

    final files = <File>[];
    final matcher = RegExp(r'^seg_(\d+)\.ts$');

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : entity.path.split(Platform.pathSeparator).last;
      if (matcher.hasMatch(name)) {
        files.add(entity);
      }
    }

    files.sort((a, b) {
      final aName = a.uri.pathSegments.last;
      final bName = b.uri.pathSegments.last;
      final aIndex = int.parse(matcher.firstMatch(aName)!.group(1)!);
      final bIndex = int.parse(matcher.firstMatch(bName)!.group(1)!);
      return aIndex.compareTo(bIndex);
    });

    return files;
  }

  Future<String> resolveOptimizedLocalPlaybackPath(String inputPath) {
    final normalizedInput = inputPath.trim();
    if (normalizedInput.isEmpty || normalizedInput.startsWith('http')) {
      return Future.value(inputPath);
    }

    final savePath = File(normalizedInput).parent.path;
    return _localPlaybackPathResolutions.putIfAbsent(savePath, () async {
      try {
        final mergedMp4File = File("$savePath/merged.mp4");
        if (await mergedMp4File.exists() && await mergedMp4File.length() > 0) {
          return mergedMp4File.path;
        }

        final mergedTsFile = File("$savePath/merged.ts");
        if (await mergedTsFile.exists() && await mergedTsFile.length() > 0) {
          return mergedTsFile.path;
        }

        if (!normalizedInput.endsWith('index.m3u8')) {
          return normalizedInput;
        }

        final segmentFiles = await _listSegmentFiles(savePath);
        if (segmentFiles.isEmpty) {
          return normalizedInput;
        }

        final merged = await _concatSegmentFilesToTs(savePath, segmentFiles);
        if (merged &&
            await mergedTsFile.exists() &&
            await mergedTsFile.length() > 0) {
          debugPrint('已为本地播放生成 merged.ts: ${mergedTsFile.path}');
          return mergedTsFile.path;
        }

        return normalizedInput;
      } finally {
        _localPlaybackPathResolutions.remove(savePath);
      }
    });
  }

  Future<bool> _tryMergeSegmentsToMp4(
      DownloadTask task, int totalSegments) async {
    final bool isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    if (isDesktop) {
      final ffmpeg = await _findFfmpeg();
      if (ffmpeg != null) {
        try {
          final concatFile = File("${task.savePath}/concat.txt");
          final buffer = StringBuffer();
          for (var i = 0; i < totalSegments; i++) {
            final segFile = File("${task.savePath}/seg_$i.ts");
            if (await segFile.exists()) {
              buffer.writeln("file 'seg_$i.ts'");
            }
          }
          if (buffer.length == 0) return false;

          await concatFile.writeAsString(buffer.toString());

          final outputPath = "${task.savePath}/merged.mp4";
          final result = await Process.run(
            ffmpeg,
            [
              '-y',
              '-f',
              'concat',
              '-safe',
              '0',
              '-i',
              concatFile.path,
              '-c',
              'copy',
              outputPath
            ],
            workingDirectory: task.savePath,
            runInShell: true,
          );
          if (result.exitCode == 0) {
            return true; // ffmpeg 合并成功，无需再合 TS
          }
          debugPrint('ffmpeg 合并失败: ${result.stderr}');
        } catch (e) {
          debugPrint('ffmpeg 合并异常: $e');
        }
      }
    }

    // 所有平台：合并分片为单个 ts 文件，确保播放时无需临时合并
    debugPrint('合并分片为单个 ts 文件');
    return await _concatSegmentsToTs(task, totalSegments);
  }

  List<DownloadTask> get tasks => _tasks;

  static const String _tasksKey = 'download_tasks';

  Future<void> init() async {
    await _loadTasks();
    // 恢复之前的状态，如果是下载中则改为暂停
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].status == DownloadStatus.downloading) {
        _tasks[i] = _tasks[i].copyWith(status: DownloadStatus.paused);
      }
      // 如果已完成但没有文件大小信息，则尝试计算
      if (_tasks[i].status == DownloadStatus.completed &&
          _tasks[i].fileSize == null) {
        final size = await _calculateDirSize(Directory(_tasks[i].savePath));
        if (size > 0) {
          _tasks[i] = _tasks[i].copyWith(fileSize: size);
        }
      }
    }
    notifyListeners();
    _syncBackgroundService();

    // 后台修复旧版本下载：为已完成的下载补充 merged.ts
    unawaited(_repairLegacyCompletedDownloads());
  }

  /// 修复旧版本下载：为已下载完成但没有 merged.ts 或 merged.mp4 的任务补充合并
  Future<void> _repairLegacyCompletedDownloads() async {
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.status != DownloadStatus.completed) continue;

      final mergedMp4 = File("${task.savePath}/merged.mp4");
      final mergedTs = File("${task.savePath}/merged.ts");
      if ((await mergedMp4.exists() && await mergedMp4.length() > 0) ||
          (await mergedTs.exists() && await mergedTs.length() > 0)) {
        continue; // 已有合并文件，跳过
      }

      final segmentFiles = await _listSegmentFiles(task.savePath);
      if (segmentFiles.isEmpty) continue;

      debugPrint('修复旧版本下载: ${task.title} - ${task.subtitle}');
      await _concatSegmentFilesToTs(task.savePath, segmentFiles);
    }
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_tasksKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _tasks.clear();
      _tasks.addAll(jsonList.map((e) => DownloadTask.fromJson(e)).toList());
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_tasks.map((e) => e.toJson()).toList());
    await prefs.setString(_tasksKey, jsonString);
  }

  Future<void> addTask(DownloadTask task) async {
    // 检查是否已存在
    if (_tasks.any((t) => t.id == task.id)) {
      return;
    }
    _tasks.add(task);
    await _saveTasks();
    notifyListeners();
    _syncBackgroundService();
    _checkQueue(); // 尝试从队列启动
  }

  void pauseTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1 && _tasks[index].status == DownloadStatus.downloading) {
      _cancelTokens[id]?.cancel("User paused");
      _tasks[index] = _tasks[index].copyWith(status: DownloadStatus.paused);
      _tasks[index].speed = 0; // 重置速度
      _saveTasks();
      notifyListeners();
      _syncBackgroundService();
      _checkQueue(); // 腾出一个位置，检查队列
    }
  }

  void resumeTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1 &&
        (_tasks[index].status == DownloadStatus.paused ||
            _tasks[index].status == DownloadStatus.failed)) {
      _tasks[index] = _tasks[index].copyWith(status: DownloadStatus.queued);
      _saveTasks();
      notifyListeners();
      _syncBackgroundService();
      _checkQueue(); // 加入队列等待调度
    }
  }

  /// 检查并调度下载队列
  void _checkQueue() {
    _syncBackgroundService();

    // 统计当前正在下载的任务
    int downloadingCount =
        _tasks.where((t) => t.status == DownloadStatus.downloading).length;

    // 如果下载中的任务已达3个，则不再启动新任务
    if (downloadingCount >= 3) return;

    // 查找处于等待中的任务
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].status == DownloadStatus.queued) {
        _startDownload(_tasks[i].id);
        downloadingCount++;
        if (downloadingCount >= 3) break;
      }
    }

    _syncBackgroundService();
  }

  Future<void> deleteTask(String id) async {
    await deleteTasks([id]);
  }

  /// 批量删除下载任务，统一处理状态刷新、持久化和本地文件清理。
  Future<void> deleteTasks(Iterable<String> ids) async {
    final targetIds = ids.toSet();
    if (targetIds.isEmpty) {
      return;
    }

    final deletedTasks = <DownloadTask>[];
    _tasks.removeWhere((task) {
      final shouldDelete = targetIds.contains(task.id);
      if (shouldDelete) {
        _cancelTokens[task.id]?.cancel("User deleted");
        deletedTasks.add(task);
      }
      return shouldDelete;
    });

    if (deletedTasks.isEmpty) {
      return;
    }

    await _saveTasks();
    notifyListeners();

    for (final task in deletedTasks) {
      _retryCounts.remove(task.id);
      _cancelTokens.remove(task.id);
    }

    _syncBackgroundService();
    _checkQueue(); // 删除后也检查队列

    for (final task in deletedTasks) {
      try {
        final dir = Directory(task.savePath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint("Error deleting download directory: $e");
      }
    }
  }

  Future<void> _startDownload(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    var task = _tasks[index];
    if (task.status == DownloadStatus.completed) return;

    _tasks[index] = task.copyWith(status: DownloadStatus.downloading);
    notifyListeners();
    _syncBackgroundService();

    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    try {
      final saveDir = Directory(task.savePath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 1. 获取真正的 M3U8 内容（处理多级 M3U8）
      String currentUrl = task.url;
      String m3u8Content = '';
      List<String> segmentUrls = [];

      // 循环解析直到找到包含分片的 M3U8
      int maxRedirects = 3;
      while (maxRedirects > 0) {
        final response = await _dio.get(currentUrl, cancelToken: cancelToken);
        m3u8Content = response.data.toString();
        final lines = m3u8Content.split('\n');

        bool hasSegments = false;
        bool hasSubPlaylist = false;
        String? firstSubPlaylist;

        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          if (!trimmed.startsWith('#')) {
            if (trimmed.contains('.m3u8')) {
              hasSubPlaylist = true;
              firstSubPlaylist = _resolveUrl(trimmed, currentUrl);
            } else {
              hasSegments = true;
            }
          }
        }

        if (hasSegments) {
          // 找到了真正的分片列表
          for (var line in lines) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
              segmentUrls.add(_resolveUrl(trimmed, currentUrl));
            }
          }
          break;
        } else if (hasSubPlaylist && firstSubPlaylist != null) {
          // 跳转到子播放列表
          currentUrl = firstSubPlaylist;
          maxRedirects--;
        } else {
          throw Exception("无法解析 M3U8 内容或未找到有效分片");
        }
      }

      if (segmentUrls.isEmpty) {
        throw Exception("No segments found in M3U8");
      }

      _tasks[index] = _tasks[index].copyWith(totalSegments: segmentUrls.length);
      notifyListeners();

      // 3. 统计已下载进度和大小（支持断点续传）
      int downloaded = 0;
      int initialSize = 0;
      for (var i = 0; i < segmentUrls.length; i++) {
        final segmentFile = File("${task.savePath}/seg_$i.ts");
        if (await segmentFile.exists()) {
          downloaded++;
          initialSize += await segmentFile.length();
        }
      }

      _tasks[index] = _tasks[index].copyWith(
        downloadedSegments: downloaded,
        progress: downloaded / segmentUrls.length,
        currentSize: initialSize,
      );
      notifyListeners();

      // 并发下载，限制并发数为 3
      const int maxConcurrent = 3;
      final List<int> pendingIndices = [];
      for (var i = 0; i < segmentUrls.length; i++) {
        final segmentFile = File("${task.savePath}/seg_$i.ts");
        if (!await segmentFile.exists()) {
          pendingIndices.add(i);
        }
      }

      int activeDownloads = 0;
      final completer = Completer<void>();

      // 用于计算速度
      DateTime lastUpdateTime = DateTime.now();
      int lastDownloadedSize = initialSize; // 关键修复：从当前已下载的大小开始计算增量

      void downloadNext() async {
        if (pendingIndices.isEmpty) {
          if (activeDownloads == 0 && !completer.isCompleted) {
            completer.complete();
          }
          return;
        }

        if (activeDownloads >= maxConcurrent) return;

        final i = pendingIndices.removeAt(0);
        activeDownloads++;

        try {
          final segmentUrl = segmentUrls[i];
          final segmentFile = File("${task.savePath}/seg_$i.ts");

          await _dio.download(
            segmentUrl,
            segmentFile.path,
            cancelToken: cancelToken,
          );

          downloaded++;

          // 获取文件大小以更新已下载字节数
          final segSize = await segmentFile.length();

          // 更新进度和大小
          final currentIndex = _tasks.indexWhere((t) => t.id == id);
          if (currentIndex != -1) {
            final now = DateTime.now();

            // 始终在内存中累加最新的数据，但不一定要立即同步给 UI 任务对象
            // 我们通过一个临时变量来追踪真实的下载总量
            _tasks[currentIndex].currentSize += segSize;

            final interval = now.difference(lastUpdateTime).inMilliseconds;
            if (interval >= 1500) {
              final currentTotalSize = _tasks[currentIndex].currentSize;
              double newSpeed =
                  (currentTotalSize - lastDownloadedSize) / (interval / 1000.0);

              lastUpdateTime = now;
              lastDownloadedSize = currentTotalSize;

              // 只有达到间隔时，才创建新的 Task 对象并通知 UI
              _tasks[currentIndex] = _tasks[currentIndex].copyWith(
                downloadedSegments: downloaded,
                progress: downloaded / segmentUrls.length,
                currentSize: currentTotalSize,
                speed: newSpeed,
              );
              notifyListeners();
            }
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
          return;
        } finally {
          activeDownloads--;
          downloadNext();
        }
      }

      // 启动初始并发
      for (var i = 0; i < maxConcurrent && pendingIndices.isNotEmpty; i++) {
        downloadNext();
      }

      await completer.future;

      // 4. 生成本地 M3U8 文件
      final localM3u8File = File("${task.savePath}/index.m3u8");
      final localLines = <String>[];
      int segIdx = 0;
      final finalLines = m3u8Content.split('\n'); // 使用最后解析成功的 m3u8 内容
      for (var line in finalLines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          localLines.add("seg_$segIdx.ts");
          segIdx++;
        } else {
          // 移除所有可能导致播放器尝试联网的标签，除了密钥标签
          if (!trimmed.startsWith('#EXT-X-KEY')) {
            localLines.add(line);
          } else {
            // 如果有加密，目前我们只是简单保留标签，实际上可能需要处理 Key 的下载
            localLines.add(line);
          }
        }
      }
      await localM3u8File.writeAsString(localLines.join('\n'));

      // 4.5 尝试合并 ts 为 mp4（可选）
      await _tryMergeSegmentsToMp4(task, segmentUrls.length);

      // 5. 计算最终文件大小
      int totalSize = 0;
      try {
        totalSize = await _calculateDirSize(Directory(task.savePath));
      } catch (e) {
        debugPrint("Error calculating directory size: $e");
      }

      // 完成
      final finalIndex = _tasks.indexWhere((t) => t.id == id);
      if (finalIndex != -1) {
        _tasks[finalIndex] = _tasks[finalIndex].copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          downloadedSegments: segmentUrls.length,
          fileSize: totalSize,
        );
        await _saveTasks();
        notifyListeners();
        _retryCounts.remove(id);
        _syncBackgroundService();
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        debugPrint("下载任务已取消: $id");
      } else {
        debugPrint("下载任务异常: $id, error: $e");
        final errIndex = _tasks.indexWhere((t) => t.id == id);
        if (errIndex != -1) {
          final retryCount = _retryCounts[id] ?? 0;
          final canRetry = _isRetriableError(e) && retryCount < _maxRetryCount;

          if (canRetry) {
            final nextRetry = retryCount + 1;
            _retryCounts[id] = nextRetry;
            _tasks[errIndex] = _tasks[errIndex].copyWith(
              status: DownloadStatus.queued,
              error: '网络波动，自动重试中（$nextRetry/$_maxRetryCount）',
            );
          } else {
            _tasks[errIndex] = _tasks[errIndex].copyWith(
              status: DownloadStatus.failed,
              error: e.toString(),
            );
            _retryCounts.remove(id);
          }

          await _saveTasks();
          notifyListeners();
          _syncBackgroundService();

          if (canRetry) {
            Future.delayed(const Duration(seconds: 2), _checkQueue);
          }
        }
      }
    } finally {
      _cancelTokens.remove(id);
      _syncBackgroundService();
      _checkQueue(); // 任务结束，检查并启动下一个
    }
  }

  String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http')) {
      return url;
    }
    final uri = Uri.parse(baseUrl);
    return uri.resolve(url).toString();
  }

  Future<int> _calculateDirSize(Directory dir) async {
    int totalSize = 0;
    try {
      if (await dir.exists()) {
        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint("Error calculating dir size: $e");
    }
    return totalSize;
  }
}

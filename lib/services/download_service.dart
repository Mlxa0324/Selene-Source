import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_task.dart';

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final List<DownloadTask> _tasks = [];
  final Map<String, CancelToken> _cancelTokens = {};
  
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
      if (_tasks[i].status == DownloadStatus.completed && _tasks[i].fileSize == null) {
        final size = await _calculateDirSize(Directory(_tasks[i].savePath));
        if (size > 0) {
          _tasks[i] = _tasks[i].copyWith(fileSize: size);
        }
      }
    }
    notifyListeners();
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
      _checkQueue(); // 腾出一个位置，检查队列
    }
  }

  void resumeTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1 && (_tasks[index].status == DownloadStatus.paused || _tasks[index].status == DownloadStatus.failed)) {
      _tasks[index] = _tasks[index].copyWith(status: DownloadStatus.queued);
      _saveTasks();
      notifyListeners();
      _checkQueue(); // 加入队列等待调度
    }
  }

  /// 检查并调度下载队列
  void _checkQueue() {
    // 统计当前正在下载的任务
    int downloadingCount = _tasks.where((t) => t.status == DownloadStatus.downloading).length;
    
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
  }

  Future<void> deleteTask(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _cancelTokens[id]?.cancel("User deleted");
      final task = _tasks[index];
      _tasks.removeAt(index);
      await _saveTasks();
      notifyListeners();
      _checkQueue(); // 删除后也检查队列
      
      // 删除本地文件
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
      int completedInSession = 0;
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

          completedInSession++;
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
              double newSpeed = (currentTotalSize - lastDownloadedSize) / (interval / 1000.0);
              
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
      }

    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        debugPrint("Download cancelled for $id");
      } else {
        debugPrint("Download error for $id: $e");
        final errIndex = _tasks.indexWhere((t) => t.id == id);
        if (errIndex != -1) {
          _tasks[errIndex] = _tasks[errIndex].copyWith(
            status: DownloadStatus.failed,
            error: e.toString(),
          );
          await _saveTasks();
          notifyListeners();
        }
      }
    } finally {
      _cancelTokens.remove(id);
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
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
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

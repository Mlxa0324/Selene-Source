import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../models/download_task.dart';
import '../models/play_record.dart';
import '../services/local_mode_storage_service.dart';
import '../services/page_cache_service.dart';
import '../services/theme_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../models/search_result.dart';
import 'player_screen.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  bool _isEditing = false;
  final Set<String> _selectedIds = {};
  final Set<String> _expandedTitles = {}; // 记录展开的剧集标题
  Map<String, PlayRecord> _localPlayRecords = {};

  @override
  void initState() {
    super.initState();
    _loadLocalPlayRecords();
  }

  Future<void> _loadLocalPlayRecords() async {
    try {
      final records = await LocalModeStorageService.getPlayRecords();
      final map = <String, PlayRecord>{};
      for (final record in records) {
        if (record.source == 'local') {
          map[record.id] = record;
        }
      }
      if (!mounted) return;
      setState(() {
        _localPlayRecords = map;
      });
    } catch (e) {
      debugPrint('加载离线播放进度失败: $e');
    }
  }

  PlayRecord? _findLocalPlayRecord(DownloadTask task) {
    final direct = _localPlayRecords[task.id];
    if (direct != null) {
      return direct;
    }

    final targetEpisodeIndex = (task.episodeIndex ?? -1) + 1;
    if (targetEpisodeIndex <= 0) {
      return null;
    }

    for (final record in _localPlayRecords.values) {
      if (record.source == 'local' &&
          record.title == task.title &&
          record.index == targetEpisodeIndex) {
        return record;
      }
    }
    return null;
  }

  Future<void> _deleteLocalPlayRecordByTask(DownloadTask task) async {
    final idsToDelete = <String>{task.id};
    final targetEpisodeIndex = (task.episodeIndex ?? -1) + 1;
    if (targetEpisodeIndex > 0) {
      for (final record in _localPlayRecords.values) {
        if (record.source == 'local' &&
            record.title == task.title &&
            record.index == targetEpisodeIndex) {
          idsToDelete.add(record.id);
        }
      }
    }

    try {
      for (final id in idsToDelete) {
        await LocalModeStorageService.deletePlayRecord('local', id);
      }
      if (mounted) {
        setState(() {
          _localPlayRecords.removeWhere((id, _) => idsToDelete.contains(id));
        });
      }
    } catch (e) {
      debugPrint('删除本地播放进度失败: $e');
    }

    if (!mounted) return;

    // 尝试同步删除云端记录，失败不影响本地功能
    () async {
      try {
        for (final id in idsToDelete) {
          await PageCacheService().deletePlayRecord('local', id, context);
        }
      } catch (error) {
        debugPrint('删除云端播放进度失败（已忽略）: $error');
      }
    }();
  }

  String _buildCompletedProgressText(DownloadTask task) {
    final baseText = "已完成 | ${_formatFileSize(task.fileSize)}";
    final record = _findLocalPlayRecord(task);
    if (record == null || record.playTime <= 0) {
      return baseText;
    }

    final totalText =
        record.totalTime > 0 ? " / ${record.formattedTotalTime}" : "";
    return "$baseText · 上次看到 ${record.formattedPlayTime}$totalText";
  }

  // 归类已完成任务
  Map<String, List<DownloadTask>> _groupCompletedTasks(
      List<DownloadTask> tasks) {
    final Map<String, List<DownloadTask>> groups = {};
    for (var task in tasks) {
      if (task.status != DownloadStatus.completed) continue;
      if (!groups.containsKey(task.title)) {
        groups[task.title] = [];
      }
      groups[task.title]!.add(task);
    }
    // 对每个组内的集数按 episodeIndex 排序
    groups.forEach((title, groupTasks) {
      groupTasks
          .sort((a, b) => (a.episodeIndex ?? 0).compareTo(b.episodeIndex ?? 0));
    });
    return groups;
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return "未知大小";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return "${size.toStringAsFixed(1)} ${suffixes[i]}";
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return "0 B/s";
    const suffixes = ["B/s", "KB/s", "MB/s", "GB/s"];
    var i = 0;
    double speed = bytesPerSecond;
    while (speed >= 1024 && i < suffixes.length - 1) {
      speed /= 1024;
      i++;
    }
    return "${speed.toStringAsFixed(1)} ${suffixes[i]}";
  }

  Future<void> _playOfflineVideo(BuildContext context, DownloadTask task,
      List<DownloadTask> allEpisodes) async {
    final List<String> episodesPaths = [];
    final List<String> episodesTitles = [];
    int initialIndex = 0;

    for (int i = 0; i < allEpisodes.length; i++) {
      final ep = allEpisodes[i];
      final localM3u8Path = "${ep.savePath}/index.m3u8";
      final mergedMp4Path = "${ep.savePath}/merged.mp4";
      final mergedTsPath = "${ep.savePath}/merged.ts";

      if (ep.status == DownloadStatus.completed &&
          File(mergedMp4Path).existsSync()) {
        episodesPaths.add(mergedMp4Path);
      } else if (ep.status == DownloadStatus.completed &&
          File(mergedTsPath).existsSync()) {
        episodesPaths.add(mergedTsPath);
      } else if (ep.status == DownloadStatus.completed &&
          File(localM3u8Path).existsSync()) {
        episodesPaths.add(localM3u8Path);
      } else {
        episodesPaths.add(ep.url);
      }

      episodesTitles.add(ep.subtitle);
      if (ep.id == task.id) {
        initialIndex = episodesPaths.length - 1;
      }
    }

    final offlineDetail = SearchResult(
      id: task.id,
      title: task.title,
      poster: task.cover,
      year: '',
      url: task.url,
      source: 'local',
      sourceName: '本地缓存',
      episodes: episodesPaths,
      episodesTitles: episodesTitles,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          title: task.title,
          localPath: episodesPaths[initialIndex].startsWith('http')
              ? null
              : episodesPaths[initialIndex],
          initialVideoDetail: offlineDetail,
          initialEpisodeIndex: initialIndex,
        ),
      ),
    );

    await _loadLocalPlayRecords();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isDarkMode = themeService.isDarkMode;
    final downloadService = context.watch<DownloadService>();
    final tasks = downloadService.tasks;

    final downloadingTasks =
        tasks.where((t) => t.status != DownloadStatus.completed).toList();
    final groupedCompletedTasks = _groupCompletedTasks(tasks);
    final completedTitles = groupedCompletedTasks.keys.toList();

    final bodyContent = Stack(
      children: [
        TabBarView(
          children: [
            downloadingTasks.isEmpty
                ? _buildEmptyState(isDarkMode, "暂无下载任务")
                : ListView.builder(
                    padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: _isEditing ? 100 : 16),
                    itemCount: downloadingTasks.length,
                    itemBuilder: (context, index) {
                      final task = downloadingTasks[index];
                      return _buildDownloadItem(
                          context, task, downloadingTasks, isDarkMode);
                    },
                  ),
            completedTitles.isEmpty
                ? _buildEmptyState(isDarkMode, "暂无已完成任务")
                : ListView.builder(
                    padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 0,
                        bottom: _isEditing ? 100 : 16),
                    itemCount: completedTitles.length,
                    itemBuilder: (context, index) {
                      final title = completedTitles[index];
                      final group = groupedCompletedTasks[title] ?? [];
                      return _buildGroup(context, title, group, isDarkMode);
                    },
                  ),
          ],
        ),
        if (_isEditing)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1e1e1e) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedIds.length == tasks.length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(tasks.map((t) => t.id));
                        }
                      });
                    },
                    child: Text(
                        _selectedIds.length == tasks.length ? '取消全选' : '全选'),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () {
                                final downloadService =
                                    context.read<DownloadService>();
                                for (var id in _selectedIds) {
                                  downloadService.pauseTask(id);
                                }
                              },
                        icon: const Icon(Icons.pause_circle_outline, size: 20),
                        label: const Text('暂停'),
                      ),
                      TextButton.icon(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () {
                                final downloadService =
                                    context.read<DownloadService>();
                                for (var id in _selectedIds) {
                                  downloadService.resumeTask(id);
                                }
                              },
                        icon: const Icon(Icons.play_circle_outline, size: 20),
                        label: const Text('开始'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _confirmBatchDelete(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('删除 (${_selectedIds.length})'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    final tabBar = TabBar(
      tabs: [
        Tab(text: "下载中 (${downloadingTasks.length})"),
        Tab(text: "已完成 (${tasks.length - downloadingTasks.length})"),
      ],
      indicatorColor: Colors.green,
      labelColor: Colors.green,
      unselectedLabelColor: isDarkMode ? Colors.white38 : Colors.black38,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            isDarkMode ? const Color(0xFF000000) : const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: Text(
            _isEditing ? '已选 ${_selectedIds.length}' : '下载管理',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: true,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
            statusBarBrightness:
                isDarkMode ? Brightness.dark : Brightness.light,
          ),
          bottom: tabBar,
          actions: [
            if (tasks.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                    if (!_isEditing) _selectedIds.clear();
                  });
                },
                child: Text(
                  _isEditing ? '完成' : '编辑',
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black),
                ),
              ),
          ],
        ),
        body: bodyContent,
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            size: 80,
            color: isDarkMode ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, String title,
      List<DownloadTask> group, bool isDarkMode) {
    final bool isExpanded = _expandedTitles.contains(title);
    final completedCount =
        group.where((t) => t.status == DownloadStatus.completed).length;

    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            setState(() {
              if (isExpanded) {
                _expandedTitles.remove(title);
              } else {
                _expandedTitles.add(title);
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white10
                    : Colors.black.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: group[0].cover,
                    width: 50,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.9)
                              : const Color(0xFF2c3e50),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "共 ${group.length} 集 · 已完成 $completedCount 集",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: isDarkMode ? Colors.white38 : Colors.black38,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...group
              .map((task) =>
                  _buildDownloadItem(context, task, group, isDarkMode))
              .toList(),
      ],
    );
  }

  Widget _buildDownloadItem(BuildContext context, DownloadTask task,
      List<DownloadTask> allEpisodes, bool isDarkMode) {
    final downloadService = context.read<DownloadService>();
    final isSelected = _selectedIds.contains(task.id);

    return Container(
      margin: EdgeInsets.only(
          left: task.status == DownloadStatus.completed ? 12 : 0,
          right: 0,
          top: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: _isEditing && isSelected
            ? Border.all(color: Colors.green, width: 2)
            : Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (_isEditing) {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(task.id);
                } else {
                  _selectedIds.add(task.id);
                }
              });
            } else if (task.status == DownloadStatus.completed) {
              await _playOfflineVideo(context, task, allEpisodes);
            } else {
              // 未完成任务：点击切换开始/暂停
              if (task.status == DownloadStatus.downloading) {
                downloadService.pauseTask(task.id);
              } else {
                downloadService.resumeTask(task.id);
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_isEditing) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.add(task.id);
                        } else {
                          _selectedIds.remove(task.id);
                        }
                      });
                    },
                    activeColor: Colors.green,
                  ),
                  const SizedBox(width: 4),
                ],
                // 正在下载模式下显示封面，已完成的分组模式下隐藏封面（因为头部已显示）
                if (task.status != DownloadStatus.completed) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: task.cover,
                      width: 45,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 信息区
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.status == DownloadStatus.completed
                            ? task.subtitle
                            : "${task.title} - ${task.subtitle}",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      // 进度条
                      LinearProgressIndicator(
                        value: task.progress,
                        backgroundColor:
                            isDarkMode ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          task.status == DownloadStatus.failed
                              ? Colors.red
                              : Colors.green,
                        ),
                        minHeight: 2,
                        borderRadius: BorderRadius.circular(1),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              task.status == DownloadStatus.downloading
                                  ? "已下载 ${_formatFileSize(task.currentSize)}"
                                  : (task.status == DownloadStatus.completed
                                      ? _buildCompletedProgressText(task)
                                      : _getStatusText(task)),
                              style: TextStyle(
                                fontSize: 11,
                                color: _getStatusColor(task, isDarkMode),
                              ),
                            ),
                          ),
                          if (task.status == DownloadStatus.downloading)
                            Text(
                              _formatSpeed(task.speed),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 操作区
                if (!_isEditing)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () => _confirmDelete(context, task),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusText(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.queued:
        return '等待中...';
      case DownloadStatus.downloading:
        return '正在下载...';
      case DownloadStatus.paused:
        return '已暂停';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.failed:
        return '下载失败';
    }
  }

  Color _getStatusColor(DownloadTask task, bool isDarkMode) {
    switch (task.status) {
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.completed:
        return Colors.green;
      default:
        return isDarkMode ? Colors.white38 : Colors.black38;
    }
  }

  IconData _getActionIcon(DownloadTask task) {
    if (task.status == DownloadStatus.downloading)
      return Icons.pause_circle_outline;
    if (task.status == DownloadStatus.completed)
      return Icons.play_circle_outline;
    return Icons.play_circle_outline;
  }

  void _confirmDelete(BuildContext context, DownloadTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content:
            Text('确定要删除 "${task.title} - ${task.subtitle}" 吗？\n文件也将从本地删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final downloadService = context.read<DownloadService>();
              Navigator.pop(ctx);
              await downloadService.deleteTask(task.id);
              await _deleteLocalPlayRecordByTask(task);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmBatchDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 个任务吗？\n文件也将从本地删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final downloadService = context.read<DownloadService>();
              final selectedTasks = downloadService.tasks
                  .where((task) => _selectedIds.contains(task.id))
                  .toList();
              Navigator.pop(ctx);

              for (final task in selectedTasks) {
                await downloadService.deleteTask(task.id);
                await _deleteLocalPlayRecordByTask(task);
              }
              if (!mounted) return;
              setState(() {
                _isEditing = false;
                _selectedIds.clear();
              });
            },
            child: const Text('全部删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

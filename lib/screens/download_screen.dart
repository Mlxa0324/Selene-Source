import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../models/download_task.dart';
import '../models/play_record.dart';
import '../services/app_cache_service.dart';
import '../services/local_mode_storage_service.dart';
import '../services/page_cache_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_confirm_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../models/search_result.dart';
import 'player_screen.dart';

@visibleForTesting
DownloadTask? resolveContinueTaskForDownloadGroup({
  required List<DownloadTask> group,
  required Iterable<PlayRecord> records,
}) {
  if (group.isEmpty) {
    return null;
  }

  final recordsById = <String, PlayRecord>{
    for (final record in records) record.id: record,
  };
  DownloadTask? bestTask;
  PlayRecord? bestRecord;

  for (final task in group) {
    final direct = recordsById[task.id];
    PlayRecord? matchedRecord = direct;
    if (matchedRecord == null) {
      final targetEpisodeIndex = task.episodeIndex + 1;
      for (final record in records) {
        if (record.source == 'local' &&
            record.title == task.title &&
            record.index == targetEpisodeIndex) {
          matchedRecord = record;
          break;
        }
      }
    }
    if (matchedRecord == null) {
      continue;
    }
    if (bestRecord == null ||
        matchedRecord.saveTime > bestRecord.saveTime ||
        (matchedRecord.saveTime == bestRecord.saveTime &&
            matchedRecord.playTime > bestRecord.playTime)) {
      bestRecord = matchedRecord;
      bestTask = task;
    }
  }

  return bestTask ?? group.first;
}

/// 下载页存储空间加载函数。
typedef DownloadStorageSummaryLoader = Future<AppStorageSummary?> Function();

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({
    super.key,
    this.storageSummaryLoader,
  });

  /// 存储空间摘要加载函数，测试可注入固定数据。
  final DownloadStorageSummaryLoader? storageSummaryLoader;

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen>
    with SingleTickerProviderStateMixin {
  bool _isEditing = false;
  final Set<String> _selectedIds = {};
  final Set<String> _expandedTitles = {}; // 记录展开的剧集标题
  Map<String, PlayRecord> _localPlayRecords = {};
  Future<AppStorageSummary?>? _storageSummaryFuture;
  late final TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _storageSummaryFuture = _loadStorageSummary();
    _loadLocalPlayRecords();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_currentTabIndex == _tabController.index) return;
    setState(() {
      _currentTabIndex = _tabController.index;
      _isEditing = false;
      _selectedIds.clear();
    });
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

  /// 读取设备存储摘要，读取失败时页面继续正常展示下载列表。
  Future<AppStorageSummary?> _loadStorageSummary() {
    final loader = widget.storageSummaryLoader;
    if (loader != null) {
      return loader();
    }
    return AppCacheService().loadStorageSummary();
  }

  /// 手动刷新存储摘要，用户删除缓存后可立即看到剩余空间变化。
  void _refreshStorageSummary() {
    setState(() {
      _storageSummaryFuture = _loadStorageSummary();
    });
  }

  PlayRecord? _findLocalPlayRecord(DownloadTask task) {
    final direct = _localPlayRecords[task.id];
    if (direct != null) {
      return direct;
    }

    final targetEpisodeIndex = task.episodeIndex + 1;
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

  /// 收集下载任务对应的本地播放记录，确保删除缓存时同步删除续播点。
  Set<String> _collectLocalPlayRecordIdsForTask(DownloadTask task) {
    final idsToDelete = <String>{task.id};
    final targetEpisodeIndex = task.episodeIndex + 1;
    if (targetEpisodeIndex > 0) {
      for (final record in _localPlayRecords.values) {
        if (record.source == 'local' &&
            record.title == task.title &&
            record.index == targetEpisodeIndex) {
          idsToDelete.add(record.id);
        }
      }
    }
    return idsToDelete;
  }

  /// 批量删除任务对应的播放记录，避免多次 setState 和重复刷新。
  Future<void> _deleteLocalPlayRecordsByTasks(
    Iterable<DownloadTask> tasks,
  ) async {
    final idsToDelete = <String>{};
    for (final task in tasks) {
      idsToDelete.addAll(_collectLocalPlayRecordIdsForTask(task));
    }
    if (idsToDelete.isEmpty) {
      return;
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

  /// 返回当前标签页下实际展示的任务列表，便于编辑态与批量操作复用。
  List<DownloadTask> _tasksForCurrentTab({
    required List<DownloadTask> downloadingTasks,
    required List<DownloadTask> completedTasks,
  }) {
    return _currentTabIndex == 0 ? downloadingTasks : completedTasks;
  }

  /// 统一处理批量任务删除，减少多次通知与重复清理逻辑。
  Future<void> _deleteTasksBatch(
    BuildContext context,
    List<DownloadTask> tasks,
  ) async {
    if (tasks.isEmpty) {
      return;
    }

    final downloadService = context.read<DownloadService>();
    final taskIds = tasks.map((task) => task.id).toSet();
    await downloadService.deleteTasks(taskIds);
    await _deleteLocalPlayRecordsByTasks(tasks);

    if (!mounted) return;
    setState(() {
      _selectedIds.removeWhere(taskIds.contains);
      if (_selectedIds.isEmpty) {
        _isEditing = false;
      }
      _storageSummaryFuture = _loadStorageSummary();
    });
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

  DownloadTask? _resolveContinueTaskForGroup(List<DownloadTask> group) {
    return resolveContinueTaskForDownloadGroup(
      group: group,
      records: _localPlayRecords.values,
    );
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
      groupTasks.sort((a, b) => a.episodeIndex.compareTo(b.episodeIndex));
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

  /// 构建存储空间摘要卡片，提醒用户下载前关注剩余容量。
  Widget _buildStorageSummaryCard(bool isDarkMode) {
    final future = _storageSummaryFuture;
    if (future == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<AppStorageSummary?>(
      future: future,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildStorageSummaryShell(
            isDarkMode: isDarkMode,
            icon: Icons.storage_outlined,
            title: '正在读取存储空间',
            subtitle: '稍后显示手机剩余容量',
            action: null,
          );
        }

        if (summary == null) {
          return _buildStorageSummaryShell(
            isDarkMode: isDarkMode,
            icon: Icons.info_outline,
            title: '无法读取存储空间',
            subtitle: '请在系统设置中留意剩余容量，避免下载占满手机。',
            action: TextButton(
              onPressed: _refreshStorageSummary,
              child: const Text('重试'),
            ),
          );
        }

        final availableText = summary.availableBytes == null
            ? '未知'
            : AppCacheService.formatBytes(summary.availableBytes!);
        final totalText = summary.totalBytes == null
            ? '未知'
            : AppCacheService.formatBytes(summary.totalBytes!);
        final subtitle = summary.isLowStorage
            ? '剩余空间低于 ${AppCacheService.formatBytes(summary.lowStorageThresholdBytes)}，建议先删除缓存再继续下载。'
            : '请保持足够剩余空间，避免下载占满手机导致卡顿。';

        return _buildStorageSummaryShell(
          isDarkMode: isDarkMode,
          icon: summary.isLowStorage
              ? Icons.warning_amber_rounded
              : Icons.storage_outlined,
          title: '剩余 $availableText / 总量 $totalText',
          subtitle: subtitle,
          danger: summary.isLowStorage,
          action: TextButton(
            onPressed: _refreshStorageSummary,
            child: const Text('刷新'),
          ),
        );
      },
    );
  }

  /// 存储空间摘要卡片外壳，统一正常、加载和异常态样式。
  Widget _buildStorageSummaryShell({
    required bool isDarkMode,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget? action,
    bool danger = false,
  }) {
    final accentColor = danger ? Colors.orangeAccent : Colors.green;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: danger
              ? Colors.orangeAccent.withValues(alpha: 0.45)
              : (isDarkMode
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF2c3e50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action,
          ],
        ],
      ),
    );
  }

  Future<void> _playOfflineVideo(BuildContext context, DownloadTask task,
      List<DownloadTask> allEpisodes) async {
    final List<String> episodesPaths = [];
    final List<String> episodesTitles = [];
    final List<String> episodeTaskIds = [];
    final List<int> episodeNumbers = [];
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
      episodeTaskIds.add(ep.id);
      episodeNumbers.add(ep.episodeIndex + 1);
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
          localEpisodeIds: episodeTaskIds,
          localEpisodeNumbers: episodeNumbers,
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
    final completedTasks =
        tasks.where((t) => t.status == DownloadStatus.completed).toList();
    final groupedCompletedTasks = _groupCompletedTasks(tasks);
    final completedTitles = groupedCompletedTasks.keys.toList();
    final currentTabTasks = _tasksForCurrentTab(
      downloadingTasks: downloadingTasks,
      completedTasks: completedTasks,
    );
    final hasCurrentTabTasks = currentTabTasks.isNotEmpty;

    final bodyContent = Stack(
      children: [
        TabBarView(
          controller: _tabController,
          children: [
            _buildDownloadingTab(
              downloadingTasks: downloadingTasks,
              isDarkMode: isDarkMode,
            ),
            _buildCompletedTab(
              completedTitles: completedTitles,
              groupedCompletedTasks: groupedCompletedTasks,
              isDarkMode: isDarkMode,
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
              child: _currentTabIndex == 0
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedIds.length ==
                                  currentTabTasks.length) {
                                _selectedIds.clear();
                              } else {
                                _selectedIds
                                  ..clear()
                                  ..addAll(currentTabTasks.map((t) => t.id));
                              }
                            });
                          },
                          child: Text(
                              _selectedIds.length == currentTabTasks.length
                                  ? '取消全选'
                                  : '全选'),
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
                              icon: const Icon(Icons.pause_circle_outline,
                                  size: 20),
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
                              icon: const Icon(Icons.play_circle_outline,
                                  size: 20),
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text('删除 (${_selectedIds.length})'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: currentTabTasks.isEmpty
                                  ? null
                                  : () => _confirmDeleteAllCurrentTab(
                                        context,
                                        currentTabTasks,
                                      ),
                              child: const Text('全部删除当前页'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedIds.length ==
                                  currentTabTasks.length) {
                                _selectedIds.clear();
                              } else {
                                _selectedIds
                                  ..clear()
                                  ..addAll(currentTabTasks.map((t) => t.id));
                              }
                            });
                          },
                          child: Text(
                              _selectedIds.length == currentTabTasks.length
                                  ? '取消全选'
                                  : '全选'),
                        ),
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
                        TextButton(
                          onPressed: currentTabTasks.isEmpty
                              ? null
                              : () => _confirmDeleteAllCurrentTab(
                                    context,
                                    currentTabTasks,
                                  ),
                          child: const Text('全部删除当前页'),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );

    final tabBar = TabBar(
      controller: _tabController,
      tabs: [
        Tab(text: "下载中 (${downloadingTasks.length})"),
        Tab(text: "已完成 (${completedTasks.length})"),
      ],
      indicatorColor: Colors.green,
      labelColor: Colors.green,
      unselectedLabelColor: isDarkMode ? Colors.white38 : Colors.black38,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
    );

    return Scaffold(
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
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        bottom: tabBar,
        actions: [
          if (hasCurrentTabTasks)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                  if (!_isEditing) _selectedIds.clear();
                });
              },
              child: Text(
                _isEditing ? '完成' : '编辑',
                style:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
            ),
        ],
      ),
      body: bodyContent,
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

  /// 构建下载中标签页，顶部固定展示存储空间提示。
  Widget _buildDownloadingTab({
    required List<DownloadTask> downloadingTasks,
    required bool isDarkMode,
  }) {
    final itemCount =
        downloadingTasks.isEmpty ? 2 : downloadingTasks.length + 1;
    return ListView.builder(
      padding: EdgeInsets.only(bottom: _isEditing ? 100 : 16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildStorageSummaryCard(isDarkMode);
        }
        if (downloadingTasks.isEmpty) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: _buildEmptyState(isDarkMode, '暂无下载任务'),
          );
        }
        final task = downloadingTasks[index - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child:
              _buildDownloadItem(context, task, downloadingTasks, isDarkMode),
        );
      },
    );
  }

  /// 构建已完成标签页，顶部固定展示存储空间提示。
  Widget _buildCompletedTab({
    required List<String> completedTitles,
    required Map<String, List<DownloadTask>> groupedCompletedTasks,
    required bool isDarkMode,
  }) {
    final itemCount = completedTitles.isEmpty ? 2 : completedTitles.length + 1;
    return ListView.builder(
      padding: EdgeInsets.only(bottom: _isEditing ? 100 : 16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildStorageSummaryCard(isDarkMode);
        }
        if (completedTitles.isEmpty) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: _buildEmptyState(isDarkMode, '暂无已完成任务'),
          );
        }
        final title = completedTitles[index - 1];
        final group = groupedCompletedTasks[title] ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildGroup(context, title, group, isDarkMode),
        );
      },
    );
  }

  Widget _buildGroup(BuildContext context, String title,
      List<DownloadTask> group, bool isDarkMode) {
    final bool isExpanded = _expandedTitles.contains(title);
    final completedCount =
        group.where((t) => t.status == DownloadStatus.completed).length;
    final continueTask = _resolveContinueTaskForGroup(group);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.08),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedTitles.remove(title);
                  } else {
                    _expandedTitles.add(title);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                              color:
                                  isDarkMode ? Colors.white38 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isEditing && continueTask != null)
                      TextButton(
                        onPressed: () async {
                          await _playOfflineVideo(context, continueTask, group);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('继续播放'),
                      ),
                    if (!_isEditing)
                      TextButton(
                        onPressed: () => _confirmDeleteGroup(
                          context,
                          title,
                          group,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('删除整部'),
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

  void _confirmDelete(BuildContext context, DownloadTask task) {
    showAppConfirmDialog(
      context: context,
      title: '删除任务',
      message: '确定要删除 "${task.title} - ${task.subtitle}" 吗？\n文件也将从本地删除。',
      confirmLabel: '删除',
      cancelLabel: '取消',
      icon: Icons.delete_outline,
      onConfirm: () async {
        await _deleteTasksBatch(context, [task]);
      },
    );
  }

  void _confirmBatchDelete(BuildContext context) {
    showAppConfirmDialog(
      context: context,
      title: '批量删除',
      message: '确定要删除选中的 ${_selectedIds.length} 个任务吗？\n文件也将从本地删除。',
      confirmLabel: '全部删除',
      cancelLabel: '取消',
      icon: Icons.delete_outline,
      onConfirm: () async {
        final downloadService = context.read<DownloadService>();
        final selectedTasks = downloadService.tasks
            .where((task) => _selectedIds.contains(task.id))
            .where((task) => _currentTabIndex == 0
                ? task.status != DownloadStatus.completed
                : task.status == DownloadStatus.completed)
            .toList();
        await _deleteTasksBatch(context, selectedTasks);
      },
    );
  }

  /// 确认删除整部分组缓存，便于已完成页直接清理整部剧。
  void _confirmDeleteGroup(
    BuildContext context,
    String title,
    List<DownloadTask> group,
  ) {
    showAppConfirmDialog(
      context: context,
      title: '删除整部',
      message: '确定要删除 "$title" 的 ${group.length} 集缓存吗？\n文件也将从本地删除。',
      confirmLabel: '全部删除',
      cancelLabel: '取消',
      icon: Icons.delete_outline,
      onConfirm: () async {
        await _deleteTasksBatch(context, group);
      },
    );
  }

  /// 确认删除当前标签页全部任务，减少先全选再删除的操作成本。
  void _confirmDeleteAllCurrentTab(
    BuildContext context,
    List<DownloadTask> tasks,
  ) {
    showAppConfirmDialog(
      context: context,
      title: '全部删除',
      message: '确定要删除当前页全部 ${tasks.length} 个任务吗？\n文件也将从本地删除。',
      confirmLabel: '全部删除',
      cancelLabel: '取消',
      icon: Icons.delete_outline,
      onConfirm: () async {
        await _deleteTasksBatch(context, tasks);
      },
    );
  }
}

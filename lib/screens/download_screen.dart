import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../models/download_task.dart';
import '../services/theme_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isDarkMode = themeService.isDarkMode;
    final downloadService = context.watch<DownloadService>();
    final tasks = downloadService.tasks;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF000000) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('下载管理', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: tasks.isEmpty
          ? _buildEmptyState(isDarkMode)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildDownloadItem(context, task, isDarkMode);
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
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
            '暂无下载内容',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadItem(BuildContext context, DownloadTask task, bool isDarkMode) {
    final downloadService = context.read<DownloadService>();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDarkMode ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 110,
                child: CachedNetworkImage(
                  imageUrl: task.cover,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: isDarkMode ? Colors.white10 : Colors.black12,
                    child: const Icon(Icons.movie, color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 信息区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 进度条
                  LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor: isDarkMode ? Colors.white10 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      task.status == DownloadStatus.failed ? Colors.red : Colors.green,
                    ),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getStatusText(task),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(task, isDarkMode),
                        ),
                      ),
                      Text(
                        '${(task.progress * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 操作区
            Column(
              children: [
                IconButton(
                  icon: Icon(
                    _getActionIcon(task),
                    color: Colors.green,
                    size: 24,
                  ),
                  onPressed: () {
                    if (task.status == DownloadStatus.downloading) {
                      downloadService.pauseTask(task.id);
                    } else {
                      downloadService.resumeTask(task.id);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
                  onPressed: () => _confirmDelete(context, task),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.queued: return '等待中...';
      case DownloadStatus.downloading: return '正在下载...';
      case DownloadStatus.paused: return '已暂停';
      case DownloadStatus.completed: return '已完成';
      case DownloadStatus.failed: return '下载失败';
    }
  }

  Color _getStatusColor(DownloadTask task, bool isDarkMode) {
    switch (task.status) {
      case DownloadStatus.failed: return Colors.red;
      case DownloadStatus.completed: return Colors.green;
      default: return isDarkMode ? Colors.white38 : Colors.black38;
    }
  }

  IconData _getActionIcon(DownloadTask task) {
    if (task.status == DownloadStatus.downloading) return Icons.pause_circle_outline;
    if (task.status == DownloadStatus.completed) return Icons.play_circle_outline;
    return Icons.play_circle_outline;
  }

  void _confirmDelete(BuildContext context, DownloadTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除 "${task.title} - ${task.subtitle}" 吗？\n文件也将从本地删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              context.read<DownloadService>().deleteTask(task.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

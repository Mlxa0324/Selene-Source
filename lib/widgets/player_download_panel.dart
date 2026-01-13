import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/download_task.dart';
import '../services/download_service.dart';
import 'package:provider/provider.dart';
import '../screens/download_screen.dart';

class PlayerDownloadPanel extends StatefulWidget {
  final ThemeData theme;
  final String title;
  final String cover;
  final List<String> episodes;
  final List<String> episodesTitles;
  final bool isCompact;

  const PlayerDownloadPanel({
    super.key,
    required this.theme,
    required this.title,
    required this.cover,
    required this.episodes,
    required this.episodesTitles,
    this.isCompact = true,
  });

  @override
  State<PlayerDownloadPanel> createState() => _PlayerDownloadPanelState();
}

class _PlayerDownloadPanelState extends State<PlayerDownloadPanel> {
  final Set<int> _selectedIndices = {};

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == widget.episodes.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(Iterable.generate(widget.episodes.length));
      }
    });
  }

  Future<void> _startDownload() async {
    if (_selectedIndices.isEmpty) return;

    final downloadService = context.read<DownloadService>();
    final appDir = await getApplicationDocumentsDirectory();
    
    for (var index in _selectedIndices) {
      final episodeUrl = widget.episodes[index];
      String subtitle = '';
      if (widget.episodesTitles.isNotEmpty && index < widget.episodesTitles.length) {
        subtitle = widget.episodesTitles[index];
      } else {
        subtitle = '第${index + 1}集';
      }

      final taskId = "${widget.title}_${subtitle}".hashCode.toString();
      final savePath = "${appDir.path}/downloads/${widget.title}/$subtitle";

      final task = DownloadTask(
        id: taskId,
        url: episodeUrl,
        title: widget.title,
        subtitle: subtitle,
        cover: widget.cover,
        savePath: savePath,
        createdAt: DateTime.now(),
      );

      await downloadService.addTask(task);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("已添加 ${_selectedIndices.length} 个下载任务")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode 
        ? const Color(0xFF121212) 
        : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: EdgeInsets.fromLTRB(20, widget.isCompact ? 16 : 20, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '缓存选集 (${widget.episodes.length})',
                  style: TextStyle(
                    color: textColor,
                    fontSize: widget.isCompact ? 17 : 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 集数选择列表 (改为 Wrap 以支持动态宽高)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(widget.episodes.length, (index) {
                  final isSelected = _selectedIndices.contains(index);
                  String title = '';
                  if (widget.episodesTitles.isNotEmpty && index < widget.episodesTitles.length) {
                    title = widget.episodesTitles[index];
                  } else {
                    title = '第${index + 1}集';
                  }

                  return GestureDetector(
                    onTap: () => _toggleSelection(index),
                    child: IntrinsicWidth(
                      child: Container(
                        constraints: BoxConstraints(
                          minWidth: widget.isCompact ? 50 : 60,
                          maxWidth: 180,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Colors.green.withOpacity(0.2) 
                              : (isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05)),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected 
                              ? Border.all(color: Colors.green, width: 1.5) 
                              : null,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isCompact ? 12 : 16,
                            vertical: widget.isCompact ? 8 : 10
                          ),
                          child: Center(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: isSelected ? Colors.green : textColor,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // 查看缓存按钮 (位于底部按钮上方一点)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DownloadScreen()),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.download_for_offline_outlined,
                      color: Colors.green,
                      size: widget.isCompact ? 18 : 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '查看缓存',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: widget.isCompact ? 13 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 底部操作按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectAll,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_selectedIndices.length == widget.episodes.length ? '取消全选' : '全选'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedIndices.isEmpty ? null : _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('立即下载 (${_selectedIndices.length})'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

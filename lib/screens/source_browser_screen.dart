import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/search_resource.dart';
import '../models/video_info.dart';
import '../services/source_browser_service.dart';
import '../services/theme_service.dart';
import '../services/user_data_service.dart';
import '../utils/device_utils.dart';
import '../widgets/video_card.dart';
import 'player_screen.dart';

class SourceBrowserScreen extends StatefulWidget {
  const SourceBrowserScreen({super.key});

  @override
  State<SourceBrowserScreen> createState() => _SourceBrowserScreenState();
}

class _SourceBrowserScreenState extends State<SourceBrowserScreen> {
  static const int _maxGridItems = 540;
  static const int _showBackToTopVideoCount = 18;
  static const double _showBackToTopOffset = 480;

  // Mobile compact layout config.
  static const bool _mobileCompactMode = true;
  static const double _mobileCompactOuterPadding = _mobileCompactMode ? 12 : 16;
  static const double _mobileCompactSectionGap = _mobileCompactMode ? 0 : 16;
  static const double _mobileCompactCardRadius = _mobileCompactMode ? 18 : 20;
  static const double _mobileCompactChipFontSize = _mobileCompactMode ? 12 : 13;
  static const double _mobileCompactChipHorizontalPadding = _mobileCompactMode ? 12 : 14;
  static const double _mobileCompactChipVerticalPadding = _mobileCompactMode ? 8 : 10;
  static const double _mobileCompactHeaderSpacing = _mobileCompactMode ? 10 : 12;

  static final Map<String, List<SourceBrowserCategory>> _categoryCache = {};
  static final Map<String, _SourceBrowserVideoCacheEntry> _videoCache = {};

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<SearchResource> _sources = const [];
  List<SourceBrowserCategory> _categories = const [];
  List<SourceBrowserVideo> _videos = const [];

  bool _isLoadingSources = false;
  bool _isLoadingCategories = false;
  bool _isLoadingVideos = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _showBackToTop = false;

  String _sourceError = '';
  String _categoryError = '';
  String _keyword = '';
  String _currentSource = 'auto';
  String _selectedCategoryId = '';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      if (_keyword == _searchController.text) return;
      setState(() {
        _keyword = _searchController.text;
      });
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final storedSource = await UserDataService.getSourceBrowserCurrentSource();
    if (!mounted) return;
    setState(() {
      _currentSource = storedSource;
    });
    await _loadSources();
  }

  Future<void> _loadSources() async {
    setState(() {
      _isLoadingSources = true;
      _sourceError = '';
    });
    try {
      final sources = await SourceBrowserService.getAvailableSources();
      var nextSource = _currentSource;
      final exists = nextSource == 'auto' ||
          sources.any((item) => item.key == nextSource);
      if (!exists) {
        nextSource = 'auto';
      }
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _currentSource = nextSource;
      });
      await UserDataService.saveSourceBrowserCurrentSource(nextSource);
      await _handleSourceChanged(nextSource, forceReload: true, persist: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sourceError = '获取数据源失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSources = false;
        });
      }
    }
  }

  Future<void> _handleSourceChanged(
    String sourceKey, {
    bool forceReload = false,
    bool persist = true,
  }) async {
    if (!forceReload && _currentSource == sourceKey) {
      return;
    }

    if (persist) {
      await UserDataService.saveSourceBrowserCurrentSource(sourceKey);
    }

    if (!mounted) return;
    setState(() {
      _currentSource = sourceKey;
      _categoryError = '';
      _videos = const [];
      _categories = const [];
      _selectedCategoryId = '';
      _showBackToTop = false;
      _hasMore = false;
      _isLoadingVideos = false;
      _isLoadingMore = false;
    });

    if (sourceKey == 'auto') {
      return;
    }

    await _loadCategoriesForCurrentSource();
  }

  Future<void> _loadCategoriesForCurrentSource() async {
    final source = _currentSourceConfig;
    if (source == null) {
      return;
    }

    final requestSourceKey = _currentSource;
    final requestSourceCacheKey = _buildSourceCacheKey(requestSourceKey);
    final cachedCategories = _categoryCache[requestSourceCacheKey];
    if (cachedCategories != null) {
      final nextCategoryId = cachedCategories.isNotEmpty ? cachedCategories.first.id : '';
      if (!mounted || _currentSource != requestSourceKey) return;
      setState(() {
        _categoryError = '';
        _isLoadingCategories = false;
        _categories = cachedCategories;
        _selectedCategoryId = nextCategoryId;
      });
      if (nextCategoryId.isNotEmpty) {
        await _loadVideos(reset: true);
      }
      return;
    }

    setState(() {
      _isLoadingCategories = true;
      _categoryError = '';
    });
    try {
      final categories = await SourceBrowserService.fetchCategories(source);
      final nextCategoryId = categories.isNotEmpty ? categories.first.id : '';
      _categoryCache[requestSourceCacheKey] = categories;
      if (!mounted || _currentSource != requestSourceKey) return;
      setState(() {
        _categories = categories;
        _selectedCategoryId = nextCategoryId;
        _isLoadingCategories = false;
      });
      if (nextCategoryId.isNotEmpty) {
        await _loadVideos(reset: true);
      }
    } catch (e) {
      if (!mounted || _currentSource != requestSourceKey) return;
      setState(() {
        _categoryError = '???????$e';
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadVideos({required bool reset}) async {
    final source = _currentSourceConfig;
    if (source == null || _selectedCategoryId.isEmpty) {
      return;
    }

    final requestSourceKey = _currentSource;
    final requestCategoryId = _selectedCategoryId;
    final requestVideoCacheKey =
        _buildVideoCacheKey(requestSourceKey, requestCategoryId);

    if (reset) {
      final cachedEntry = _videoCache[requestVideoCacheKey];
      if (cachedEntry != null) {
        if (!mounted ||
            _currentSource != requestSourceKey ||
            _selectedCategoryId != requestCategoryId) {
          return;
        }
        setState(() {
          _categoryError = '';
          _isLoadingVideos = false;
          _isLoadingMore = false;
          _videos = cachedEntry.videos.take(_maxGridItems).toList();
          _page = cachedEntry.page;
          _hasMore = cachedEntry.hasMore && _videos.length < _maxGridItems;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateBackToTopVisibility();
        });
        return;
      }

      setState(() {
        _isLoadingVideos = true;
        _categoryError = '';
        _videos = const [];
        _page = 1;
        _hasMore = false;
        _showBackToTop = false;
      });
    } else {
      if (_isLoadingMore || !_hasMore || _videos.length >= _maxGridItems) {
        return;
      }
      setState(() {
        _isLoadingMore = true;
      });
    }

    final requestPage = reset ? 1 : (_page + 1);
    try {
      final result = await SourceBrowserService.fetchVideos(
        source: source,
        categoryId: requestCategoryId,
        page: requestPage,
      );
      if (!mounted ||
          _currentSource != requestSourceKey ||
          _selectedCategoryId != requestCategoryId) {
        return;
      }
      setState(() {
        final merged = reset
            ? result.videos
            : [..._videos, ...result.videos].fold<List<SourceBrowserVideo>>([], (acc, item) {
                final exists = acc.any((existing) => existing.id == item.id);
                if (!exists) {
                  acc.add(item);
                }
                return acc;
              });
        _videos = merged.take(_maxGridItems).toList();
        _page = result.page;
        _hasMore = result.hasMore && _videos.length < _maxGridItems;
        _videoCache[requestVideoCacheKey] = _SourceBrowserVideoCacheEntry(
          videos: List<SourceBrowserVideo>.from(_videos),
          page: _page,
          hasMore: _hasMore,
        );
      });
    } catch (e) {
      if (!mounted ||
          _currentSource != requestSourceKey ||
          _selectedCategoryId != requestCategoryId) {
        return;
      }
      setState(() {
        _categoryError = '?????????$e';
      });
    } finally {
      if (mounted &&
          _currentSource == requestSourceKey &&
          _selectedCategoryId == requestCategoryId) {
        setState(() {
          _isLoadingVideos = false;
          _isLoadingMore = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateBackToTopVisibility();
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _updateBackToTopVisibility();
    final position = _scrollController.position;
    if (position.pixels + 520 >= position.maxScrollExtent) {
      unawaited(_loadVideos(reset: false));
    }
  }

  String _buildSourceCacheKey(String sourceKey) => sourceKey;

  String _buildVideoCacheKey(String sourceKey, String categoryId) =>
      '$sourceKey::$categoryId';

  bool get _shouldShowBackToTop =>
      _videos.length >= _showBackToTopVideoCount && _showBackToTop;

  void _updateBackToTopVisibility() {
    if (!_scrollController.hasClients) return;
    final shouldShow = _videos.length >= _showBackToTopVideoCount &&
        _scrollController.offset >= _showBackToTopOffset;
    if (_showBackToTop == shouldShow || !mounted) {
      return;
    }
    setState(() {
      _showBackToTop = shouldShow;
    });
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  SearchResource? get _currentSourceConfig {
    for (final source in _sources) {
      if (source.key == _currentSource) {
        return source;
      }
    }
    return null;
  }

  List<SearchResource> get _filteredSources {
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _sources;
    }
    return _sources.where((source) {
      return source.name.toLowerCase().contains(keyword) ||
          source.key.toLowerCase().contains(keyword) ||
          source.api.toLowerCase().contains(keyword);
    }).toList();
  }

  String get _currentSourceName {
    if (_currentSource == 'auto') {
      return '聚合模式';
    }
    return _currentSourceConfig?.name ?? _currentSource;
  }

  VideoInfo _toVideoInfo(SourceBrowserVideo item) {
    return VideoInfo(
      id: item.id,
      source: _currentSource,
      title: item.title,
      sourceName: _currentSourceName,
      year: item.year,
      cover: item.poster,
      index: 1,
      totalEpisodes: 0,
      playTime: 0,
      totalTime: 0,
      saveTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      searchTitle: item.title,
      doubanId: item.doubanId?.toString(),
    );
  }

  void _openPlayer(SourceBrowserVideo item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          source: _currentSource,
          id: item.id,
          title: item.title,
          year: item.year,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDarkMode = themeService.isDarkMode;
        final background = Theme.of(context).scaffoldBackgroundColor;
        final cardColor = isDarkMode ? const Color(0xFF171d1a) : Colors.white;
        const accent = Color(0xFF27ae60);
        final isDesktopStyle = DeviceUtils.isTablet(context) || DeviceUtils.isPC();

        final horizontalPadding = isDesktopStyle ? 16.0 : _mobileCompactOuterPadding;
        final topPadding = isDesktopStyle ? 16.0 : 12.0;
        final sectionGap = isDesktopStyle ? 16.0 : _mobileCompactSectionGap;

        return Container(
          color: background,
          child: Stack(
            children: [
              RefreshIndicator(
                color: accent,
                onRefresh: _loadSources,
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, 28),
                  children: [
                    if (isDesktopStyle) ...[
                      _buildHeader(cardColor, isDarkMode, accent),
                      SizedBox(height: sectionGap),
                      _buildSourceSection(cardColor, isDarkMode, accent),
                      SizedBox(height: sectionGap),
                      _buildCategorySection(cardColor, isDarkMode, accent),
                    ] else ...[
                      _buildMobileSummarySection(cardColor, isDarkMode, accent),
                    ],
                    SizedBox(height: sectionGap),
                    _buildContentSection(cardColor, isDarkMode, accent),
                  ],
                ),
              ),
              if (_shouldShowBackToTop)
                Positioned(
                  right: isDesktopStyle ? 24 : 16,
                  bottom: isDesktopStyle ? 24 : 18,
                  child: FloatingActionButton.small(
                    heroTag: 'source_browser_back_to_top',
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    onPressed: _scrollToTop,
                    child: const Icon(LucideIcons.chevronUp, size: 20),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color cardColor, bool isDarkMode, Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(LucideIcons.globe, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '源浏览器',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : const Color(0xFF1f2d26),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '按源查看分类内容，直接进入播放详情。',



                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.68)
                            : const Color(0xFF5f6f67),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '??',
                onPressed: _isLoadingSources ? null : _loadSources,
                icon: _isLoadingSources
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : Icon(LucideIcons.refreshCcw, color: accent, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索源名称、Key 或 API 地址',
              prefixIcon: Icon(LucideIcons.search, size: 18, color: accent),
              suffixIcon: _keyword.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
              filled: true,
              fillColor: isDarkMode ? const Color(0xFF101513) : const Color(0xFFF2F7F3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSection(Color cardColor, bool isDarkMode, Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '数据源',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF1f2d26),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '当前：$_currentSourceName · 共 ${_sources.length + 1} 个选项',

            style: TextStyle(
              fontSize: 13,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.68)
                  : const Color(0xFF5f6f67),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSourceChip(
                label: '聚合模式',
                selected: _currentSource == 'auto',
                accent: accent,
                isDarkMode: isDarkMode,
                onTap: () => _handleSourceChanged('auto'),
              ),
              ..._filteredSources.map(
                (source) => _buildSourceChip(
                  label: source.name,
                  selected: _currentSource == source.key,
                  accent: accent,
                  isDarkMode: isDarkMode,
                  onTap: () => _handleSourceChanged(source.key),
                ),
              ),
            ],
          ),
          if (_sourceError.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildErrorBox(_sourceError),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileSummarySection(
      Color cardColor, bool isDarkMode, Color accent) {
    return Container(
      padding: EdgeInsets.all(_mobileCompactMode ? 14 : 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_mobileCompactCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前源',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.6)
                            : const Color(0xFF708178),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentSourceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _mobileCompactMode ? 16 : 17,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : const Color(0xFF1f2d26),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: _isLoadingSources
                    ? null
                    : () => _showSourcePickerSheet(accent, isDarkMode),
                style: FilledButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  foregroundColor: accent,
                  padding: EdgeInsets.symmetric(
                    horizontal: _mobileCompactMode ? 12 : 14,
                    vertical: _mobileCompactMode ? 12 : 14,
                  ),
                  minimumSize: Size(0, _mobileCompactMode ? 42 : 48),
                ),
                icon: const Icon(LucideIcons.panelBottomOpen, size: 18),
                label: Text(
                  '切换源',
                  style: TextStyle(fontSize: _mobileCompactMode ? 13 : 14),
                ),
              ),
            ],
          ),
          SizedBox(height: _mobileCompactMode ? 12 : 14),
          Row(
            children: [
              Text(
                '分类',
                style: TextStyle(
                  fontSize: _mobileCompactMode ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF1f2d26),
                ),
              ),
              const Spacer(),
              if (_isLoadingCategories)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
              else if (_currentSource != 'auto' && _categories.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _showCategoryPickerSheet(accent, isDarkMode),
                  child: Container(
                    width: _mobileCompactMode ? 30 : 34,
                    height: _mobileCompactMode ? 30 : 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.ellipsis,
                      size: _mobileCompactMode ? 16 : 18,
                      color: accent,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: _mobileCompactHeaderSpacing),
          if (_currentSource == 'auto')
            Text(
              '请先选择具体源。',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.68)
                    : const Color(0xFF5f6f67),
              ),
            )
          else if (_categories.isEmpty && !_isLoadingCategories)
            Text(
              '当前源暂无可浏览分类。',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.68)
                    : const Color(0xFF5f6f67),
              ),
            )
          else
            SizedBox(
              height: _mobileCompactMode ? 36 : 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) =>
                    SizedBox(width: _mobileCompactMode ? 8 : 10),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final selected = _selectedCategoryId == category.id;
                  return _buildSourceChip(
                    label: category.name,
                    selected: selected,
                    accent: accent,
                    isDarkMode: isDarkMode,
                    compact: true,
                    onTap: () => _selectCategory(category.id),
                  );
                },
              ),
            ),
          if (_categoryError.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildErrorBox(_categoryError),
          ],
        ],
      ),
    );
  }

  Future<void> _selectCategory(String categoryId) async {
    if (_selectedCategoryId == categoryId) return;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {
      _selectedCategoryId = categoryId;
      _showBackToTop = false;
    });
    await _loadVideos(reset: true);
  }

  Future<void> _showCategoryPickerSheet(Color accent, bool isDarkMode) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF171d1a) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '全部分类',

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF1f2d26),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((category) {
                    return _buildSourceChip(
                      label: category.name,
                      selected: _selectedCategoryId == category.id,
                      accent: accent,
                      isDarkMode: isDarkMode,
                      compact: true,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await _selectCategory(category.id);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSourcePickerSheet(Color accent, bool isDarkMode) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF171d1a) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final visibleSources = _filteredSources;
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        '切换数据源',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? Colors.white : const Color(0xFF1f2d26),
                        ),
                      ),
                      const Spacer(),
                      if (_isLoadingSources)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索源名称、Key 或 API 地址',
                      prefixIcon: Icon(LucideIcons.search, size: 18, color: accent),
                      filled: true,
                      fillColor: isDarkMode ? const Color(0xFF101513) : const Color(0xFFF2F7F3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    children: [
                      _buildSourceSheetTile(
                        label: '聚合模式',
                        value: 'auto',
                        isDarkMode: isDarkMode,
                        accent: accent,
                      ),
                      ...visibleSources.map((source) => _buildSourceSheetTile(
                            label: source.name,
                            value: source.key,
                            subtitle: source.api,
                            isDarkMode: isDarkMode,
                            accent: accent,
                          )),
                      if (_sourceError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildErrorBox(_sourceError),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceSheetTile({
    required String label,
    required String value,
    String? subtitle,
    required bool isDarkMode,
    required Color accent,
  }) {
    final selected = _currentSource == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.12)
            : (isDarkMode ? const Color(0xFF101513) : const Color(0xFFF7FAF8)),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            Navigator.of(context).pop();
            await _handleSourceChanged(value);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? accent
                              : (isDarkMode ? Colors.white : const Color(0xFF1f2d26)),
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.56)
                                : const Color(0xFF708178),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(LucideIcons.check, size: 18, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(Color cardColor, bool isDarkMode, Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '??',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF1f2d26),
                ),
              ),
              const Spacer(),
              if (_isLoadingCategories)
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '正在拉取分类...',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.68)
                            : const Color(0xFF5f6f67),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_currentSource == 'auto')
            Text(
              '请先选择具体源。',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.68)
                    : const Color(0xFF5f6f67),
              ),
            )
          else if (_categories.isEmpty)
            Text(
              '当前源暂无可浏览分类。',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode

                    ? Colors.white.withValues(alpha: 0.68)
                    : const Color(0xFF5f6f67),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _categories.map((category) {
                final selected = _selectedCategoryId == category.id;
                return _buildSourceChip(
                  label: category.name,
                  selected: selected,
                  accent: accent,
                  isDarkMode: isDarkMode,
                  onTap: () => _selectCategory(category.id),
                );
              }).toList(),
            ),
          if (_categoryError.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildErrorBox(_categoryError),
          ],
        ],
      ),
    );
  }

  Widget _buildContentSection(Color cardColor, bool isDarkMode, Color accent) {
    final isDesktopStyle = DeviceUtils.isTablet(context) || DeviceUtils.isPC();
    if (_currentSource == 'auto') {
      return _buildEmptyCard(cardColor, isDarkMode, '请选择具体源后开始浏览。');
    }
    if (_selectedCategoryId.isEmpty && !_isLoadingCategories) {
      return _buildEmptyCard(cardColor, isDarkMode, '当前分类为空，暂时无法展示内容。');
    }
    if (_isLoadingVideos) {
      return _buildLoadingCard(cardColor, accent, '正在拉取分类内容...');
    }
    if (_videos.isEmpty) {
      return _buildEmptyCard(cardColor, isDarkMode, '该分类暂无可展示内容。');
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktopStyle) ...[
          Text(
            '分类内容',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF1f2d26),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '已加载 ${_videos.length} 条${_videos.length >= _maxGridItems ? '（已达渲染上限）' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.68)
                  : const Color(0xFF5f6f67),
            ),
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            int crossAxisCount = 3;
            if (width >= 1200) {
              crossAxisCount = 6;
            } else if (width >= 900) {
              crossAxisCount = 5;
            } else if (width >= 700) {
              crossAxisCount = 4;
            }

            final spacing = width >= 700 ? 18.0 : (_mobileCompactMode ? 8.0 : 10.0);
            final mainSpacing = width >= 700 ? 18.0 : (_mobileCompactMode ? 14.0 : 18.0);
            final cardWidth =
                (width - spacing * (crossAxisCount - 1)) / crossAxisCount;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _videos.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: mainSpacing,
                childAspectRatio: 0.46,
              ),
              itemBuilder: (context, index) {
                final item = _videos[index];
                return VideoCard(
                  videoInfo: _toVideoInfo(item),
                  from: 'search',
                  cardWidth: cardWidth,
                  onTap: () => _openPlayer(item),
                );
              },
            );
          },
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.tonal(
            onPressed: (_hasMore && !_isLoadingMore)
                ? () => _loadVideos(reset: false)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.14),
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isLoadingMore
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                      ),
                      const SizedBox(width: 10),
                      const Text('加载中...'),
                    ],
                  )
                : Text(
                    _hasMore
                        ? '加载更多'
                        : (_videos.length >= _maxGridItems ? '已达性能上限' : '已到底部'),
                  ),
          ),
        ),
      ],
    );

    if (!isDesktopStyle) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: content,
    );
  }

  Widget _buildSourceChip({
    required String label,
    required bool selected,
    required Color accent,
    required bool isDarkMode,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    final horizontalPadding = compact
        ? _mobileCompactChipHorizontalPadding
        : 14.0;
    final verticalPadding = compact
        ? _mobileCompactChipVerticalPadding
        : 10.0;
    final fontSize = compact ? _mobileCompactChipFontSize : 13.0;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : (isDarkMode ? const Color(0xFF101513) : const Color(0xFFF2F7F3)),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.45) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? accent
                : (isDarkMode ? Colors.white.withValues(alpha: 0.86) : const Color(0xFF38463f)),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFef4444).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFef4444).withValues(alpha: 0.28)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFdc2626), fontSize: 13),
      ),
    );
  }

  Widget _buildLoadingCard(Color cardColor, Color accent, String text) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            ),
            const SizedBox(width: 12),
            Text(text),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(Color cardColor, bool isDarkMode, String text) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.68)
                : const Color(0xFF5f6f67),
          ),
        ),
      ),
    );
  }
}

class _SourceBrowserVideoCacheEntry {
  const _SourceBrowserVideoCacheEntry({
    required this.videos,
    required this.page,
    required this.hasMore,
  });

  final List<SourceBrowserVideo> videos;
  final int page;
  final bool hasMore;
}

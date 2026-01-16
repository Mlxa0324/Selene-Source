import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/search_result.dart';

/// M3U8 解析和测速服务
class M3U8Service {
  final Dio _dio = Dio();

  M3U8Service() {
    // 配置 Dio
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Accept': '*/*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    };
  }

  /// 过滤 M3U8 内容中的广告标识，并将相对路径转换为绝对路径
  static String filterAdsFromM3U8(String content, String baseUrl) {
    if (content.isEmpty) return '';

    // 按行分割内容
    final lines = content.split('\n');
    final filteredLines = <String>[];

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        filteredLines.add(line);
        continue;
      }

      // 过滤 #EXT-X-DISCONTINUITY 标识
      if (trimmedLine.contains('#EXT-X-DISCONTINUITY')) {
        continue;
      }

      // 处理分片 URL 或 Key URL
      if (!trimmedLine.startsWith('#')) {
        // 这是一行 URL（分片地址）
        filteredLines.add(_resolveUrlStatic(trimmedLine, baseUrl));
      } else if (trimmedLine.startsWith('#EXT-X-KEY')) {
        // 处理加密密钥 URL
        // 格式通常为: #EXT-X-KEY:METHOD=AES-128,URI="key.php",IV=0x...
        final uriRegex = RegExp(r'URI=["\x27]([^"\x27]+)["\x27]');
        final match = uriRegex.firstMatch(trimmedLine);
        if (match != null) {
          final relativeUri = match.group(1)!;
          final absoluteUri = _resolveUrlStatic(relativeUri, baseUrl);
          filteredLines.add(trimmedLine.replaceFirst(relativeUri, absoluteUri));
        } else {
          filteredLines.add(line);
        }
      } else if (trimmedLine.startsWith('#EXT-X-MAP')) {
        // 处理 Media Initialization Section
        // 格式: #EXT-X-MAP:URI="main.mp4",BYTERANGE="1000@0"
        final uriRegex = RegExp(r'URI=["\x27]([^"\x27]+)["\x27]');
        final match = uriRegex.firstMatch(trimmedLine);
        if (match != null) {
          final relativeUri = match.group(1)!;
          final absoluteUri = _resolveUrlStatic(relativeUri, baseUrl);
          filteredLines.add(trimmedLine.replaceFirst(relativeUri, absoluteUri));
        } else {
          filteredLines.add(line);
        }
      } else {
        filteredLines.add(line);
      }
    }

    return filteredLines.join('\n');
  }

  /// 静态版本的 URL 解析
  static String _resolveUrlStatic(String url, String baseUrl) {
    if (url.startsWith('http') || url.startsWith('data:')) {
      return url;
    }
    
    try {
      final uri = Uri.parse(baseUrl);
      return uri.resolve(url).toString();
    } catch (e) {
      return url;
    }
  }

  /// 并发获取流的核心信息：分辨率、下载速度、延迟
  Future<Map<String, dynamic>> getStreamInfo(String streamUrl) async {
    try {
      // 获取片段列表
      final segments = await _getSegmentUrls(streamUrl);
      
      if (segments.isEmpty) {
        return {
          'resolution': '未知',
          'downloadSpeed': 0.0,
          'latency': 0,
          'success': false,
          'error': '未找到视频片段',
        };
      }
      
      // 并发执行三个任务
      final futures = await Future.wait([
        _getResolutionFromM3U8(streamUrl),
        _measureLatency(segments.first),
        _measureDownloadSpeed(segments),
      ]);
      
      final resolutionData = futures[0] as Map<String, int>;
      final latency = futures[1] as int;
      final downloadSpeedKBps = futures[2] as double;
      
      return {
        'resolution': resolutionData,
        'downloadSpeed': downloadSpeedKBps,
        'latency': latency,
        'success': true,
        'error': '',
      };
      
    } catch (e) {
      return {
        'resolution': {'width': 0, 'height': 0},
        'downloadSpeed': 0.0,
        'latency': 0,
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 优选最佳播放源
  Future<Map<String, dynamic>> preferBestSource(List<SearchResult> allSources) async {
    final Map<String, dynamic> allSourcesSpeed = {};
    SearchResult? bestSource;
    double maxSpeed = -1.0;

    // 为每个源进行测速（限制前 5 个源，避免耗时太长）
    final sourcesToTest = allSources.take(5).toList();
    
    final List<Future<void>> testFutures = [];
    for (var source in sourcesToTest) {
      testFutures.add(() async {
        if (source.episodes.isEmpty) return;
        
        final info = await getStreamInfo(source.episodes.first);
        debugPrint('获取到的流信息: $info');
        final speed = info['downloadSpeed'] as double;
        final latency = info['latency'] as int;
        final res = info['resolution'] as Map<String, int>;
        
        final speedStr = speed > 1024 
            ? '${(speed / 1024).toStringAsFixed(1)} MB/s' 
            : '${speed.toStringAsFixed(1)} KB/s';
        
        final quality = _getQualityLabel(res['height'] ?? 0);
        
        allSourcesSpeed['${source.source}_${source.id}'] = {
          'quality': quality,
          'loadSpeed': speedStr,
          'pingTime': '${latency}ms',
        };

        // 简单的评分逻辑：速度优先
        if (speed > maxSpeed) {
          maxSpeed = speed;
          bestSource = source;
        }
      }());
    }

    await Future.wait(testFutures);

    return {
      'bestSource': bestSource ?? allSources.first,
      'allSourcesSpeed': allSourcesSpeed,
    };
  }

  String _getQualityLabel(int height) {
    if (height >= 2160) return '4K';
    if (height >= 1080) return '1080P';
    if (height >= 720) return '720P';
    if (height >= 480) return '480P';
    if (height > 0) return '标清';
    return '未知';
  }

  /// 批量测速并提供实时回调
  Future<void> testSourcesWithCallback(
    List<SearchResult> allSources,
    Function(String sourceId, Map<String, dynamic> speedData) callback, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // 限制最大并发数，避免资源占用过高
    final sourcesToTest = allSources.take(10).toList();
    final List<Future<void>> tasks = [];

    for (var source in sourcesToTest) {
      tasks.add(() async {
        if (source.episodes.isEmpty) return;

        try {
          // 获取流核心信息
          final info = await getStreamInfo(source.episodes.first).timeout(timeout);
          
          final speed = info['downloadSpeed'] as double;
          final latency = info['latency'] as int;
          final res = info['resolution'] as Map<String, int>?;

          final speedStr = speed > 1024
              ? '${(speed / 1024).toStringAsFixed(1)} MB/s'
              : '${speed.toStringAsFixed(1)} KB/s';

          final quality = _getQualityLabel(res?['height'] ?? 0);

          final speedData = {
            'quality': quality,
            'loadSpeed': speedStr,
            'pingTime': '${latency}ms',
          };

          callback('${source.source}_${source.id}', speedData);
        } catch (e) {
          // 超时或失败返回空结果
          callback('${source.source}_${source.id}', {
            'quality': '未知',
            'loadSpeed': '超时',
            'pingTime': '---',
          });
        }
      }());
    }

    await Future.wait(tasks);
  }

  /// 获取M3U8流的片段URL列表
  Future<List<String>> _getSegmentUrls(String m3u8Url) async {
    try {
      final response = await _dio.get(m3u8Url);
      final content = response.data as String;
      return _parseSegmentsFromContent(content, m3u8Url);
    } catch (e) {
      return [];
    }
  }

  /// 从M3U8内容中解析片段URL
  List<String> _parseSegmentsFromContent(String content, String baseUrl) {
    final lines = content.split('\n').map((line) => line.trim()).toList();
    final segments = <String>[];
    
    for (final line in lines) {
      // 跳过注释和空行
      if (line.startsWith('#') || line.isEmpty) {
        continue;
      }
      
      // 这应该是一个片段URL
      final absoluteUrl = _resolveUrl(line, baseUrl);
      segments.add(absoluteUrl);
    }
    
    return segments;
  }

  /// 解析相对 URL 为绝对 URL
  String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http')) {
      return url;
    }
    
    final uri = Uri.parse(baseUrl);
    return uri.resolve(url).toString();
  }

  /// 测量延迟
  Future<int> _measureLatency(String url) async {
    final stopwatch = Stopwatch()..start();
    try {
      await _dio.head(url);
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return 999;
    }
  }

  /// 测量下载速度 (KB/s)
  Future<double> _measureDownloadSpeed(List<String> segments) async {
    if (segments.isEmpty) return 0.0;
    
    // 下载第一个片段来测速
    final url = segments.first;
    final stopwatch = Stopwatch()..start();
    
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      
      final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
      if (elapsedSeconds == 0) return 0.0;
      
      final bytes = response.data?.length ?? 0;
      final speedKBps = (bytes / 1024.0) / elapsedSeconds;
      
      return speedKBps;
    } catch (e) {
      return 0.0;
    }
  }

  /// 从M3U8文件中提取分辨率
  Future<Map<String, int>> _getResolutionFromM3U8(String url) async {
    try {
      final response = await _dio.get(url);
      final content = response.data as String;
      
      final regExp = RegExp(r'RESOLUTION=(\d+)x(\d+)');
      final match = regExp.firstMatch(content);
      
      if (match != null) {
        return {
          'width': int.parse(match.group(1)!),
          'height': int.parse(match.group(2)!),
        };
      }
    } catch (e) {
      // 忽略错误
    }
    return {'width': 0, 'height': 0};
  }
}
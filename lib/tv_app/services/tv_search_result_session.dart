import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:selene/models/search_result.dart';

/// TV 搜索页与详情页共享的一轮搜索会话。
///
/// 搜索页在发起一次资源站聚合搜索后，会把当前已经拿到的原始搜索结果、
/// 以及该轮搜索是否结束，同步写入这个会话对象。
/// 详情页进入时可直接复用这份状态，避免为同一关键词再次发起一轮 SSE 搜索。
class TvSearchResultSession extends ChangeNotifier {
  /// 创建 TV 搜索共享会话。
  TvSearchResultSession({
    required this.query,
    required this.requestVersion,
  });

  /// 本轮搜索的关键词。
  final String query;

  /// 本轮搜索在搜索页内对应的请求版本号。
  ///
  /// 仅用于辅助排查和对齐旧请求失效逻辑，不参与 UI 展示。
  final int requestVersion;

  List<SearchResult> _results = const <SearchResult>[];

  /// 当前已经拿到的原始搜索结果。
  UnmodifiableListView<SearchResult> get results =>
      UnmodifiableListView<SearchResult>(_results);

  bool _isCompleted = false;

  /// 当前搜索是否已经完整结束。
  bool get isCompleted => _isCompleted;

  bool _isInvalidated = false;

  /// 当前会话是否已被新请求或页面状态切换淘汰。
  bool get isInvalidated => _isInvalidated;

  /// 当前会话是否已结束，不再继续接收更新。
  bool get isFinished => _isCompleted || _isInvalidated;

  /// 用增量结果刷新会话快照。
  void replaceResults(List<SearchResult> results) {
    if (isFinished) {
      return;
    }
    _results = List<SearchResult>.unmodifiable(results);
    notifyListeners();
  }

  /// 用最终结果结束本轮搜索。
  void complete(List<SearchResult> results) {
    if (_isInvalidated) {
      return;
    }
    _results = List<SearchResult>.unmodifiable(results);
    _isCompleted = true;
    notifyListeners();
  }

  /// 让当前会话立即失效。
  ///
  /// 当搜索页启动了新的关键词搜索，或页面已经回退离开结果态时，
  /// 旧会话不应再继续把后续回包派发给详情页。
  void invalidate() {
    if (isFinished) {
      return;
    }
    _isInvalidated = true;
    notifyListeners();
  }
}

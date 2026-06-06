import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/tv_app/services/tv_perf_trace.dart';

void main() {
  DebugPrintCallback? originalDebugPrint;

  setUp(() {
    originalDebugPrint = debugPrint;
    TvPerfTrace.debugEnabledOverride = null;
  });

  tearDown(() {
    debugPrint = originalDebugPrint!;
    TvPerfTrace.debugEnabledOverride = null;
  });

  test('perf trace stays silent by default', () async {
    final messages = <String>[];
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        messages.add(message);
      }
    };

    TvPerfTrace.instant('TV详情页: 首屏事件');
    await TvPerfTrace.async('TV详情页: 异步阶段', () async => 1);
    final value = TvPerfTrace.sync('TV详情页: 同步阶段', () => 2);

    expect(value, 2);
    expect(messages, isEmpty);
  });

  test('perf trace logs instant and duration events when enabled', () async {
    final messages = <String>[];
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        messages.add(message);
      }
    };
    TvPerfTrace.debugEnabledOverride = true;

    TvPerfTrace.instant(
      'TV详情页: 首个可播源',
      arguments: {'sources': 3},
    );
    await TvPerfTrace.async('TV详情页: 加载精确源', () async => 'ok');
    TvPerfTrace.sync('TV详情页: 合并播放源', () => null);

    expect(
      messages,
      contains('[TV PERF] TV详情页: 首个可播源 sources=3'),
    );
    expect(
      messages.any(
        (message) => message.startsWith('[TV PERF] TV详情页: 加载精确源 '),
      ),
      isTrue,
    );
    expect(
      messages.any(
        (message) => message.startsWith('[TV PERF] TV详情页: 合并播放源 '),
      ),
      isTrue,
    );
  });
}

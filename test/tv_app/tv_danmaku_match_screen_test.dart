import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/tv_app/screens/tv_danmaku_match_screen.dart';

void main() {
  testWidgets('TV danmaku match screen only supports delete clear reset and search',
      (tester) async {
    String? submittedQuery;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvDanmakuMatchScreen(
            initialQuery: '进击的巨人 最终季',
            currentEpisodeId: 1001,
            currentEpisodeCommentCount: 3,
            onSearch: (query) async {
              submittedQuery = query;
              return DanmakuSearchResult(
                errorCode: 0,
                success: true,
                errorMessage: '',
                animes: const [],
              );
            },
            onEpisodeSelected: (_, __, ___, ____) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('进击的巨人 最终季'), findsOneWidget);
    expect(find.text('删一字'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);
    expect(find.text('恢复片名'), findsOneWidget);
    expect(find.text('开始搜索'), findsOneWidget);

    await tester.tap(find.text('删一字'));
    await tester.pumpAndSettle();
    expect(find.text('进击的巨人 最终'), findsOneWidget);

    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(find.text('进击的巨人 最终'), findsNothing);

    await tester.tap(find.text('恢复片名'));
    await tester.pumpAndSettle();
    expect(find.text('进击的巨人 最终季'), findsOneWidget);

    await tester.tap(find.text('开始搜索'));
    await tester.pumpAndSettle();
    expect(submittedQuery, '进击的巨人 最终季');
  });
}

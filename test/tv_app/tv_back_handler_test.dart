import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';

void main() {
  testWidgets(
      'tv back handler ignores repeat back events until current dispatch finishes',
      (tester) async {
    final backDispatchCompleter = Completer<bool>();
    var backDispatchCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: TvBackHandler(
          autofocus: true,
          onBackPressed: () async {
            backDispatchCount++;
            return backDispatchCompleter.future;
          },
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(backDispatchCount, 1);

    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(backDispatchCount, 1);

    backDispatchCompleter.complete(true);
    await tester.pumpAndSettle();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';

void main() {
  testWidgets('handles boundary arrow key when focused', (tester) async {
    final focusNode = FocusNode();
    var rightPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvFocusable(
            focusNode: focusNode,
            onArrowRight: () {
              rightPressed = true;
            },
            builder: (_, __) => const SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);

    expect(rightPressed, isTrue);

    focusNode.dispose();
  });

  testWidgets('scrolls focused controls into a vertical viewport',
      (tester) async {
    final focusNode = FocusNode();
    final scrollController = ScrollController();
    var gotFocus = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 160,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  const SizedBox(height: 420),
                  TvFocusable(
                    focusNode: focusNode,
                    onFocusChanged: (hasFocus) {
                      gotFocus = hasFocus;
                    },
                    builder: (_, __) => const SizedBox(
                      width: 80,
                      height: 80,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(scrollController.offset, 0);
    expect(scrollController.position.maxScrollExtent, greaterThan(0));

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(gotFocus, isTrue);
    expect(scrollController.offset, greaterThan(0));

    focusNode.dispose();
    scrollController.dispose();
  });

  testWidgets('treats space key as confirm action', (tester) async {
    final focusNode = FocusNode();
    var pressedCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvFocusable(
            focusNode: focusNode,
            onPressed: () {
              pressedCount++;
            },
            builder: (_, __) => const SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);

    expect(pressedCount, 1);

    focusNode.dispose();
  });

  testWidgets('starts scrolling horizontal focus list before last item',
      (tester) async {
    final scrollController = ScrollController();
    final focusNodes = List<FocusNode>.generate(8, (_) => FocusNode());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 760,
              height: 120,
              child: ListView.separated(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: focusNodes.length,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                separatorBuilder: (_, __) => const SizedBox(width: 18),
                itemBuilder: (context, index) {
                  return TvFocusable(
                    focusNode: focusNodes[index],
                    builder: (_, __) => Container(
                      width: 158,
                      height: 96,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(scrollController.offset, 0);

    focusNodes[4].requestFocus();
    await tester.pumpAndSettle();

    expect(scrollController.offset, greaterThan(0));
    expect(
      scrollController.offset,
      lessThanOrEqualTo(scrollController.position.maxScrollExtent),
    );

    for (final node in focusNodes) {
      node.dispose();
    }
    scrollController.dispose();
  });

  testWidgets('restores remembered focus when moving vertically between lists',
      (tester) async {
    final upperNode = FocusNode(debugLabel: 'upper');
    final lowerFirstNode = FocusNode(debugLabel: 'lower-first');
    final lowerSecondNode = FocusNode(debugLabel: 'lower-second');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TvFocusable(
                    focusNode: upperNode,
                    focusMemoryGroupKey: 'upper-list',
                    builder: (_, __) => const SizedBox(
                      width: 80,
                      height: 60,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  TvFocusable(
                    focusNode: lowerFirstNode,
                    focusMemoryGroupKey: 'lower-list',
                    builder: (_, __) => const SizedBox(
                      width: 80,
                      height: 60,
                    ),
                  ),
                  const SizedBox(width: 40),
                  TvFocusable(
                    focusNode: lowerSecondNode,
                    focusMemoryGroupKey: 'lower-list',
                    builder: (_, __) => const SizedBox(
                      width: 80,
                      height: 60,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    lowerSecondNode.requestFocus();
    await tester.pump();
    upperNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(lowerSecondNode.hasFocus, isTrue);
    expect(lowerFirstNode.hasFocus, isFalse);

    upperNode.dispose();
    lowerFirstNode.dispose();
    lowerSecondNode.dispose();
  });
}

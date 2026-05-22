import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';

void main() {
  testWidgets('plays edge shake with cooldown between repeated triggers',
      (tester) async {
    final shakeKey = GlobalKey<TvEdgeShakeState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvEdgeShake(
            key: shakeKey,
            child: const SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );

    shakeKey.currentState?.shake(AxisDirection.right);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    var transform = tester.widget<Transform>(
      find.byKey(const ValueKey('tv-edge-shake')),
    );
    expect(transform.transform.getTranslation().x, isPositive);

    shakeKey.currentState?.shake(AxisDirection.left);
    await tester.pump(const Duration(milliseconds: 32));

    transform = tester.widget<Transform>(
      find.byKey(const ValueKey('tv-edge-shake')),
    );
    expect(transform.transform.getTranslation().x, isPositive);

    await tester.pump(TvEdgeShakeState.cooldownDuration);
    shakeKey.currentState?.shake(AxisDirection.left);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    transform = tester.widget<Transform>(
      find.byKey(const ValueKey('tv-edge-shake')),
    );
    expect(transform.transform.getTranslation().x, isNegative);
  });
}

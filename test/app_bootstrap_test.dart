import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/app_bootstrap.dart';
import 'package:selene/models/app_device_type.dart';

void main() {
  testWidgets('shows TV shell when device type is Android TV', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppBootstrap(
          resolveDeviceType: () async => AppDeviceType.tv,
          normalBuilder: (_) => const Text('normal app'),
          tvBuilder: (_) => const Text('tv app'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('tv app'), findsOneWidget);
    expect(find.text('normal app'), findsNothing);
  });

  testWidgets('shows normal app when device type is not TV', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppBootstrap(
          resolveDeviceType: () async => AppDeviceType.phone,
          normalBuilder: (_) => const Text('normal app'),
          tvBuilder: (_) => const Text('tv app'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('normal app'), findsOneWidget);
    expect(find.text('tv app'), findsNothing);
  });

  testWidgets('shows normal app when device type is unknown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppBootstrap(
          resolveDeviceType: () async => AppDeviceType.unknown,
          normalBuilder: (_) => const Text('normal app'),
          tvBuilder: (_) => const Text('tv app'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('normal app'), findsOneWidget);
    expect(find.text('tv app'), findsNothing);
  });
}

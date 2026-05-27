import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/tv_app/screens/tv_settings_screen.dart';
import 'package:selene/tv_app/services/tv_account_config_service.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';

void main() {
  testWidgets('renders TV server account and danmaku settings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => const TvSettingsData(
              serverUrl: 'https://example.com',
              username: 'demo',
              password: 'secret',
              doubanImageSource: '豆瓣官方精品 CDN',
              danmakuBaseApi: 'https://danmaku.example.com/',
              danmakuSettings: DanmakuSettings(),
            ),
            loadCacheSize: () async => 128 * 1024 * 1024,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('服务器配置'), findsOneWidget);
    expect(find.text('服务器地址'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('保存配置'), findsOneWidget);
    expect(find.text('图片与弹幕'), findsOneWidget);
    expect(find.text('主题色'), findsOneWidget);
    expect(find.text('奈飞红'), findsOneWidget);
    expect(find.text('图片代理'), findsOneWidget);
    expect(find.text('豆瓣官方精品 CDN'), findsOneWidget);
    expect(find.text('弹幕服务器地址'), findsOneWidget);
    expect(find.text('弹幕开关'), findsOneWidget);
    expect(find.text('显示区域'), findsOneWidget);
    expect(find.text('缓存管理'), findsOneWidget);
    expect(find.text('缓存占用'), findsOneWidget);
    expect(find.text('128.0 MB'), findsOneWidget);
    expect(find.text('清除所有缓存'), findsOneWidget);
  });

  testWidgets('shows settings title at top left above settings panels',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final settingsTop = tester.getTopLeft(find.text('设置')).dy;
    final sectionTop = tester.getTopLeft(find.text('服务器配置')).dy;

    expect(find.text('设置'), findsOneWidget);
    expect(settingsTop, lessThanOrEqualTo(64));
    expect(settingsTop, lessThan(sectionTop));
  });

  testWidgets('keeps TV text fields readonly until confirm is pressed',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final firstTextField =
        tester.widget<TextField>(find.byType(TextField).at(0));
    firstTextField.focusNode?.requestFocus();
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField).at(0)).readOnly,
        isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField).at(0)).readOnly,
        isFalse);
  });

  testWidgets('saves TV image proxy option', (tester) async {
    String? savedImageSource;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            saveDoubanImageSource: (imageSource) async {
              savedImageSource = imageSource;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('豆瓣 CDN By CMLiussss（腾讯云）'));
    await tester.pumpAndSettle();

    expect(savedImageSource, '豆瓣 CDN By CMLiussss（腾讯云）');
    expect(find.text('图片代理已保存'), findsOneWidget);
  });

  testWidgets('saves TV theme color option', (tester) async {
    String? savedThemeKey;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            saveTheme: (themeKey) async {
              savedThemeKey = themeKey;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('奈飞红'));
    await tester.pumpAndSettle();

    expect(savedThemeKey, TvThemePalette.netflixRedKey);
    expect(find.text('主题色已保存'), findsOneWidget);
  });

  testWidgets('saves TV server account fields', (tester) async {
    TvServerCredentials? savedCredentials;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            saveAccount: (credentials) async {
              savedCredentials = credentials;
              return const TvAccountSaveResult(
                success: true,
                message: '服务器配置已保存',
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _activateTextField(tester, 0);
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://server.example.com',
    );
    await _activateTextField(tester, 1);
    await tester.enterText(find.byType(TextField).at(1), 'demo_user');
    await _activateTextField(tester, 2);
    await tester.enterText(find.byType(TextField).at(2), 'demo_password');
    await tester.tap(find.text('保存配置'));
    await tester.pumpAndSettle();

    expect(savedCredentials?.serverUrl, 'https://server.example.com');
    expect(savedCredentials?.username, 'demo_user');
    expect(savedCredentials?.password, 'demo_password');
  });

  testWidgets('saves TV danmaku endpoint and switch settings', (tester) async {
    String? savedBaseApi;
    DanmakuSettings? savedSettings;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            saveDanmaku: (baseApi, settings) async {
              savedBaseApi = baseApi;
              savedSettings = settings;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _activateTextField(tester, 3);
    await tester.enterText(
      find.byType(TextField).at(3),
      'https://danmaku.example.com',
    );
    await tester.tap(find.byType(Switch).first);
    await tester.drag(find.byType(Slider).at(0), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存弹幕配置'));
    await tester.tap(find.text('保存弹幕配置'));
    await tester.pumpAndSettle();

    expect(savedBaseApi, 'https://danmaku.example.com');
    expect(savedSettings?.enabled, isFalse);
    expect(savedSettings?.opacity, lessThan(1.0));
  });

  testWidgets('clears all TV caches from settings', (tester) async {
    var cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            loadCacheSize: () async => cleared ? 0 : 64 * 1024 * 1024,
            clearAllCaches: () async {
              cleared = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('64.0 MB'), findsOneWidget);

    await tester.ensureVisible(find.text('清除所有缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除所有缓存'));
    await tester.pumpAndSettle();

    expect(cleared, isTrue);
    expect(find.text('0 B'), findsOneWidget);
    expect(find.text('缓存已清除'), findsOneWidget);
  });

  testWidgets('escape pops TV settings page like remote back key',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          Scaffold(
                        body: TvSettingsScreen(
                          loadSettings: () async => TvSettingsData.empty(),
                        ),
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开设置页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开设置页'));
    await tester.pumpAndSettle();

    expect(find.text('服务器配置'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('打开设置页'), findsOneWidget);
    expect(find.text('服务器配置'), findsNothing);
  });
}

Future<void> _activateTextField(WidgetTester tester, int index) async {
  final textField = tester.widget<TextField>(find.byType(TextField).at(index));
  textField.focusNode?.requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

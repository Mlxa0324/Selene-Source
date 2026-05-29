import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/tv_app/screens/tv_home_screen.dart';
import 'package:selene/tv_app/screens/tv_settings_screen.dart';
import 'package:selene/tv_app/services/tv_account_config_service.dart';
import 'package:selene/tv_app/services/tv_mobile_settings_bridge.dart';
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
              adFilterEnabled: false,
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
    expect(find.text('背景色'), findsOneWidget);
    expect(find.text('奈飞红'), findsOneWidget);
    expect(find.text('深蓝灰'), findsOneWidget);
    expect(find.text('深黑夜幕'), findsOneWidget);
    expect(find.text('图片代理'), findsOneWidget);
    expect(find.text('豆瓣官方精品 CDN'), findsOneWidget);
    expect(find.text('自动去广告'), findsOneWidget);
    expect(find.text('弹幕服务器地址'), findsOneWidget);
    expect(find.text('弹幕开关'), findsOneWidget);
    expect(find.text('显示区域'), findsOneWidget);
    expect(find.text('缓存管理'), findsOneWidget);
    expect(find.text('缓存占用'), findsOneWidget);
    expect(find.text('128.0 MB'), findsOneWidget);
    expect(find.text('清除所有缓存'), findsOneWidget);
  });

  testWidgets('keeps pinned settings header above mobile scan section',
      (tester) async {
    final fakeBridge = _FakeMobileConfigBridge();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            startMobileConfigBridge: fakeBridge.start,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final settingsTop = tester.getTopLeft(find.text('设置')).dy;

    await tester.ensureVisible(find.text('手机扫码配置'));
    await tester.pumpAndSettle();

    final mobileConfigTop = tester.getTopLeft(find.text('手机扫码配置')).dy;
    final sectionTop = tester.getTopLeft(find.text('服务器配置')).dy;

    expect(find.text('设置'), findsOneWidget);
    expect(settingsTop, lessThanOrEqualTo(64));
    expect(settingsTop, lessThan(mobileConfigTop));
    expect(mobileConfigTop, lessThan(sectionTop));
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

    expect(tester.widget<TextField>(find.byType(TextField).at(0)).readOnly,
        isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField).at(0)).readOnly,
        isFalse);
  });

  testWidgets('dispatches initial remote focus to the first settings field',
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

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tv-settings-regenerate-qr-button',
    );
  });

  testWidgets('moves focus to the next TV text field on remote down key',
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

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tv-settings-username-browse',
    );
  });

  testWidgets('moves through danmaku rows in stable remote order',
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

    // 扫码区调整到顶部后，首焦点仍从服务器配置开始，向下计数减少一步。
    await _sendArrowDownTimes(tester, 6);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tv-settings-ad-filter-row',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tv-settings-danmaku-base-api-browse',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tv-settings-danmaku-enabled-row',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tv-settings-opacity-row',
    );
  });

  testWidgets('moving up from danmaku options keeps focus inside settings chain',
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

    await _sendArrowDownTimes(tester, 6);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tv-settings-ad-filter-row',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('tv-back-handler'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('tv-back-handler'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('tv-back-handler'),
    );
  });

  testWidgets(
      'moves focus across theme background and image options without dropping out',
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

    await _sendArrowDownTimes(tester, 3);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tv-settings-save-account-button',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('tv-back-handler'),
    );

    await tester.tap(find.text('深蓝灰'));
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('tv-back-handler'),
    );

    await tester.tap(find.text('Ivy 绿'));
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('tv-back-handler'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('tv-back-handler'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'tv-settings-ad-filter-row',
    );
  });

  testWidgets('keeps focused settings control in lower half of viewport',
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

    final scrollViewRect = tester.getRect(find.byType(SingleChildScrollView));
    final viewportMidpointDy = scrollViewRect.center.dy;
    final lowerHalfTargetDy =
        scrollViewRect.top + (scrollViewRect.height * 0.72);

    await _sendArrowDownTimes(tester, 6);
    final adFilterCenterDy =
        tester.getCenter(find.byKey(const ValueKey('tv-settings-ad-filter-switch'))).dy;
    expect(adFilterCenterDy, greaterThan(viewportMidpointDy));
    expect((adFilterCenterDy - lowerHalfTargetDy).abs(), lessThan(90));

    await _sendArrowDownTimes(tester, 3);
    final opacitySliderCenterDy = tester.getCenter(find.byType(Slider).first).dy;
    expect(opacitySliderCenterDy, greaterThan(viewportMidpointDy));
    expect((opacitySliderCenterDy - lowerHalfTargetDy).abs(), lessThan(90));

    await _sendArrowDownTimes(tester, 6);
    final clearCachesCenterDy = tester.getCenter(find.text('清除所有缓存')).dy;
    expect(clearCachesCenterDy, greaterThan(viewportMidpointDy));
    expect((clearCachesCenterDy - lowerHalfTargetDy).abs(), lessThan(90));
  });

  testWidgets('keeps settings page header visible after scrolling down',
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

    await _sendArrowDownTimes(tester, 15);
    await tester.pumpAndSettle();

    final viewportRect = tester.getRect(find.byType(Scaffold).first);
    final headerRect = tester.getRect(find.text('设置').first);

    expect(headerRect.top, greaterThanOrEqualTo(viewportRect.top));
    expect(headerRect.bottom, lessThanOrEqualTo(viewportRect.bottom));
  });

  testWidgets('shows mobile scan config section in TV settings',
      (tester) async {
    final fakeBridge = _FakeMobileConfigBridge();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            startMobileConfigBridge: fakeBridge.start,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('手机扫码配置'), findsOneWidget);
    expect(find.text('使用手机扫码打开配置页'), findsOneWidget);
    expect(find.text('192.168.1.8:18321'), findsOneWidget);
  });

  testWidgets('regenerate qr button requests a new share port',
      (tester) async {
    final fakeBridge = _FakeMobileConfigBridge();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            startMobileConfigBridge: fakeBridge.start,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('192.168.1.8:18321'), findsOneWidget);

    await tester.tap(find.text('重新生成二维码'));
    await tester.pumpAndSettle();

    expect(find.text('192.168.1.8:18322'), findsOneWidget);
  });

  testWidgets('reopening TV settings keeps the same mobile scan address',
      (tester) async {
    var showSettings = true;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: showSettings
                  ? TvSettingsScreen(
                      loadSettings: () async => TvSettingsData.empty(),
                      startMobileConfigBridge: (draft, onDraftSubmitted) {
                        return TvMobileSettingsBridge.startSession(
                          draft,
                          onDraftSubmitted,
                          bindAddress: InternetAddress.loopbackIPv4,
                          preferredHost: '127.0.0.1',
                        );
                      },
                    )
                  : Center(
                      child: ElevatedButton(
                        onPressed: () => setState(() {
                          showSettings = true;
                        }),
                        child: const Text('重新打开设置'),
                      ),
                    ),
              floatingActionButton: showSettings
                  ? FloatingActionButton(
                      onPressed: () => setState(() {
                        showSettings = false;
                      }),
                      child: const Icon(Icons.close),
                    )
                  : null,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('127.0.0.1:'), findsOneWidget);
    final firstAddress = tester.widget<SelectableText>(
      find.byType(SelectableText).first,
    ).data;

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新打开设置'));
    await tester.pumpAndSettle();

    final secondAddress = tester.widget<SelectableText>(
      find.byType(SelectableText).first,
    ).data;
    expect(secondAddress, firstAddress);
  });

  testWidgets('applies mobile scan draft back into TV settings form',
      (tester) async {
    final fakeBridge = _FakeMobileConfigBridge();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            startMobileConfigBridge: fakeBridge.start,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    fakeBridge.submit(
      const TvMobileSettingsDraft(
        serverUrl: 'https://tv.example.com',
        username: 'tv_user',
        password: 'tv_password',
        doubanImageSource: '豆瓣官方精品 CDN',
        adFilterEnabled: false,
        danmakuBaseApi: 'https://danmaku.tv.example.com/',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已同步手机配置，请在电视上确认保存'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      'https://tv.example.com',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
      'tv_user',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller?.text,
      'tv_password',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(3)).controller?.text,
      'https://danmaku.tv.example.com/',
    );
    expect(find.text('豆瓣官方精品 CDN'), findsWidgets);
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
    await tester.ensureVisible(find.text('豆瓣 CDN By CMLiussss（腾讯云）'));
    await tester.tap(find.text('豆瓣 CDN By CMLiussss（腾讯云）'));
    await tester.pumpAndSettle();

    expect(savedImageSource, '豆瓣 CDN By CMLiussss（腾讯云）');
    expect(find.text('图片代理已保存'), findsOneWidget);
  });

  testWidgets('saves TV ad filter option', (tester) async {
    bool? savedAdFilterEnabled;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => const TvSettingsData(
              serverUrl: '',
              username: '',
              password: '',
              adFilterEnabled: true,
              doubanImageSource: '直连',
              danmakuBaseApi: '',
              danmakuSettings: DanmakuSettings(),
            ),
            saveAdFilterEnabled: (enabled) async {
              savedAdFilterEnabled = enabled;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('tv-settings-ad-filter-switch')),
    );
    await tester
        .tap(find.byKey(const ValueKey('tv-settings-ad-filter-switch')));
    await tester.pumpAndSettle();

    expect(savedAdFilterEnabled, isFalse);
    expect(find.text('自动去广告已关闭'), findsOneWidget);
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
    await tester.ensureVisible(find.text('奈飞红'));
    await tester.tap(find.text('奈飞红'));
    await tester.pumpAndSettle();

    expect(savedThemeKey, TvThemePalette.netflixRedKey);
    expect(find.text('主题色已保存'), findsOneWidget);
  });

  testWidgets('saves TV background color option', (tester) async {
    String? savedBackgroundKey;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            saveBackground: (backgroundKey) async {
              savedBackgroundKey = backgroundKey;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('深黑夜幕'));
    await tester.tap(find.text('深黑夜幕'));
    await tester.pumpAndSettle();

    expect(savedBackgroundKey, TvThemeBackground.deepBlack.key);
    expect(find.text('背景色已保存'), findsOneWidget);
  });

  testWidgets('applies TV theme immediately after opening settings from home',
      (tester) async {
    final themeService = TvThemeService();

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: themeService,
          child: TvHomeScreen(
            loadHomeData: (_) async => TvHomeData.empty(),
            buildSettingsPage: () => TvSettingsScreen(
              loadSettings: () async => TvSettingsData.empty(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tv-top-nav-action-settings')));
    await tester.pumpAndSettle();

    Switch initialAdFilterSwitch = tester.widget<Switch>(
      find.byKey(const ValueKey('tv-settings-ad-filter-switch')),
    );
    expect(
      initialAdFilterSwitch.activeThumbColor,
      TvThemePalette.ivyGreen.accent,
    );

    await tester.ensureVisible(find.text('奈飞红'));
    await tester.tap(find.text('奈飞红'));
    await tester.pumpAndSettle();

    expect(themeService.themeKey, TvThemePalette.netflixRedKey);

    final updatedAdFilterSwitch = tester.widget<Switch>(
      find.byKey(const ValueKey('tv-settings-ad-filter-switch')),
    );
    expect(
      updatedAdFilterSwitch.activeThumbColor,
      TvThemePalette.netflixRed.accent,
    );
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
    expect(
      find.byKey(const ValueKey('tv-settings-action-notice')),
      findsOneWidget,
    );
    expect(find.text('服务器配置已保存'), findsOneWidget);
  });

  testWidgets('shows save notice inside pushed TV settings route',
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
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return TvSettingsScreen(
                          loadSettings: () async => TvSettingsData.empty(),
                          saveAccount: (credentials) async {
                            return const TvAccountSaveResult(
                              success: true,
                              message: '服务器配置已保存',
                            );
                          },
                        );
                      },
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
    await tester.ensureVisible(find.text('保存配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存配置'));
    await tester.pumpAndSettle();

    // 提示必须直接显示在当前设置页里，不能等退出页面后才露出来。
    expect(find.text('设置'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tv-settings-action-notice')),
      findsOneWidget,
    );
    expect(find.text('服务器配置已保存'), findsOneWidget);
  });

  testWidgets('shows compact error notice for TV settings main actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            saveAccount: (credentials) async {
              return const TvAccountSaveResult(
                success: false,
                message: '保存失败，请检查服务器地址',
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存配置'));
    await tester.pumpAndSettle();

    final noticeFinder =
        find.byKey(const ValueKey('tv-settings-action-notice'));
    final noticeSize = tester.getSize(noticeFinder);

    // 报错提示要明显收小，避免遮住设置页主体内容。
    expect(noticeFinder, findsOneWidget);
    expect(noticeSize.width, lessThanOrEqualTo(420));
    expect(noticeSize.height, lessThanOrEqualTo(92));
    expect(find.text('保存失败，请检查服务器地址'), findsOneWidget);
  });

  testWidgets('shows inline error notice when saving TV danmaku fails',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            loadSettings: () async => TvSettingsData.empty(),
            saveDanmaku: (baseApi, settings) async {
              throw Exception('network error');
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存弹幕配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存弹幕配置'));
    await tester.pumpAndSettle();

    final noticeFinder =
        find.byKey(const ValueKey('tv-settings-action-notice'));
    final noticeSize = tester.getSize(noticeFinder);

    expect(noticeFinder, findsOneWidget);
    expect(noticeSize.width, lessThanOrEqualTo(420));
    expect(noticeSize.height, lessThanOrEqualTo(92));
    expect(find.text('保存弹幕配置失败'), findsOneWidget);
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
    await tester.ensureVisible(
      find.byKey(const ValueKey('tv-settings-danmaku-enabled-switch')),
    );
    await tester.tap(
      find.byKey(const ValueKey('tv-settings-danmaku-enabled-switch')),
    );
    await tester.ensureVisible(find.byType(Slider).at(0));
    await tester.drag(find.byType(Slider).at(0), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存弹幕配置'));
    await tester.tap(find.text('保存弹幕配置'));
    await tester.pumpAndSettle();

    expect(savedBaseApi, 'https://danmaku.example.com');
    expect(savedSettings?.enabled, isFalse);
    expect(savedSettings?.opacity, lessThan(1.0));
    expect(
      find.byKey(const ValueKey('tv-settings-action-notice')),
      findsOneWidget,
    );
    expect(find.text('弹幕配置已保存'), findsOneWidget);
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
    expect(
      find.byKey(const ValueKey('tv-settings-action-notice')),
      findsOneWidget,
    );
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
  final key = switch (index) {
    0 => const ValueKey('tv-settings-field-server-url'),
    1 => const ValueKey('tv-settings-field-username'),
    2 => const ValueKey('tv-settings-field-password'),
    3 => const ValueKey('tv-settings-field-danmaku-base-api'),
    _ => throw ArgumentError('未知的设置输入框索引: $index'),
  };
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

class _FakeMobileConfigBridge {
  ValueNotifier<String>? _statusNotifier = ValueNotifier<String>(
    '请使用手机扫码填写配置',
  );

  int _port = 18321;

  late ValueChanged<TvMobileSettingsDraft> _onDraftSubmitted;

  Future<TvMobileSettingsBridgeSession> start(
    TvMobileSettingsDraft initialDraft,
    ValueChanged<TvMobileSettingsDraft> onDraftSubmitted,
  ) async {
    _onDraftSubmitted = onDraftSubmitted;
    final shareUri = Uri.parse('http://192.168.1.8:$_port');
    _port++;
    final statusNotifier = _statusNotifier ??=
        ValueNotifier<String>('请使用手机扫码填写配置');
    return TvMobileSettingsBridgeSession(
      shareUri: shareUri,
      statusNotifier: statusNotifier,
      updateDraft: (_) {},
      dispose: () async {
        _statusNotifier?.dispose();
        _statusNotifier = null;
      },
    );
  }

  void submit(TvMobileSettingsDraft draft) {
    _statusNotifier?.value = '已接收手机端提交';
    _onDraftSubmitted(draft);
  }
}

Future<void> _sendArrowDownTimes(WidgetTester tester, int count) async {
  for (var index = 0; index < count; index++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
  }
}

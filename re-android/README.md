# re-android

Selene 原生 Android TV 重建工程。

当前阶段仅包含：

- `app-tv` 单模块应用壳
- Compose 根入口
- 顶级 TV 导航路由定义
- 最小可运行的导航占位页面

## 运行测试

在 `re-android/` 目录内直接执行：

```bash
./gradlew :app-tv:testDebugUnitTest
```

如果本机没有全局 Android SDK 环境变量，可在命令前注入：

```bash
ANDROID_HOME=/Users/your-name/Library/Android/sdk \
ANDROID_SDK_ROOT=/Users/your-name/Library/Android/sdk \
./gradlew :app-tv:testDebugUnitTest --tests "org.moontechlab.selene.tv.app.navigation.TvDestinationTest"
```

# re-android

Selene 原生 Android TV 重建工程。

当前阶段仅包含：

- `app-tv` 单模块应用壳
- Compose 根入口
- 顶级 TV 导航路由定义
- 最小可运行的导航占位页面

## 运行测试

如果本机未在 `re-android/` 下生成 Gradle Wrapper，可通过仓库现有 Android Wrapper 执行：

```bash
../android/gradlew -p re-android :app-tv:testDebugUnitTest
```

# 修复 Kotlin TV 打开闪退

## Goal

修复 Kotlin TV 应用打开后立即闪退的问题，确保应用可以进入主界面或展示可恢复的错误状态。

## Confirmed Facts

- 近期已接入本地后台网关配置，`app-tv` 会读取 `re-android/local.gateway.properties` 中的后台地址、用户名和密码。
- TV 启动链路会创建应用容器、登录后台并加载首页数据，崩溃可能发生在启动初始化、配置读取、网络客户端创建或首页数据加载阶段。
- 本地真实网关配置文件必须继续保持 Git 忽略，仅允许提交示例配置与代码修复。
- 复现日志显示根因是 `OkHttp Dispatcher` 线程抛出 `java.lang.SecurityException: Permission denied (missing INTERNET permission?)`，`app-tv` Manifest 未声明网络权限。

## Requirements

- 必须先通过日志或可复现路径定位闪退根因，不做猜测式修复。
- 应用启动时不得因后台地址为空、格式错误、网络异常或登录失败而直接进程崩溃。
- 后台连接失败时，应由界面状态承载错误信息，允许用户后续重试或修改本地配置后重新启动。
- 不提交 `re-android/local.gateway.properties` 或其他包含本地地址、用户名、密码的文件。
- 修复范围限定在 TV 启动和后台连接稳定性，不顺带重构 UI 或扩展新功能。

## Acceptance Criteria

- [x] 可以捕获或复现当前打开闪退的错误栈，并记录根因。
- [x] 修复后 TV 应用启动不再因为网关配置或后台连接异常闪退。
- [x] 相关单元测试、lint 或构建验证通过。
- [x] Git 提交只包含本任务相关文件，不包含本地敏感配置。

## Notes

- 这是轻量崩溃修复任务，当前先保持 PRD-only；若诊断发现需要跨模块重构，再补充 `design.md` 与 `implement.md`。
- 修复后已重新安装并启动 `org.moontechlab.selene.tv.app/.MainActivity`，日志未再出现 `AndroidRuntime`、`FATAL EXCEPTION`、`missing INTERNET` 或 `Permission denied`。

# Kotlin TV 本地后台网关配置

## Goal

让 Kotlin 原生 TV 工程从本地 git-ignore 配置读取后台地址、用户名和密码，并打通登录、Cookie 会话和首页接口请求，避免开发调试时因没有后台数据只能看到空页面。

## User Value

- 本地敏感信息不进入 Git 提交。
- 开发者只需要填写一个本地配置文件即可让 `re-android` 连接真实后台。
- TV 首页等数据页可以通过真实后台接口看到数据，便于继续验证 UI 和交互。

## Confirmed Facts

- Flutter TV 端登录契约是 `POST <baseUrl>/api/login`。
- 登录请求 JSON 字段为 `username` 和 `password`。
- 登录成功后从 `Set-Cookie` 解析 Cookie，并在后续请求里通过 `Cookie` header 传递。
- Kotlin `core-network` 已有 `SeleneTvApi`、`AuthInterceptor`、`SessionCookieStore`。
- Kotlin `core-data` 已有 `TvHomeRepository`，通过 `SeleneTvApi.getDashboard()` 加载 `admin/dashboard`。
- Kotlin 当前缺少本地私密配置文件、Retrofit/OkHttp 构建入口、自动登录会话初始化，以及 `app-tv` 到真实首页仓库的装配。

## Requirements

- 新增一个 git-ignore 的本地配置文件，用于保存后台地址、用户名、密码。
- 提供可提交的示例配置文件，说明字段名但不包含真实敏感信息。
- `.gitignore` 必须覆盖真实本地配置文件，避免误提交。
- Kotlin 编译期读取本地配置并生成 `BuildConfig` 常量，未填写时保持空值。
- `core-network` 提供 Retrofit/OkHttp API 工厂，支持：
  - 标准化 baseUrl。
  - 登录 `/api/login`。
  - 从 `Set-Cookie` 解析 Cookie。
  - 请求自动携带当前 Cookie。
- `app-tv` 启动时使用本地配置初始化会话，并把首页连接到真实 `TvHomeRepository`。
- 如果本地配置缺失，页面应显示可理解的错误状态，不崩溃。
- 不把真实地址、用户名、密码写入代码、测试、PRD 或提交。

## Acceptance Criteria

- [x] 仓库中存在示例配置文件，真实配置文件被 `.gitignore` 忽略。
- [x] `git status` 不会显示真实本地配置文件。
- [x] `app-tv` 可以从本地配置创建后台会话并调用 `admin/dashboard`。
- [x] 登录成功后 Cookie 被保存并用于后续请求。
- [x] 配置缺失或登录失败时 TV 首页进入错误态并给出原因。
- [x] 相关 Kotlin 单元测试覆盖配置读取、baseUrl 标准化、登录 Cookie 解析和首页真实仓库装配。
- [x] 相关 Gradle 测试、lint 或编译验证通过；如环境阻塞，记录具体原因。

## Verification

- `git check-ignore -v re-android/local.gateway.properties`
- `./re-android/gradlew -p re-android :core-network:testDebugUnitTest :app-tv:testDebugUnitTest`
- `./re-android/gradlew -p re-android :core-network:lintDebug :app-tv:lintDebug :feature-tv-home:testDebugUnitTest`
- `git diff --check`

## Notes

- 不要在聊天、代码或提交中记录真实密码。
- 本任务只打通开发本地后台连接，不做生产账号管理 UI 和加密持久化。

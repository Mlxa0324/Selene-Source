# Frontend Spec Index

本目录记录 Flutter 前端实现规格。新增 TV 端功能前，优先阅读相关规格，确认组件边界、数据流和测试要求。

## Pre-Development Checklist

1. 阅读 [TV 模式前端实现规格](tv-mode.md)。
2. 确认改动是否属于 TV 专属模块，优先放入 `lib/tv_app/`。
3. 确认是否会影响普通端启动、登录、首页或播放器。
4. 新增交互必须补充对应 widget test 或 service test。
5. 结束前至少运行相关 `flutter test`、针对性 `flutter analyze` 和 `git diff --check`。

## Specs

- [TV 模式前端实现规格](tv-mode.md)


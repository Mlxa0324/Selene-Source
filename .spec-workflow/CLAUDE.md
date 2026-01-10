[根目录](../CLAUDE.md) > **.spec-workflow**

---

# Spec-Workflow 模块

## 模块职责

Spec-Workflow 模块提供项目文档模板和工作流规范，用于标准化需求、设计、开发等各阶段的文档编写。

---

## 入口与启动

**目录结构：**
```
.spec-workflow/
├── templates/           # 官方模板
│   ├── requirements-template.md
│   ├── product-template.md
│   ├── design-template.md
│   ├── tech-template.md
│   ├── tasks-template.md
│   └── structure-template.md
└── user-templates/      # 用户自定义模板
    └── README.md
```

---

## 对外接口

### 模板列表

**requirements-template.md**
- 需求文档模板
- 包含：背景、目标、功能需求、非功能需求

**product-template.md**
- 产品文档模板
- 包含：产品定位、用户画像、功能规划、竞品分析

**design-template.md**
- 设计文档模板
- 包含：UI 设计、交互设计、视觉规范

**tech-template.md**
- 技术文档模板
- 包含：技术选型、架构设计、接口定义

**tasks-template.md**
- 任务文档模板
- 包含：任务分解、优先级、时间估算

**structure-template.md**
- 结构文档模板
- 包含：目录结构、模块划分、依赖关系

---

## 关键依赖与配置

### 使用方式
1. 复制模板到项目目录
2. 根据实际情况填写内容
3. 提交到版本控制

### 自定义模板
- 在 `user-templates/` 目录创建自定义模板
- 遵循 Markdown 格式
- 可引用官方模板作为基础

---

## 数据模型

无数据模型（纯文档模板）

---

## 测试与质量

无需测试（静态文档）

---

## 常见问题 (FAQ)

### Q1: 如何使用模板？
1. 进入 `.spec-workflow/templates/` 目录
2. 复制需要的模板到项目目录
3. 重命名并填写内容

### Q2: 如何创建自定义模板？
1. 在 `user-templates/` 目录创建新文件
2. 参考官方模板格式
3. 添加项目特定的章节

### Q3: 模板是否强制使用？
- 不强制，仅作为参考
- 建议在团队协作中统一使用

---

## 相关文件清单

### 模板文件
- `templates/requirements-template.md` (需求模板)
- `templates/product-template.md` (产品模板)
- `templates/design-template.md` (设计模板)
- `templates/tech-template.md` (技术模板)
- `templates/tasks-template.md` (任务模板)
- `templates/structure-template.md` (结构模板)

### 说明文件
- `user-templates/README.md` (用户模板说明)

### 文件统计
- 模板文件：6
- 说明文件：1

---

## 变更记录 (Changelog)

### 2026-01-11
- 初始化模块文档
- 识别 6 个官方模板
- 记录使用方式

---

**模块版本：** 1.0.0
**最后更新：** 2026-01-11

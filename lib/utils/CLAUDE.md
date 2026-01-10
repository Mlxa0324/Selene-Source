[根目录](../../CLAUDE.md) > [lib](../) > **utils**

---

# Utils 模块

## 模块职责

Utils 模块提供应用的通用工具函数，包括设备检测、字体处理、图片 URL 转换等功能。这些工具被其他模块广泛使用。

---

## 入口与启动

**核心工具：**
- `device_utils.dart`：设备类型检测（手机/平板/桌面）
- `font_utils.dart`：字体加载和管理
- `image_url.dart`：图片 URL 处理和转换

**使用方式：**
- 所有工具类提供静态方法，无需实例化
- 按需导入使用

---

## 对外接口

### DeviceUtils

**核心方法：**
```dart
// 判断是否为平板设备
static bool isTablet(BuildContext context)

// 判断是否为竖屏平板
static bool isPortraitTablet(BuildContext context)

// 判断是否为桌面平台
static bool isDesktop()

// 判断是否为移动平台
static bool isMobile()

// 获取屏幕尺寸分类
static ScreenSize getScreenSize(BuildContext context)
```

**判断逻辑：**
- 平板：屏幕最短边 >= 600dp
- 桌面：Windows、macOS、Linux 平台
- 移动：Android、iOS 平台

### FontUtils

**核心方法：**
```dart
// 加载自定义字体
static Future<void> loadCustomFonts()

// 获取适配字体大小
static double getAdaptiveFontSize(BuildContext context, double baseSize)

// 判断是否需要使用特殊字体
static bool needsSpecialFont(String text)
```

### ImageUrl

**核心方法：**
```dart
// 转换图片 URL（处理相对路径、CDN 等）
static String convertImageUrl(String url)

// 获取缩略图 URL
static String getThumbnailUrl(String url, {int width = 300})

// 验证图片 URL 有效性
static bool isValidImageUrl(String url)
```

---

## 关键依赖与配置

### 外部依赖
- `flutter/material.dart`：UI 框架（用于 BuildContext）
- `dart:io`：平台检测

### 内部依赖
- 无内部依赖（独立工具模块）

### 配置项
- **设备判断阈值**：平板最短边 600dp（可调整）
- **字体大小缩放**：根据屏幕尺寸自适应

---

## 数据模型

### 使用的枚举
```dart
enum ScreenSize {
  small,    // 手机
  medium,   // 平板
  large,    // 桌面
}
```

---

## 测试与质量

**当前状态：** 无测试覆盖

**建议测试：**
1. **单元测试**：
   - 设备类型判断逻辑
   - 图片 URL 转换规则
   - 字体大小计算
2. **测试用例示例**：
   ```dart
   test('isTablet should return true for width >= 600', () {
     // Mock BuildContext with screen width 600
     expect(DeviceUtils.isTablet(context), true);
   });
   ```

---

## 常见问题 (FAQ)

### Q1: 如何添加新的工具函数？
1. 在 `lib/utils/` 创建新文件或在现有文件中添加
2. 定义静态方法
3. 添加清晰的注释说明用途
4. 在需要的地方导入使用

### Q2: 设备判断不准确怎么办？
- 检查 `DeviceUtils.isTablet` 的阈值是否合适
- 考虑使用 `MediaQuery.of(context).size` 获取实际尺寸
- 根据具体场景调整判断逻辑

### Q3: 如何处理不同平台的字体差异？
- 使用 `FontUtils.needsSpecialFont` 判断是否需要特殊字体
- 在 `pubspec.yaml` 中配置自定义字体
- 使用 `google_fonts` 包加载在线字体

---

## 相关文件清单

### 工具文件
- `device_utils.dart` (设备检测)
- `font_utils.dart` (字体处理)
- `image_url.dart` (图片 URL 处理)

### 文件统计
- 总文件数：3
- 代码行数：约 300-500 行（估算）
- 平均每个工具：约 100-150 行

---

## 变更记录 (Changelog)

### 2026-01-11
- 初始化模块文档
- 识别 3 个工具类
- 记录核心方法和使用场景

---

**模块版本：** 1.0.0
**最后更新：** 2026-01-11

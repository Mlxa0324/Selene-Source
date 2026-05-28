import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VersionService {
  /// 更新功能开关。
  static const bool isUpdateCheckEnabled = false;

  /// 版本详情页仍沿用仓库 Release 页格式，便于后续恢复更新功能时复用。
  static const String githubRepoUrl = 'https://github.com/MoonTechLab/Selene';
  static const String _lastCheckKey = 'last_version_check';
  static const String _dismissedVersionKey = 'dismissed_version';

  /// 检查是否有新版本。
  static Future<VersionInfo?> checkForUpdate() async {
    // 当前策略要求关闭远程更新检查，仅保留后续恢复所需的调用入口。
    if (!isUpdateCheckEnabled) {
      return null;
    }

    try {
      // 保留当前版本读取逻辑，方便后续重新接回远程版本源。
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 远程版本地址已下线，功能恢复时在这里重新接入新的版本来源。
      final remoteVersionInfo = await _fetchRemoteVersionInfo();
      if (remoteVersionInfo == null) {
        return null;
      }

      // 只在远端版本更高时返回弹窗所需数据。
      if (_isNewerVersion(currentVersion, remoteVersionInfo.latestVersion)) {
        return VersionInfo(
          currentVersion: currentVersion,
          latestVersion: remoteVersionInfo.latestVersion,
          releaseNotes: remoteVersionInfo.releaseNotes,
        );
      }

      return null;
    } catch (e) {
      debugPrint('检查版本更新失败: $e');
      return null;
    }
  }

  /// 远程版本信息读取入口。
  static Future<_RemoteVersionInfo?> _fetchRemoteVersionInfo() async {
    // 当前没有启用任何远程版本源，先返回空结果占位。
    return null;
  }

  /// 获取 GitHub Release 页面 URL。
  static String getReleaseUrl(String version) {
    return '$githubRepoUrl/releases/tag/v$version';
  }

  /// 比较版本号，判断是否有新版本。
  static bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    return false;
  }

  /// 检查是否应该显示更新提示。
  static Future<bool> shouldShowUpdatePrompt(String version) async {
    // 更新功能关闭后，不再记录和展示任何版本提示。
    if (!isUpdateCheckEnabled) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();

    // 已忽略的版本不再重复提示。
    final dismissedVersion = prefs.getString(_dismissedVersionKey);
    if (dismissedVersion == version) {
      return false;
    }

    // 同一天内最多提示一次，避免频繁打断用户。
    final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const dayInMs = 24 * 60 * 60 * 1000;

    if (now - lastCheck < dayInMs) {
      return false;
    }

    // 记录本次提示时间，供下一次节流使用。
    await prefs.setInt(_lastCheckKey, now);
    return true;
  }

  /// 标记用户已忽略某个版本。
  static Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }

  /// 清除忽略记录（用于测试或重置）。
  static Future<void> clearDismissedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedVersionKey);
  }
}

/// 远程版本信息模型。
class _RemoteVersionInfo {
  final String latestVersion;
  final String releaseNotes;

  const _RemoteVersionInfo({
    required this.latestVersion,
    required this.releaseNotes,
  });
}

class VersionInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;

  VersionInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
  });
}

import 'package:flutter/material.dart';

enum AppThemeScheme {
  classicGreen(
    storageValue: 'classic_green',
    label: '经典影院绿',
    lightSeedColor: Color(0xFF27AE60),
    darkSeedColor: Color(0xFF27AE60),
  ),
  oceanBlue(
    storageValue: 'ocean_blue',
    label: '深海蓝',
    lightSeedColor: Color(0xFF2F6BFF),
    darkSeedColor: Color(0xFF3B82F6),
  ),
  neonPurple(
    storageValue: 'neon_purple',
    label: '霓虹紫',
    lightSeedColor: Color(0xFF7C4DFF),
    darkSeedColor: Color(0xFF8B5CF6),
  ),
  sunsetOrange(
    storageValue: 'sunset_orange',
    label: '落日橙',
    lightSeedColor: Color(0xFFFF7A1A),
    darkSeedColor: Color(0xFFFB923C),
  ),
  roseRed(
    storageValue: 'rose_red',
    label: '玫瑰红',
    lightSeedColor: Color(0xFFE54861),
    darkSeedColor: Color(0xFFF43F5E),
  );

  const AppThemeScheme({
    required this.storageValue,
    required this.label,
    required this.lightSeedColor,
    required this.darkSeedColor,
  });

  final String storageValue;
  final String label;
  final Color lightSeedColor;
  final Color darkSeedColor;

  Color seedColorFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkSeedColor : lightSeedColor;
  }

  static AppThemeScheme fromStorageValue(String? value) {
    return AppThemeScheme.values.firstWhere(
      (scheme) => scheme.storageValue == value,
      orElse: () => AppThemeScheme.classicGreen,
    );
  }
}

const AppThemeScheme kDefaultAppThemeScheme = AppThemeScheme.classicGreen;

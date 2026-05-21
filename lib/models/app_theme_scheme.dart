import 'package:flutter/material.dart';

enum AppThemeScheme {
  classicGreen(
    storageValue: 'classic_green',
    label: '经典影院绿',
    lightSeedColor: Color(0xFF27AE60),
    darkSeedColor: Color(0xFF27AE60),
  ),
  netflixRed(
    storageValue: 'netflix_red',
    label: '奈飞红',
    lightSeedColor: Color(0xFFE50914),
    darkSeedColor: Color(0xFFE50914),
  ),
  clearBlue(
    storageValue: 'clear_blue',
    label: '清澈蓝',
    lightSeedColor: Color(0xFF0393E7),
    darkSeedColor: Color(0xFF0393E7),
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
    if (value == 'ocean_blue') {
      return AppThemeScheme.clearBlue;
    }

    return AppThemeScheme.values.firstWhere(
      (scheme) => scheme.storageValue == value,
      orElse: () => AppThemeScheme.classicGreen,
    );
  }
}

const AppThemeScheme kDefaultAppThemeScheme = AppThemeScheme.classicGreen;

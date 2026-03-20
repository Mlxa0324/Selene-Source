import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;

class FontUtils {
  static List<String>? get _platformFontFallbacks {
    if (Platform.isIOS || Platform.isMacOS) {
      return const [
        'PingFang SC',
        'Hiragino Sans GB',
        'Heiti SC',
        'Arial Unicode MS',
      ];
    }

    // if (Platform.isAndroid) {
    //   return const [
    //     'Noto Sans CJK SC',
    //     'Noto Sans SC',
    //     'sans-serif',
    //   ];
    // }

    return null;
  }

  /// 获取 Poppins 字体样式，Windows 下使用微软雅黑
  static TextStyle poppins({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) {
    if (Platform.isWindows) {
      return TextStyle(
        fontFamily: 'Microsoft YaHei',
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.w500,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
      );
    }

    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
    ).copyWith(
      fontFamilyFallback: _platformFontFallbacks,
    );
  }

  /// 获取 Source Code Pro 字体样式，所有平台都使用 Google Fonts
  static TextStyle sourceCodePro({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.sourceCodePro(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
    );
  }
}

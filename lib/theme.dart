import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();
  static const Color color = Colors.deepPurpleAccent;
  static final defaultTheme =
      ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: color),
        useMaterial3: true,
      ).copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: primaryElevatedButtonStyle,
        ),
        inputDecorationTheme: borderedInput,
        // showModalBottomSheet的圆角
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),
        textTheme: ThemeData.light().textTheme.copyWith(
          bodyLarge: const TextStyle(fontSize: 17, color: Colors.black),
          bodyMedium: const TextStyle(fontSize: 15, color: Colors.black),
          bodySmall: const TextStyle(fontSize: 12, color: Colors.black),
        ),
      );

  /// 深色背景的按钮
  static final primaryElevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: color, // 按钮背景色
    foregroundColor: Colors.white, // 文字颜色
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    elevation: 1,
  );

  /// 浅色背景的按钮
  static final secondaryElevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: color,
    side: primaryOutlineInputBorder.borderSide,
    elevation: 0,
  );

  static final disabledElevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.grey[300],
    foregroundColor: Colors.white,
    side: BorderSide(color: Colors.grey, width: 1.2),
    elevation: 0,
  );

  /// 输入类的样式：边框
  static const primaryOutlineInputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: color, width: 1.2),
    borderRadius: BorderRadius.all(Radius.circular(8.0)),
  );


  /// 输入类的样式：有边框
  static const borderedInput = InputDecorationTheme(
    // 手机上focus不好取消，所以不设置focus
    border: primaryOutlineInputBorder,
    enabledBorder: primaryOutlineInputBorder,
    focusedBorder: primaryOutlineInputBorder,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
  );

  /// 重要的输入框（搜索框）样式
  static const headOutlineInputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: color, width: 1.2),
    borderRadius: BorderRadius.all(Radius.circular(999)),
  );
}

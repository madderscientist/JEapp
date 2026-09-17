import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// MiSans VF 的 Android 字重到字体 wght 轴值的映射
///
/// Flutter PR #175771 从 3.39.0-0.0.pre 引入、在稳定版 3.41 发布，使 FontWeight 除了选择字体实例，还会自动把同一数值写入可变字体的 wght 轴。
/// 小米/红米使用 MiSans VF 时，常规字重原本对应轴值 330；升级后直接写入 400，会让正文看起来更粗，因此需要按系统配置的对应关系恢复各档字重。
/// https://github.com/flutter/flutter/pull/175771
/// https://docs.flutter.dev/release/breaking-changes/font-weight-variation
class MiSansFontWeight {
  MiSansFontWeight._();

  /// 与 FontWeight.values 的 w100 到 w900 一一对应
  ///
  /// 取自已验证小米设备的 /system/etc/fonts.xml，w600、w700 均对应 450。
  /// 这是系统字重映射，不等同于字体中命名实例的刻度，也不代表系统粗细滑块设置。
  static const values = [
    FontWeight(150),
    FontWeight(200),
    FontWeight(250),
    FontWeight(330),
    FontWeight(380),
    FontWeight(450),
    FontWeight(450),
    FontWeight(520),
    FontWeight(630),
  ];
}

/// 默认系统字体的统一字重入口，启动时选择映射表，读取时不再检测字体
///
/// 显式字重使用 AdaptedFontWeight.bold 等成员；monospace 等指定字体继续使用 FontWeight。
/// 选择发生在运行时，使用这些成员的 TextStyle 不能声明为 const。
class AdaptedFontWeight {
  AdaptedFontWeight._();

  static List<FontWeight> _values = FontWeight.values;

  static FontWeight get w100 => _values[0];
  static FontWeight get w200 => _values[1];
  static FontWeight get w300 => _values[2];
  static FontWeight get w400 => _values[3];
  static FontWeight get w500 => _values[4];
  static FontWeight get w600 => _values[5];
  static FontWeight get w700 => _values[6];
  static FontWeight get w800 => _values[7];
  static FontWeight get w900 => _values[8];
  static FontWeight get normal => w400;
  static FontWeight get bold => w700;

  /// 将主题中的标准字重换成选中表的值，非标准字重保持原样
  static FontWeight _resolve(FontWeight weight) {
    final index = FontWeight.values.indexOf(weight);
    return index < 0 ? weight : _values[index];
  }
}

class AppTheme {
  AppTheme._();
  static const Color color = Colors.deepPurpleAccent;
  static const _fontChannel = MethodChannel(
    'com.madderscientist.je/system_font',
  );
  static ThemeData _theme = _defaultTheme;
  static ThemeData get defaultTheme => _theme;

  /// 在 runApp 前等待原生字体检测，统一选择字重表并生成主题
  ///
  /// 只对实际检测到的 MiSans 启用修正；非 Android 或通道不可用时使用 Flutter 默认值。
  /// 启动后更换系统字体需重新启动应用，本方法不监听系统字体或粗细滑块的变化。
  static Future<void> initSystemFont() async {
    var usesMiSans = false;
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
      usesMiSans = await _fontChannel.invokeMethod<bool>('usesMiSans') ?? false;
    } on PlatformException {
      usesMiSans = false;
    } on MissingPluginException {
      usesMiSans = false;
    } finally {
      AdaptedFontWeight._values = usesMiSans
          ? MiSansFontWeight.values
          : FontWeight.values;
      // 每次都从未适配的基础主题生成，避免重复初始化时再次映射已转换的字重
      _theme = usesMiSans
          ? _defaultTheme.copyWith(
              textTheme: _systemTextTheme(_defaultTheme.textTheme),
              primaryTextTheme: _systemTextTheme(
                _defaultTheme.primaryTextTheme,
              ),
            )
          : _defaultTheme;
    }
  }

  /// 只校正主题各级文字的字重，保留字号、颜色等其余属性
  ///
  /// 覆盖继承主题的文字；控件显式指定的字重仍需使用 AdaptedFontWeight。
  /// 未指定字重按 normal 映射，不设置固定 wght 轴，以免覆盖子样式的粗体层级。
  static TextTheme _systemTextTheme(TextTheme theme) {
    TextStyle? correct(TextStyle? style) => style?.copyWith(
      fontWeight: AdaptedFontWeight._resolve(
        style.fontWeight ?? FontWeight.normal,
      ),
    );
    return theme.copyWith(
      displayLarge: correct(theme.displayLarge),
      displayMedium: correct(theme.displayMedium),
      displaySmall: correct(theme.displaySmall),
      headlineLarge: correct(theme.headlineLarge),
      headlineMedium: correct(theme.headlineMedium),
      headlineSmall: correct(theme.headlineSmall),
      titleLarge: correct(theme.titleLarge),
      titleMedium: correct(theme.titleMedium),
      titleSmall: correct(theme.titleSmall),
      bodyLarge: correct(theme.bodyLarge),
      bodyMedium: correct(theme.bodyMedium),
      bodySmall: correct(theme.bodySmall),
      labelLarge: correct(theme.labelLarge),
      labelMedium: correct(theme.labelMedium),
      labelSmall: correct(theme.labelSmall),
    );
  }

  static final _defaultTheme =
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

  static const contentPadding = EdgeInsets.symmetric(vertical: 7, horizontal: 10);

  /// 深色背景的按钮
  static final primaryElevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: color, // 按钮背景色
    foregroundColor: Colors.white, // 文字颜色
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    elevation: 1,
    padding: AppTheme.contentPadding,
  );

  /// 浅色背景的按钮
  static final secondaryElevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: color,
    side: primaryOutlineInputBorder.borderSide,
    elevation: 0,
    padding: AppTheme.contentPadding,
  );

  static final disabledElevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.grey[300],
    foregroundColor: Colors.white,
    side: BorderSide(color: Colors.grey, width: 1.2),
    elevation: 0,
    padding: AppTheme.contentPadding,
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
    contentPadding: AppTheme.contentPadding,
  );

  /// 重要的输入框（搜索框）样式
  static const headOutlineInputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: color, width: 1.2),
    borderRadius: BorderRadius.all(Radius.circular(999)),
  );
}

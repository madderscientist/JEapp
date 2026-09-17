package com.madderscientist.je;

import android.graphics.Paint;
import android.graphics.Typeface;
import android.graphics.text.PositionedGlyphs;
import android.graphics.text.TextRunShaper;
import android.os.Build;
import android.util.Log;

import java.io.File;
import java.io.IOException;
import java.util.Locale;

import com.ryanheise.audioservice.AudioServiceActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/** 保留后台音频 Activity 行为，并向 Dart 提供系统字体检测 */
public class MainActivity extends AudioServiceActivity {
	/**
	 * 注册 system_font 通道，供 AppTheme.initSystemFont 在启动时查询是否启用 MiSans 适配
	 * 先调用父类保留原有引擎配置；这里只返回检测结果，字重映射由 Dart 端完成
	 */
	@Override
	public void configureFlutterEngine(FlutterEngine flutterEngine) {
		super.configureFlutterEngine(flutterEngine);
		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
				"com.madderscientist.je/system_font").setMethodCallHandler((call, result) -> {
					if (call.method.equals("usesMiSans")) {
						boolean usesMiSans = usesMiSans();
						Log.i("JEFont", "MiSans correction enabled: " + usesMiSans);
						result.success(usesMiSans);
					} else {
						result.notImplemented();
					}
				});
	}

	/**
	 * 检查默认字体排版的英文、数字和中文样本是否全部命中已验证的 MiSans VF 文件
	 * 使用实际字形的字体文件而非手机品牌判断，避免小米用户换字体后仍被套用 MiSans 映射
	 * TextRunShaper 需要 Android 12；低版本、混合字体或无法识别时返回 false，保持默认字重
	 * 本方法不读取系统粗细滑块，也不修改系统字体
	 */
	private boolean usesMiSans() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false;
		try {
			Paint paint = new Paint();
			paint.setTypeface(Typeface.DEFAULT);
			String sample = "Aa0\u4e2d";
			PositionedGlyphs glyphs = TextRunShaper.shapeTextRun(
					sample, 0, sample.length(), 0, sample.length(), 0, 0, false, paint);
			if (glyphs.glyphCount() == 0) return false;
			// 逐个检查以排除样本中的字体回退；解析真实路径后只接受已验证的文件名
			// 不用 Font.getAxes() 判定：可变字体的默认实例也可能返回空轴列表
			for (int index = 0; index < glyphs.glyphCount(); index++) {
				File file = glyphs.getFont(index).getFile();
				if (file == null) return false;
				String name = file.getCanonicalFile().getName().toLowerCase(Locale.ROOT);
				if (!name.equals("misansvf.ttf") && !name.equals("misansvf_overlay.ttf")) {
					return false;
				}
			}
			return true;
		} catch (IOException | RuntimeException error) {
			Log.w("JEFont", "Unable to identify the default system font", error);
			return false;
		}
	}
}
import 'package:je/utils/file.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/list_notifier.dart';

export 'utils/list_notifier.dart';

class Config {
  Config._();

  static const double navBarTopPadding = 10;

  static const double searchBarPadding = 20;
  static const double searchBarHeight = 48;
  static const double initSearchBarTopRatio = 0.3;
  static const double initScoreListTopRatio = 0.55;
  static const int home2searchDuration = 680; // ms
  static const int keyboardAnimationDuration = 450; // ms

  static const double capsuleFontSize = 12;

  static late SharedPreferencesWithCache pref;
  static const String _historyKey = 'searchHistory';
  static const String _keyboardHeightKey = 'keyboardHeight';
  static const String _networkBannerKey = 'networkBanner';
  static const String _networkBannerURLKey = 'networkBannerURL';

  static final ListNotifier<String> history = ListNotifier([]);

  static Future<void> init() {
    return Future.wait([initLocalScores(), initPreferences()]);
  }

  static Future<void> initPreferences() {
    return SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: <String>{
          _keyboardHeightKey,
          _historyKey,
          _networkBannerKey,
          _networkBannerURLKey,
        },
      ),
    ).then((pref_) {
      pref = pref_;
      history.value = pref_.getStringList(_historyKey) ?? [];
    });
  }

  static Future<void> initLocalScores() {
    return FileUtils.listFiles(localScorePath, false, '.md').then((files) {
      files.sort((a, b) => a.path.compareTo(b.path));
      localScores.value = files;
    });
  }

  /// @brief 增加历史
  static Future<void> addHistory(String h) async {
    // 如果之前有则拉到最前面
    history.value.remove(h);
    history.value.insert(0, h);
    history.notify();
    return pref.setStringList(_historyKey, history.value);
  }

  /// @brief 删除历史
  static Future<void> deleteHistory(String h) {
    history.value.remove(h);
    history.notify();
    return pref.setStringList(_historyKey, history.value);
  }

  /// @brief 键盘高度
  static double get keyboardHeight {
    return pref.getDouble(_keyboardHeightKey) ?? 0;
  }

  static set keyboardHeight(double value) {
    pref.setDouble(_keyboardHeightKey, value);
  }

  /// @brief 获取主页网络头图开关
  static bool get networkBanner {
    return pref.getBool(_networkBannerKey) ?? false;
  }

  static set networkBanner(bool value) {
    pref.setBool(_networkBannerKey, value);
  }

  /// @brief 获取网络头图的URL
  static String get networkBannerURL {
    return pref.getString(_networkBannerURLKey) ??
        'https://imgapi.lie.moe/random?sort=random';
  }

  static set networkBannerURL(String? value) {
    if (value == null || value.isEmpty) {
      pref.remove(_networkBannerURLKey);
    } else {
      pref.setString(_networkBannerURLKey, value);
    }
  }

  static const String searchBarHeroTag = 'searchBarHero';

  static const localScorePath = 'scores';
  static final ListNotifier<File> localScores = ListNotifier([]);

  /// 有重复的名称则返回true
  static bool checkRepeatName(String filename) {
    return Config.localScores.value.any(
      (f) => p.basenameWithoutExtension(f.path) == filename,
    );
  }

  /// @brief 添加本地曲谱 不负责保存
  static void addLocalScore(File file) {
    localScores.value.add(file);
    localScores.notify();
  }

  /// @brief 删除本地曲谱
  static Future<void> deleteLocalScore(File file) async {
    await file.delete();
    localScores.value.remove(file);
    localScores.notify();
  }
}

String nocacheURL(String url) {
  if (url.contains('?')) {
    return '$url&t=${DateTime.now().millisecondsSinceEpoch}';
  } else {
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }
}

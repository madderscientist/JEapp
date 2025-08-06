import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toastification/toastification.dart';
import '../config.dart';
import '../synthesizer/synth_worker.dart';
import '../utils/action.dart';
import '../utils/file.dart';
import '../theme.dart';
import '../utils/update.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final ValueNotifier<String> localScorePath = ValueNotifier('');
  final ValueNotifier<bool> showBannerInput = ValueNotifier(
    Config.networkBanner,
  );
  final TextEditingController _bannerController = TextEditingController(
    text: Config.networkBannerURL,
  );
  final ValueNotifier<bool> wakelockSwitch = ValueNotifier(Config.wakelock);
  final ValueNotifier<int> selectedTimbre = ValueNotifier(Config.defaultTimbre);

  @override
  void initState() {
    super.initState();
    // 初始化本地曲谱路径
    FileUtils.publicPath.then((path) {
      localScorePath.value = '$path/${Config.localScorePath}';
    });
  }

  @override
  void dispose() {
    localScorePath.dispose();
    showBannerInput.dispose();
    _bannerController.dispose();
    wakelockSwitch.dispose();
    selectedTimbre.dispose();
    super.dispose();
  }

  Widget _buildVersion() {
    return ListTile(
      title: const Text('检查更新'),
      onTap: () {
        appUpdateCheck(context);
      },
    );
  }

  Widget _buildLocalPath(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localScorePath,
      builder: (context, value, child) {
        return ListTile(
          title: const Text('本地曲谱存储路径'),
          subtitle: Text(value),
          onTap: () async {
            openFolder(value);
          },
          onLongPress: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              toastification.show(
                context: context,
                style: ToastificationStyle.simple,
                title: Text("已复制 (￣▽￣)V"),
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                alignment: Alignment.bottomCenter,
                autoCloseDuration: const Duration(seconds: 2),
                borderRadius: BorderRadius.circular(12.0),
                showProgressBar: false,
                dragToClose: true,
                applyBlurEffect: false,
              );
            }
          },
        );
      },
    );
  }

  List<Widget> _buildHomeBanner(BuildContext context) {
    return [
      ValueListenableBuilder<bool>(
        valueListenable: showBannerInput,
        builder: (context, showInput, child) {
          return SwitchListTile(
            title: const Text('主页使用网络图片'),
            value: showInput,
            onChanged: (bool value) {
              showBannerInput.value = value;
              Config.networkBanner = value;
              toastification.show(
                context: context,
                style: ToastificationStyle.simple,
                title: Text('重启应用才生效哦~'),
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                alignment: Alignment.bottomCenter,
                autoCloseDuration: const Duration(seconds: 2),
                borderRadius: BorderRadius.circular(12.0),
                showProgressBar: false,
                dragToClose: true,
                applyBlurEffect: false,
              );
            },
          );
        },
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: ValueListenableBuilder<bool>(
            valueListenable: showBannerInput,
            builder: (context, showInput, child) {
              return showInput
                  ? Padding(
                      key: const ValueKey('networkBannerInput'),
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        bottom: 10.0,
                      ),
                      child: TextField(
                        controller: _bannerController,
                        decoration: InputDecoration(
                          labelText: '图片api',
                          hintText: Config.networkBannerURL,
                          hintStyle: TextStyle(
                            color: AppTheme.color.withAlpha(128),
                          ),
                        ),
                        onTapOutside: (event) {
                          FocusScope.of(context).unfocus();
                          Config.networkBannerURL = _bannerController.text
                              .trim();
                        },
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ),
      ),
    ];
  }

  Widget _buildLogOut(BuildContext context) {
    return ListTile(
      title: const Text('退出登录'),
      onTap: () {
        Config.githubToken = null;
        toastification.show(
          context: context,
          type: ToastificationType.info,
          style: ToastificationStyle.flatColored,
          title: const Text('已退出登录'),
          alignment: Alignment.bottomCenter,
          autoCloseDuration: const Duration(seconds: 2),
          borderRadius: BorderRadius.circular(12.0),
          showProgressBar: false,
          dragToClose: true,
          applyBlurEffect: false,
        );
      },
    );
  }

  Widget _buildWakelockSwitch(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: wakelockSwitch,
      builder: (context, value, child) {
        return SwitchListTile(
          title: const Text('曲谱界面屏幕常亮'),
          value: value,
          onChanged: (bool newValue) {
            wakelockSwitch.value = newValue;
            Config.wakelock = newValue;
          },
        );
      },
    );
  }

  Widget _buildTimbreSelection(BuildContext context) {
    return ListTile(
      title: const Text('播放音色'),
      trailing: ValueListenableBuilder<int>(
        valueListenable: selectedTimbre,
        builder: (context, value, child) {
          return DropdownButton<int>(
            value: value,
            items: List.generate(
              Config.timbres.length,
              (index) => DropdownMenuItem(
                value: index,
                child: Text(Config.timbres[index]),
              ),
            ),
            onChanged: (int? newValue) {
              if (newValue != null) {
                selectedTimbre.value = newValue;
                Config.defaultTimbre = newValue;
                if (IsolateSynthesizer.created) {
                  IsolateSynthesizer.instance.send(
                    ChangePreset(
                      channel: 0,
                      preset: Config.defaultTimbre,
                    ),
                  );
                }
              }
            },
            underline: SizedBox(), // 去掉下划线更像Tile
          );
        },
      ),
    );
  }

  static const _divider = Divider(
    height: 1,
    thickness: 1,
    indent: 16,
    endIndent: 16,
    color: Colors.grey,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildVersion(),
            _divider,
            _buildLocalPath(context),
            _divider,
            ..._buildHomeBanner(context),
            _divider,
            _buildWakelockSwitch(context),
            _divider,
            _buildTimbreSelection(context),
            _divider,
            _buildLogOut(context),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';
import 'synthesizer/synth_worker.dart';
import 'components/home.dart';
import 'components/mine.dart';
import 'components/tool.dart';
import 'config.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await Config.init(); // 初始化 pref 和相关配置
  runApp(
    MaterialApp(
      title: 'justice eternal',
      theme: AppTheme.defaultTheme,
      home: const Main(),
    ),
  );
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  int _currentIndex = 0;
  final LazyNotifier<bool> _mainShowTop = LazyNotifier(false);  // home是否在顶部
  final ScrollController _homeScrollController = ScrollController();

  late final List<Widget> _pages = [
    Home(
      scrollController: _homeScrollController,
      show2top: _mainShowTop,
    ),
    Tool(),
    Mine(),
  ];

  @override
  void initState() {
    super.initState();
    // quickAction 热启动正常，冷启动会有两个页面。在Tool.openPanel中进行了去重
    final QuickActions quickActions = const QuickActions();
    quickActions.initialize((String shortcutType) {
      switch (shortcutType) {
        case 'tool-panel':
          Tool.openPanel(context);
          break;
        case 'tool-tuner':
          Tool.openTuner(context);
          break;
        case 'tool-metronome':
          Tool.openMetronome(context);
          break;
      }
    });
    quickActions.setShortcutItems([
      const ShortcutItem(type: 'tool-panel', localizedTitle: '转调/播放器'),
      const ShortcutItem(type: 'tool-tuner', localizedTitle: '调音器'),
      const ShortcutItem(type: 'tool-metronome', localizedTitle: '节拍器'),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _mainShowTop.dispose();
    // ignore: deprecated_member_use_from_same_package
    IsolateSynthesizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 导航栏有毛玻璃，因此内容要延展到导航栏内部，不用SafeArea
    // 但要避开系统的导航栏，所以加了个padding
    return Scaffold(
      // 弹出键盘时会导致较大的背景图片被缩放 在home和srearch的切换中发现 所以取消键盘对屏幕的影响
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor,
                    // Theme.of(context).colorScheme.secondaryContainer,
                    Colors.white,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),
            IndexedStack(index: _currentIndex, children: _pages),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      extendBody: true,
      backgroundColor: Colors.white,
    );
  }

  /// @brief 一个好看的底部导航栏
  Widget _buildBottomNavigationBar() {
    return ClipRRect(
      // 上圆角
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xFFF3F0FC),
        // backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0, // 关闭自带阴影
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.grey[500],
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            if (_currentIndex == 0 && index == 0 && _mainShowTop.value) {
              _homeScrollController.animateTo(
                0.0,
                duration: const Duration(
                  milliseconds: Config.home2searchDuration,
                ),
                curve: Curves.easeInOut,
              );
            }
            _currentIndex = index;
          });
          FocusManager.instance.primaryFocus?.unfocus();
        },
        items: [
          BottomNavigationBarItem(
            label: '找谱',
            icon: Padding(
              padding: EdgeInsets.only(top: Config.navBarTopPadding),
              child: ValueListenableBuilder<bool>(
                valueListenable: _mainShowTop,
                builder: (context, show2Top, child) {
                  return Icon(
                    show2Top && _currentIndex == 0
                        ? Icons.arrow_upward
                        : Icons.home,
                  );
                },
              ),
            ),
          ),
          const BottomNavigationBarItem(
            label: '工具',
            icon: Padding(
              padding: EdgeInsets.only(top: Config.navBarTopPadding),
              child: Icon(Icons.handyman),
            ),
          ),
          const BottomNavigationBarItem(
            label: '我的',
            icon: Padding(
              padding: EdgeInsets.only(top: Config.navBarTopPadding),
              child: Icon(Icons.person),
            ),
          ),
        ],
      ),
    );
  }
}
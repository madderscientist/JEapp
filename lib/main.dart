import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _mainShowTop = false; // home是否在顶部
  final ScrollController _homeScrollController = ScrollController();

  late final List<Widget> _pages = [
    Home(
      scrollController: _homeScrollController,
      ifToTop: (i) => setState(() => _mainShowTop = i),
    ),
    Tool(),
    Mine(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
            if (_currentIndex == 0 && index == 0 && _mainShowTop) {
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
            icon: Padding(
              padding: EdgeInsets.only(top: Config.navBarTopPadding),
              child: Icon(
                _mainShowTop && _currentIndex == 0
                    ? Icons.arrow_upward
                    : Icons.home,
              ),
            ),
            label: '找谱',
          ),
          const BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(top: Config.navBarTopPadding),
              child: Icon(Icons.handyman),
            ),
            label: '工具',
          ),
          const BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(top: Config.navBarTopPadding),
              child: Icon(Icons.person),
            ),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

// Widget _buildBottomNavigationBar() {
//   return Container(
//     decoration: BoxDecoration(
//       color: Colors.transparent,
//       // 阴影
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withAlpha(24),
//           offset: const Offset(0, -3), // 向上投影
//           blurRadius: 16,
//           spreadRadius: 2,
//         ),
//       ],
//     ),
//     child: ClipRRect(
//       // 上圆角
//       borderRadius: const BorderRadius.only(
//         topLeft: Radius.circular(20),
//         topRight: Radius.circular(20),
//       ),
//       child: Stack(
//         children: [
//           // 毛玻璃层
//           BackdropFilter(
//             filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
//             child: Container(
//               color: Theme.of(
//                 context,
//               ).colorScheme.primaryContainer.withAlpha(96),
//               height: kBottomNavigationBarHeight + Config.navBarTopPadding,
//             ),
//           ),
//           BottomNavigationBar(
//             type: BottomNavigationBarType.fixed,
//             backgroundColor: Colors.transparent,
//             elevation: 0, // 关闭自带阴影
//             selectedItemColor: Colors.purpleAccent,
//             unselectedItemColor: Colors.grey[500],
//             currentIndex: _currentIndex,
//             onTap: (int index) {
//               setState(() {
//                 if (_currentIndex == 0 && index == 0 && _mainShowTop) {
//                   _homeScrollController.animateTo(
//                     0.0,
//                     duration: const Duration(
//                       milliseconds: Config.home2searchDuration,
//                     ),
//                     curve: Curves.easeInOut,
//                   );
//                 }
//                 _currentIndex = index;
//               });
//             },
//             items: [
//               BottomNavigationBarItem(
//                 icon: Padding(
//                   padding: EdgeInsets.only(top: Config.navBarTopPadding),
//                   child: Icon(
//                     _mainShowTop && _currentIndex == 0
//                         ? Icons.arrow_upward
//                         : Icons.home,
//                   ),
//                 ),
//                 label: '找谱',
//               ),
//               const BottomNavigationBarItem(
//                 icon: Padding(
//                   padding: EdgeInsets.only(top: Config.navBarTopPadding),
//                   child: Icon(Icons.handyman),
//                 ),
//                 label: '工具',
//               ),
//               const BottomNavigationBarItem(
//                 icon: Padding(
//                   padding: EdgeInsets.only(top: Config.navBarTopPadding),
//                   child: Icon(Icons.person),
//                 ),
//                 label: '我的',
//               ),
//             ],
//           ),
//           // 顶部内部高光突起
//           Positioned(
//             top: 0,
//             left: 0,
//             right: 0,
//             child: Container(
//               height: 2,
//               color: const Color(0x66FFFFFF), // 纯色横线，覆盖圆角
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }

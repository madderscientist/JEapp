import 'package:flutter/material.dart';
import '../mdEditor/panel.dart';
import '../metronome/metronome.dart';
import '../timefrequency/tuner.dart';

class Tool extends StatelessWidget {
  const Tool({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsetsGeometry.only(
          top: MediaQuery.of(context).padding.top,
          bottom: MediaQuery.of(context).padding.bottom,
          left: 4,
          right: 4,
        ),
        child: Column(
          spacing: 10,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Tool.openMetronome(context),
              child: Image.asset('assets/tools/metronome.png'),
            ),
            GestureDetector(
              onTap: () => Tool.openTuner(context),
              child: Image.asset('assets/tools/tuner.png'),
            ),
            GestureDetector(
              onTap: () => Tool.openPanel(context),
              child: Image.asset('assets/tools/player.png'),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isNavigating = false;  // 由于Navigator.push异步，因此要锁一下

  static Future<void> openPanel(BuildContext context) async {
    if (_isRouteInStack(context, '/panel')) return;
    _isNavigating = true;
    try {
      return Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/panel'),
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('转调/播放器')),
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              child: const Panel(padding: EdgeInsets.symmetric(horizontal: 6.0)),
            ),
          ),
        ),
      ).then((_) {
        if (context.mounted) FocusScope.of(context).unfocus();
      });
    } finally {
      Future.microtask(() => _isNavigating = false);
    }
  }

  static Future<void> openTuner(BuildContext context) async{
    if (_isRouteInStack(context, '/tuner')) return;
    _isNavigating = true;
    try {
      return Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/tuner'),
          builder: (context) =>
              Scaffold(body: SafeArea(top: true, bottom: false, child: Tuner())),
        ),
      ).then((_) {
        if (context.mounted) FocusScope.of(context).unfocus();
      });
    } finally {
      Future.microtask(() => _isNavigating = false);
    }
  }

  static Future<void> openMetronome(BuildContext context) async {
    if (_isRouteInStack(context, '/metronome')) return;
    _isNavigating = true;
    try {
      return Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/metronome'),
          builder: (context) => Material(child: Metronome()),
        ),
      ).then((_) {
        if (context.mounted) FocusScope.of(context).unfocus();
      });
    } finally {
      Future.microtask(() => _isNavigating = false);
    }
  }

  static bool _isRouteInStack(BuildContext context, String routeName) {
    // 物理锁：如果上一个跳转还没完成，直接拦截
    if (_isNavigating) return true;
    bool exists = false;
    Navigator.popUntil(context, (route) {
      if (route.settings.name == routeName) exists = true;
      // 返回 true 意味着“停止 pop”，所以这行代码不会真的关掉任何页面
      return true;
    });
    return exists;
  }
}

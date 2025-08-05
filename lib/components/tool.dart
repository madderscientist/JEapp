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

  static Future<void> openPanel(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
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
  }

  static Future<void> openTuner(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            Scaffold(body: SafeArea(top: true, bottom: false, child: Tuner())),
      ),
    ).then((_) {
      if (context.mounted) FocusScope.of(context).unfocus();
    });
  }

  static Future<void> openMetronome(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Material(child: Metronome())),
    ).then((_) {
      if (context.mounted) FocusScope.of(context).unfocus();
    });
  }
}

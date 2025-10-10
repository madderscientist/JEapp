import 'dart:async';
import 'package:flutter/material.dart';
import 'synth_worker.dart';

void main() {
  runApp(const MaterialApp(home: TestPage()));
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  @override
  void initState() {
    super.initState();
    init();
  }
  final initCompleter = Completer<void>(); // 指示合成器是否初始化完成

  void init() async {
    if (!initCompleter.isCompleted) {
      IsolateSynthesizer.instance.onReceive = (dynamic msg) {
        switch (msg) {
          case List<Preset>():
            // 收到预设列表后表明初始化完成
            if (!initCompleter.isCompleted) {
              IsolateSynthesizer.instance.send(
                ChangePreset(channel: 0, preset: 0),
              );
              initCompleter.complete();
            }
            break;
          case _:
            debugPrint('@msg: ${msg.runtimeType}');
        }
      };
      if (IsolateSynthesizer.instance.presets != null) {
        // 初始化后更改音色的逻辑在settings中
        initCompleter.complete(); // 已经初始化过了
      } else {
        await initCompleter.future;
      }
    }
    IsolateSynthesizer.instance.send(StartAudio());
    debugPrint('@test started');
  }
  @override
  void dispose() {
    // ignore: deprecated_member_use_from_same_package
    IsolateSynthesizer.dispose();
    super.dispose();
  }

  int p = 0;
  void nextP() {
    if (IsolateSynthesizer.instance.presets != null &&
        IsolateSynthesizer.instance.presets!.isNotEmpty) {
      p = (p + 1) % IsolateSynthesizer.instance.presets!.length;
      IsolateSynthesizer.instance.send(ChangePreset(channel: 0, preset: p));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Page')),
      body: Column(
        children: [
          ElevatedButton(onPressed: nextP, child: const Text('Change Preset')),
          PitchBtn(60),
          PitchBtn(61),
          PitchBtn(62),
          PitchBtn(63),
          PitchBtn(64),
          PitchBtn(65),
        ],
      ),
    );
  }
}

class PitchBtn extends StatelessWidget {
  final int midi;
  static void nextP() {}
  const PitchBtn(this.midi, {super.key});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        IsolateSynthesizer.instance.send(
          PlayNote(channel: 0, key: midi, velocity: 127),
        );
      },
      onPointerUp: (_) {
        IsolateSynthesizer.instance.send(
          PlayNote(channel: 0, key: midi, velocity: 0),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(4.0),
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
        ),
        child: Text('Note $midi', textAlign: TextAlign.center),
      ),
    );
  }
}

import 'dart:isolate';
import 'package:dart_melty_soundfont/preset.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'synth_context.dart';

abstract class AudioCommand {} // 命令基类

class StartAudio extends AudioCommand {}

class StopAudio extends AudioCommand {}

class DisposeAudio extends AudioCommand {}

class PlayNote extends AudioCommand {
  final int channel;
  final int key;
  final int velocity; // 为0表示停止
  PlayNote({this.channel = 0, this.key = 60, this.velocity = 127});
}

class ChangePreset extends AudioCommand {
  final int channel;
  final int preset;
  ChangePreset({this.channel = 0, this.preset = 0});
}

class GetPreset extends AudioCommand {}

/// 不在主线程运行 SynthContext 的封装
class IsolateSynthesizer {
  // 全局单例，访问才初始化 被 SynthContext 传染
  static IsolateSynthesizer? _instance;
  static IsolateSynthesizer get instance {
    _instance ??= IsolateSynthesizer._();
    return _instance!;
  }

  ReceivePort receivePort = ReceivePort();
  SendPort? workerSendPort;
  List<Preset>? presets;

  IsolateSynthesizer._() {
    // rootBundle 只能在主Isolate中使用
    final synthesizerLoading = rootBundle.load('assets/PVF.sf2');
    RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
    Isolate.spawn<_IsolateIniter>(
      IsolateSynthesizer._synthWorker,
      _IsolateIniter(receivePort.sendPort, rootIsolateToken),
    );
    receivePort.listen((message) {
      if (message is SendPort) {
        if (workerSendPort == null) {
          workerSendPort = message;
          workerSendPort!.send(StartAudio());
          synthesizerLoading.then((bytes) {
            workerSendPort!.send(bytes);
            workerSendPort!.send(GetPreset());
          });
        }
      } else if (message is List<Preset>) {
        presets = message;
      }
    });
  }

  void send(AudioCommand command) {
    workerSendPort?.send(command);
  }

  void dispose() {
    workerSendPort?.send(DisposeAudio());
    receivePort.close();
    workerSendPort = null;
    presets = null;
    _instance = null;
  }

  static void _synthWorker(_IsolateIniter init) async {
    // 不然SoLoud会报错 但即使调用了也不能用 rootBundle (只能在主Isolate中用)
    BackgroundIsolateBinaryMessenger.ensureInitialized(init.rootIsolateToken);
    SynthContext ctx = SynthContext.instance;
    final ReceivePort workerPort = ReceivePort();
    init.sendPort.send(workerPort.sendPort);
    // 用for代替listen使得事件有顺序
    await for (final msg in workerPort) {
      switch (msg) {
        case StartAudio():
          await ctx.start();
          break;
        case StopAudio():
          await ctx.stop();
          break;
        case DisposeAudio():
          await ctx.stop();
          SoLoud.instance.deinit();
          workerPort.close();
          return;
        case PlayNote():
          if (msg.velocity > 0) {
            ctx.synthesizer?.noteOn(
              channel: msg.channel,
              key: msg.key,
              velocity: msg.velocity,
            );
          } else {
            ctx.synthesizer?.noteOff(channel: msg.channel, key: msg.key);
          }
          break;
        case ChangePreset():
          ctx.synthesizer?.selectPreset(
            channel: msg.channel,
            preset: msg.preset,
          );
          break;
        case GetPreset():
          List<Preset> p = ctx.synthesizer?.soundFont.presets ?? [];
          init.sendPort.send(p);
          break;
        case ByteData():
          ctx.initSynthesizer(msg);
          break;
      }
    }
  }
}

class _IsolateIniter {
  SendPort sendPort;
  RootIsolateToken rootIsolateToken;
  _IsolateIniter(this.sendPort, this.rootIsolateToken);
}
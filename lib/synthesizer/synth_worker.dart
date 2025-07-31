import 'dart:isolate';
import 'package:dart_melty_soundfont/preset.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'synth_context.dart';
export 'package:dart_melty_soundfont/preset.dart' show Preset;

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

  static bool get created => _instance != null;

  ReceivePort receivePort = ReceivePort();
  SendPort? workerSendPort;
  List<Preset>? presets;
  void Function(dynamic)? onReceive;

  IsolateSynthesizer._() {
    _init();
  }

  void _init() async {
    // rootBundle 只能在主Isolate中使用
    final synthesizerLoading = rootBundle.load('assets/PVF.sf2');
    if (SoLoud.instance.isInitialized == false) {
      // 非主线程初始化的 SoLoud 不具备 loadAsset 能力 (flutter限制)
      // 因此在主线程初始化 (C++是共用的)
      await SoLoud.instance.init(
        sampleRate: 44100,
        bufferSize: 256,
        channels: Channels.mono,
      );
    }
    Isolate.spawn<_IsolateIniter>(
      IsolateSynthesizer._synthWorker,
      _IsolateIniter(receivePort.sendPort, RootIsolateToken.instance!),
    );
    receivePort.listen((message) {
      if (message is SendPort) {
        if (workerSendPort == null) {
          workerSendPort = message;
          synthesizerLoading.then((bytes) {
            workerSendPort!.send(bytes);
            workerSendPort!.send(GetPreset());
          });
        }
      } else if (message is List<Preset>) {
        presets = message;
        onReceive?.call(presets); // 可以使用合成器了
      } else {
        onReceive?.call(message); // 发出的指令都有回音
      }
    });
  }

  void send(AudioCommand command) {
    workerSendPort?.send(command);
  }

  /// 当页面使用的页面关闭后调用
  /// 关闭音频流 清空回调 但不关闭Isolate和SoLoud
  static void leave() {
    if (_instance != null) {
      _instance!.workerSendPort?.send(StopAudio());
      _instance!.onReceive = null;
    }
  }

  /// 作为全局单例，此方法不应该被调用 (除非App析构)
  /// This method should NOT be called manually.
  @Deprecated('全局单例不应主动dispose')
  static void dispose() {
    if (_instance == null) return;
    _instance!
      ..workerSendPort?.send(DisposeAudio())
      ..receivePort.close()
      ..workerSendPort = null
      ..presets = null
      ..onReceive = null;
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
          continue;
        case ByteData():
          ctx.initSynthesizer(msg);
          break;
        default:
          continue;
      }
      init.sendPort.send(msg); // 回应
    }
  }
}

class _IsolateIniter {
  SendPort sendPort;
  RootIsolateToken rootIsolateToken;
  _IsolateIniter(this.sendPort, this.rootIsolateToken);
}

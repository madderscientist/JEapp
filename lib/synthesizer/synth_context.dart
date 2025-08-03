import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:dart_melty_soundfont/dart_melty_soundfont.dart';
import '../config.dart';

/// 控制合成于输出 可以在任意线程使用
class SynthContext {
  // 全局单例，访问才初始化 被 SoLoud 的唯一 released BufferStream 传染
  static SynthContext? _instance;
  static SynthContext get instance {
    _instance ??= SynthContext._(22050);
    return _instance!;
  }

  double currentTime = 0; // 当前时间（秒）比用int精准
  final int sampleRate;

  SynthContext._(this.sampleRate)
    : fillBufferMicroseconds = (1e6 / sampleRate * fillBufferSize).toInt();

  Synthesizer? synthesizer;

  /// 初始化合成器 需要外界调用
  /// [bytes] SoundFont 文件数据 只能是 sf2
  /// 没有初始化也可以start和feed，不过都是0
  void initSynthesizer(ByteData bytes) {
    synthesizer = Synthesizer.loadByteData(
      bytes,
      SynthesizerSettings(
        sampleRate: sampleRate,
        blockSize: 64,
        maximumPolyphony: 64,
        enableReverbAndChorus: true,
      ),
    );
    synthesizer!.selectPreset(channel: 0, preset: 0);
  }

  static const fillBufferSize = 768; // 要大于512 太小不播放且卡顿
  int get maxBufferSize => fillBufferSize * 3;
  final _samples = Float32List(fillBufferSize);
  final int fillBufferMicroseconds;
  AudioSource? stream;
  SoundHandle? handle;
  Timer? _check;
  Future<void> initSoLoudStream() async {
    // SoLoud 初始化需要 BackgroundIsolateBinaryMessenger.ensureInitialized
    // 在主Isolate中不需要特意调用，但在Isolate中需要
    // 否则报错：Bad state: The BackgroundIsolateBinaryMessenger.instance value is invalid until BackgroundIsolateBinaryMessenger.ensureInitialized is executed.
    // 但是非主线程初始化的 SoLoud 不具备 loadAsset 能力(flutter限制) 尽量在主线程初始化
    await Config.initSoLoud();
    stop();
    stream = SoLoud.instance.setBufferStream(
      bufferingType: BufferingType.released,
      maxBufferSizeBytes: maxBufferSize * Float32List.bytesPerElement,
      bufferingTimeNeeds: 0,
      sampleRate: sampleRate,
      channels: Channels.mono,
      format: BufferType.f32le,
    );
  }

  Future<void> start() async {
    if (stream == null) await initSoLoudStream();

    // 第一次要喂满 不然不会开始
    SoLoud.instance.addAudioDataStream(
      stream!,
      Float32List(maxBufferSize).buffer.asUint8List(),
    );
    currentTime += maxBufferSize / sampleRate;

    handle = await SoLoud.instance.play(stream!);

    _check = Timer.periodic(
      Duration(microseconds: fillBufferMicroseconds ~/ 2.5),
      (_) {
        final playedTime = SoLoud.instance.getStreamTimeConsumed(stream!);
        if (currentTime * 1e6 - playedTime.inMicroseconds <
            fillBufferMicroseconds) {
          feed();
        }
      },
    );
  }

  Future<void> stop() async {
    final waits = <Future<void>>[];
    if (handle != null) {
      waits.add(SoLoud.instance.stop(handle!));
      handle = null;
    }
    if (stream != null) {
      waits.add(SoLoud.instance.disposeSource(stream!));
      stream = null;
    }
    synthesizer?.noteOffAll();
    _check?.cancel();
    _check = null;
    currentTime = 0;
    await Future.wait(waits);
  }

  // dispose 只需要在stop的基础上 SoLoud.instance.deinit 不写

  void feed() {
    if (stream == null || synthesizer == null) return;
    currentTime += fillBufferSize / sampleRate;
    synthesizer?.render(_samples, _samples);
    try {
      SoLoud.instance.addAudioDataStream(
        stream!,
        _samples.buffer.asUint8List(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('@feed error: $e');
      }
    }
  }
}

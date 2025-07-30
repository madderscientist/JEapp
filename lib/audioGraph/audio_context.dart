import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'audio_node.dart' as n;

// 全局单例 要提前设置号instance 在isloate中运行
class AudioContext {
  // 访问就初始化
  static AudioContext? _instance;
  static AudioContext get instance {
    if (_instance != null) return _instance!;
    _instance = AudioContext._(24000);
    _instance!.destination = n.GainNode(1.0);
    return _instance!;
  }

  double currentTime = 0; // 当前时间（秒）
  final int sampleRate;
  final List<n.AudioNode> audioNodes = [];
  late final n.GainNode destination; // 总音量 总输出 必须放到构造函数外，因为要注册到audioNodes中

  AudioContext._(this.sampleRate)
    : fillBufferMicroseconds = (1000000 / sampleRate * fillBufferSize).toInt();

  void dispose() {
    stop();
    for (int i = audioNodes.length - 1; i >= 0; i--) {
      audioNodes[i].dispose();
    }
    audioNodes.clear();
  }

  /// 恢复刚初始化的样子
  void restore() {
    stop();
    for (int i = audioNodes.length - 1; i >= 0; i--) {
      audioNodes[i].dispose();
    }
    audioNodes.add(destination);
  }

  // 256以下容易卡顿
  static const fillBufferSize = 512;
  // 这个太小不会播放 即使能也会卡顿
  int get maxBufferSize => fillBufferSize * 4;
  final _samples = Float32List(fillBufferSize);
  final int fillBufferMicroseconds;
  AudioSource? stream;
  SoundHandle? handle;
  Timer? _check;
  Future<void> initSoLoud() async {
    if (SoLoud.instance.isInitialized == false) {
      await SoLoud.instance.init(
        sampleRate: 44100,
        bufferSize: 256,
        channels: Channels.mono,
      );
    }
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

  void step() {
    currentTime += 1 / sampleRate;
    // 必须倒序 因为会触发dispose
    for (int i = audioNodes.length - 1; i >= 0; i--) {
      audioNodes[i].step(); // 推进所有节点
    }
  }

  void start() async {
    if (stream == null) await initSoLoud();
    // 第一次要喂满 不然不会开始
    initialFeed();

    handle = await SoLoud.instance.play(stream!);
    _check = Timer.periodic(
      Duration(microseconds: fillBufferMicroseconds ~/ 3),
      (_) {
        final playedTime = SoLoud.instance.getStreamTimeConsumed(stream!);
        if (currentTime * 1000000 - playedTime.inMicroseconds <
            fillBufferMicroseconds) {
          feed();
        }
      },
    );
  }

  void stop() {
    if (handle != null) {
      SoLoud.instance.stop(handle!);
      handle = null;
    }
    if (stream != null) {
      SoLoud.instance.disposeSource(stream!);
      stream = null;
    }
    _check?.cancel();
    _check = null;
  }

  void feed() {
    if (stream == null || handle == null) return;
    for (int i = 0; i < _samples.length; i++) {
      step(); // 推进所有节点
      _samples[i] = destination.currentValue; // 采样主输出
    }
    try {
      SoLoud.instance.addAudioDataStream(stream!, _samples.buffer.asUint8List());
    } finally {}
  }

  void initialFeed() {
    final buf = Float32List(maxBufferSize);
    for (int i = 0; i < fillBufferSize; i++) {
      step(); // 推进所有节点
      _samples[i] = destination.currentValue; // 采样主输出
    }
    try {
      SoLoud.instance.addAudioDataStream(stream!, buf.buffer.asUint8List());
    } finally {}
  }
}

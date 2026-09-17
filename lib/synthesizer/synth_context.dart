import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
// ignore: implementation_imports, invalid_use_of_internal_member
import 'package:flutter_soloud/src/enums.dart' show PlayerErrors;
import 'package:dart_melty_soundfont/dart_melty_soundfont.dart';

/// 控制合成与输出；共享引擎需先在主线程初始化
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
  // ignore: experimental_member_use
  final _soloud = SoLoudIsolate.instance.bindings;  // 直接控制底层

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

  static const fillBufferSize = 512;
  static const maxBufferSize = fillBufferSize * 4;  // 3倍无声
  final _samples = Float32List(fillBufferSize);
  final int fillBufferMicroseconds;
  SoundHash? stream;
  SoundHandle? handle;
  Timer? _check;
  Future<void> initSoLoudStream() async {
    // 使用共享原生引擎，不在后台重新初始化或接管主线程回调
    await stop();
    final result = _soloud.setBufferStream(
      maxBufferSize * Float32List.bytesPerElement,
      BufferingType.released,
      0,
      sampleRate,
      Channels.mono.count,
      BufferType.f32le.value,
      null,
      null,
    );
    // ignore: invalid_use_of_internal_member
    if (result.error != PlayerErrors.noError) {
      throw SoLoudCppException.fromPlayerError(result.error);
    }
    stream = result.soundHash;
  }

  Future<void> start() async {
    if (stream == null) await initSoLoudStream();

    // 播放前预填一块，避免设备启动后立即读到空流
    final error = _soloud.addAudioDataStream(
      stream!.hash,
      Float32List(fillBufferSize).buffer.asUint8List(),
    );
    // ignore: invalid_use_of_internal_member
    if (error != PlayerErrors.noError) {
      throw SoLoudCppException.fromPlayerError(error);
    }
    currentTime += fillBufferSize / sampleRate;

    final result = _soloud.play(stream!);
    // ignore: invalid_use_of_internal_member
    if (result.error != PlayerErrors.noError) {
      throw SoLoudCppException.fromPlayerError(result.error);
    }
    handle = result.newHandle;
    _check = Timer.periodic(
      Duration(microseconds: fillBufferMicroseconds ~/ 2.5),
      (_) => feed(),
    );
  }

  Future<void> stop() async {
    // 补音和释放在同一 isolate 顺序执行；释放音源会同时停止其句柄
    _check?.cancel();
    _check = null;
    if (stream != null) {
      _soloud.disposeSound(stream!);
      stream = null;
    }
    handle = null;
    synthesizer?.noteOffAll();
    currentTime = 0;
  }

  // 只释放自己的流，不关闭主线程初始化的共享引擎

  void feed() {
    final soundHash = stream;
    if (soundHash == null || synthesizer == null) return;
    try {
      // 欠载后的第一次写入可能暂停音源，第二次写入恢复播放
      // 最多补两块，保持原水位，并让音符和停止命令有机会执行
      for (var remaining = 2; remaining > 0; remaining--) {
        final buffered = _soloud.getBufferSize(soundHash);
        // ignore: invalid_use_of_internal_member
        if (buffered.error != PlayerErrors.noError) {
          throw SoLoudCppException.fromPlayerError(buffered.error);
        }
        if (buffered.sizeInBytes > fillBufferSize * Float32List.bytesPerElement) {
          break;
        }
        synthesizer!.render(_samples, _samples);
        final error = _soloud.addAudioDataStream(
          soundHash.hash,
          _samples.buffer.asUint8List(),
        );
        // ignore: invalid_use_of_internal_member
        if (error != PlayerErrors.noError) {
          throw SoLoudCppException.fromPlayerError(error);
        }
        currentTime += fillBufferSize / sampleRate;
      }
    } catch (e) {
      if (kDebugMode) {
        print('@feed error: $e');
      }
    }
  }
}

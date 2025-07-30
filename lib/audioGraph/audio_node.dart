import 'dart:math';
import 'audio_context.dart';
import 'audio_param.dart';
import 'connectable.dart';

abstract class AudioNode extends Connectable {
  AudioNode() {
    AudioContext.instance.audioNodes.add(this);
  }
  void Function()? ended;
  void step(); // 更新AudioParam等 由AudioContext驱动
  // 断掉后面的连接
  void dispose() {
    disconnect();
    AudioContext.instance.audioNodes.remove(this);
    ended?.call();
  }
}

class GainNode extends AudioNode with MIMO {
  final AudioParam gain;

  GainNode([double initialGain = 1]) : gain = AudioParam(initialGain, min: 0);

  @override
  double get currentValue {
    double sum = 0;
    for (var input in from) {
      sum += input.currentValue;
    }
    if (from.length > 1) sum /= from.length;
    return sum * gain.currentValue;
  }

  @override
  void step() => gain.step();

  @override
  void dispose() {
    // 断掉输入的连接
    for (var input in from) {
      input.disconnect(this);
    }
    from.clear();
    // 清除增益调度
    gain.schedules.clear();
    // 断掉输出的连接
    super.dispose();
  }
}

abstract class AudioSource extends AudioNode with MO {
  AudioSource();
  double startTime = double.infinity;
  double _stopTime = double.infinity;
  bool get isPlaying => startTime <= AudioContext.instance.currentTime;
  // 更新相位等 由AudioContext驱动
  @override
  void step() {
    if (_stopTime < AudioContext.instance.currentTime) super.dispose();
  }

  void start(double time) => startTime = time;
  void stop(double time) => _stopTime = time;
}

abstract class Oscillator extends AudioSource {
  late final AudioParam frequency; // 支持FM
  double phase = 0.0;

  Oscillator(double f) : frequency = AudioParam(f, min: 0);

  @override
  void step() {
    if (AudioContext.instance.currentTime < startTime) return;
    if (_stopTime < AudioContext.instance.currentTime) {
      dispose();
      return;
    }
    frequency.step();
    phase += 2 * pi * frequency.currentValue / AudioContext.instance.sampleRate;
    if (phase >= 2 * pi) {
      phase -= 2 * pi;
    }
  }

  @override
  void dispose() {
    frequency.schedules.clear();
    super.dispose();
  }

  @override
  double get currentValue => phase;
}

// 要拓展波形，只需要继承Oscillator并重写currentValue即可
class SineOscillator extends Oscillator {
  SineOscillator(super.f);

  @override
  double get currentValue => isPlaying ? sin(super.currentValue) : 0;
}

class SquareOscillator extends Oscillator {
  SquareOscillator(super.f);

  @override
  double get currentValue {
    if (!isPlaying) return 0;
    double v = super.currentValue;
    return v < pi ? 1 : -1;
  }
}

class TriangleOscillator extends Oscillator {
  TriangleOscillator(super.f);

  @override
  double get currentValue {
    if (!isPlaying) return 0;
    double v = super.currentValue;
    if (v < pi) return 2 * v / pi - 1;
    return -2 * v / pi + 3;
  }
}

class SawtoothOscillator extends Oscillator {
  SawtoothOscillator(super.f);

  @override
  double get currentValue {
    if (!isPlaying) return 0;
    return super.currentValue / pi - 1;
  }
}

class CustomOscillator extends Oscillator {
  List<double> waveform;
  CustomOscillator(super.f, this.waveform);

  @override
  double get currentValue {
    if (!isPlaying) return 0;
    int index = (super.currentValue / (2 * pi) * waveform.length).round();
    return waveform[index % waveform.length];
  }
}

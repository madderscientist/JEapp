import 'dart:async';
import 'dart:math';

import 'package:je/audioGraph/audio_context.dart';
import 'package:je/audioGraph/audio_param.dart';
import 'package:je/audioGraph/connectable.dart';
import 'audio_node.dart';

class WaveParams {
  int g;
  String w;
  double t;
  double f;
  double v;
  double a;
  double h;
  double d;
  double s;
  double r;
  double p;
  double q;
  double k;
  WaveParams({
    this.g = 0,
    this.w = 'sine',
    this.t = 1,
    this.f = 0,
    this.v = 0.5,
    this.a = 0.0,
    this.h = 0.01,
    this.d = 0.01,
    this.s = 0,
    this.r = 0.05,
    this.p = 1,
    this.q = 1,
    this.k = 0,
  });

  WaveParams.fromConfig(Map<String, dynamic> config)
    : g = config['g'] ?? 0,
      w = config['w'] ?? 'sine',
      t = config['t'] ?? 1,
      f = config['f'] ?? 0,
      v = config['v'] ?? 0.5,
      a = config['a'] ?? 0,
      h = config['h'] ?? 0.01,
      d = config['d'] ?? 0.01,
      s = config['s'] ?? 0,
      r = config['r'] ?? 0.05,
      p = config['p'] ?? 1,
      q = config['q'] ?? 1,
      k = config['k'] ?? 0;
}

class Note {
  double end;
  final List<GainNode> gain;
  final List<Oscillator> osc;
  final List<double> release;
  Note({
    required this.end,
    required this.gain,
    required this.osc,
    required this.release,
  });
}

class NoteManager {
  List<Note> notes = [];
  Timer? _check;

  List<WaveParams> timbre = [
    WaveParams(w: "sine", v: .4, d: 0.7, r: 0.1),
    WaveParams(w: "triangle", v: 2, d: 0.7, s: 0.1, g: -1, a: 0.01, k: -1.2),
  ];

  void init() {
    AudioContext.instance.start();
    _check = Timer.periodic(const Duration(microseconds: 500), (_) {
      checkStop();
    });
  }

  void dispose() {
    _check?.cancel();
    stopAll();
    // 恢复AudioContext
    AudioContext.instance.restore();
    // AudioContext.instance.dispose();
  }

  Note? play({
    required double f,
    double startTime = 0,
    double last = 999,
    double v = 127,
  }) {
    if (last <= 0) return null;
    double t = (startTime < 0)
        ? (AudioContext.instance.currentTime - startTime)
        : max(AudioContext.instance.currentTime, startTime);
    List<Oscillator> osc = [];
    List<GainNode> gain = [];
    List<double> release = [];
    List<double> freq = [];
    for (int i = 0; i < timbre.length; i++) {
      final p = timbre[i];
      Connectable out;
      double aRate; // 幅度(调制深度)
      // 判断调制
      if (p.g == 0) {
        out = AudioContext.instance.destination;
        aRate = v * v / 16129;  // 平方律设置归一化振幅
        freq.add(f * p.t + p.f);
      } else if (p.g > 0) {
        out = osc[p.g - 1].frequency;
        aRate = freq[p.g - 1];
        freq.add(freq[p.g - 1] * p.t + p.f);
      } else {
        out = gain[-p.g - 1].gain;
        aRate = (out as AudioParam).value;
        freq.add(freq[-p.g - 1] * p.t + p.f);
      }
      Oscillator o = switch (timbre[0].w) {
        'sine' => SineOscillator(freq[i]),
        'triangle' => TriangleOscillator(freq[i]),
        'square' => SquareOscillator(freq[i]),
        'sawtooth' => SawtoothOscillator(freq[i]),
        _ => SineOscillator(freq[i]), // 默认使用正弦波
      };
      if (p.p != 1) o.frequency.setTargetAtTime(freq[i] * p.p, t, p.q);
      osc.add(o);

      double volume = aRate * p.v;
      if (p.k != 0) volume *= pow(f / 261.6, p.k);
      release.add(p.r);

      GainNode g = GainNode(volume);
      if (p.a > 0) {
        g.gain.value = 0;
        g.gain.setValueAtTime(0, t);
        g.gain.linearRampToValueAtTime(volume, t + p.a);
      } else {
        g.gain.setValueAtTime(volume, t);
      }
      g.gain.setTargetAtTime(p.s * volume, t + p.a + p.h, p.d);
      gain.add(g);

      o.connect(g);
      g.connect(out);
      o.start(t);
    }
    final n = Note(
      end: t + last,
      gain: gain,
      osc: osc,
      release: release,
    );
    notes.add(n);
    return n;
  }

  void stop(Note note, [double at = 0]) {
    notes.remove(note);
    double t = (at < 0)
        ? (AudioContext.instance.currentTime - at)
        : max(AudioContext.instance.currentTime, at);
    final promises = List.generate(note.osc.length, (i) {
      final completer = Completer();
      final osc = note.osc[i];
      final gain = note.gain[i];
      osc.ended = () {
        completer.complete();
      };
      gain.gain.cancelAndHoldAtTime(t);
      // Release
      gain.gain.setTargetAtTime(0, t, note.release[i]);
      osc.stop(t + note.release[i] * 2);
      gain.gain.cancelAndHoldAtTime(t + note.release[i] * 2);
      return completer.future;
    });
    Future.wait(promises).then((_) {
      // 调用ended时，osc已经析构完成(stop自带dispose)
      // 析构所有的gain dispose自带disconnect
      for (var gain in note.gain) {
        gain.dispose();
      }
    });
  }

  void checkStop() {
    double t = AudioContext.instance.currentTime;
    for (var i = notes.length - 1; i >= 0; i--) {
      final note = notes[i];
      if (note.end < t) {
        stop(note, t);
      }
    }
  }

  void stopAll() {
    for (var note in notes) {
      stop(note);
    }
    notes.clear();
  }
}
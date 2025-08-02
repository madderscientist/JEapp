import 'dart:math';

class FreqTable {
  final List<double> _freqs = List.filled(84, 0.0);
  double _a4;
  int get length => _freqs.length;

  FreqTable([this._a4 = 440]) {
    A4 = _a4;
  }

  // dart format off
  static List<String> noteName = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  // dart format on

  // ignore: non_constant_identifier_names
  set A4(double A4) {
    _a4 = A4;
    final note4 = [
      A4 * 0.5946035575013605,
      A4 * 0.6299605249474366,
      A4 * 0.6674199270850172,
      A4 * 0.7071067811865475,
      A4 * 0.7491535384383408,
      A4 * 0.7937005259840998,
      A4 * 0.8408964152537146,
      A4 * 0.8908987181403393,
      A4 * 0.9438743126816935,
      A4,
      A4 * 1.0594630943592953,
      A4 * 1.122462048309373,
    ];
    for (int i = 0; i < 12; i++) {
      _freqs[i] = note4[i] / 8;
      _freqs[i + 12] = note4[i] / 4;
      _freqs[i + 24] = note4[i] / 2;
      _freqs[i + 36] = note4[i];
      _freqs[i + 48] = note4[i] * 2;
      _freqs[i + 60] = note4[i] * 4;
      _freqs[i + 72] = note4[i] * 8;
    }
  }

  // ignore: non_constant_identifier_names
  double get A4 => _freqs[A4at];
  // ignore: constant_identifier_names
  static const int A4at = 45;

  double operator [](int index) {
    if (index < 0 || index >= _freqs.length) {
      return _a4 * pow(2, (index - A4at) / 12);
    }
    return _freqs[index];
  }
}
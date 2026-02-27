import 'dart:math' as math;

class YIN {
  int frameSize;
  int sampleRate;
  double threshold;
  List<double> buffer;

  // 预计算的滤波器系数 原论文表明滤波有效
  late double _hpB0, _hpB1, _hpB2, _hpA1, _hpA2;
  late double _lpB0, _lpB1, _lpB2, _lpA1, _lpA2;

  YIN({
    this.frameSize = 2048,
    this.sampleRate = 22050,
    this.threshold = 0.22,
    double lpfCutoff = 5000,  // 5k幅度变为一半 比较宽裕
    double hpfCutoff = 30,
  }) : buffer = List<double>.filled(frameSize ~/ 2, 0.0) {
    // buffer长度为frameSize的一半，频率下限为sampleRate*2/frameSize=21Hz
    _computeHPF(hpfCutoff);
    _computeLPF(lpfCutoff);
  }

 void _computeHPF(double freq) {
    double omega = 2.0 * math.pi * freq / sampleRate;
    double sn = math.sin(omega);
    double cs = math.cos(omega);
    double alpha = sn / (2.0 * 0.7071);

    double b0 = (1 + cs) / 2;
    double b1 = -(1 + cs);
    double b2 = (1 + cs) / 2;
    double a0 = 1 + alpha;
    double a1 = -2 * cs;
    double a2 = 1 - alpha;

    _hpB0 = b0 / a0; _hpB1 = b1 / a0; _hpB2 = b2 / a0;
    _hpA1 = a1 / a0; _hpA2 = a2 / a0;
  }

  void _computeLPF(double freq) {
    double omega = 2.0 * math.pi * freq / sampleRate;
    double sn = math.sin(omega);
    double cs = math.cos(omega);
    double alpha = sn / (2.0 * 0.7071);

    double b0 = (1 - cs) / 2;
    double b1 = 1 - cs;
    double b2 = (1 - cs) / 2;
    double a0 = 1 + alpha;
    double a1 = -2 * cs;
    double a2 = 1 - alpha;

    _lpB0 = b0 / a0; _lpB1 = b1 / a0; _lpB2 = b2 / a0;
    _lpA1 = a1 / a0; _lpA2 = a2 / a0;
  }

  /// input.length = frameSize
  /// 负数表示未找到符合条件的音高
  double getPitch(final List<double> input) {
    _applyBandPassInPlace(input);
    difference(input);
    cumulativeMeanNormalizedDifference();
    final int tau = absoluteThreshold();
    final double f0 = tau.sign * sampleRate / parabolicInterpolation(tau.abs());
    return f0;
  }

  /// 使用预计算系数进行原位滤波
  void _applyBandPassInPlace(List<double> data) {
    double hpx1 = 0, hpx2 = 0, hpy1 = 0, hpy2 = 0;
    double lpx1 = 0, lpx2 = 0, lpy1 = 0, lpy2 = 0;
    for (int i = 0; i < data.length; i++) {
      double x = data[i];
      // 高通
      double hpOut = _hpB0 * x + _hpB1 * hpx1 + _hpB2 * hpx2 - _hpA1 * hpy1 - _hpA2 * hpy2;
      hpx2 = hpx1; hpx1 = x;
      hpy2 = hpy1; hpy1 = hpOut;
      // 低通
      double lpOut = _lpB0 * hpOut + _lpB1 * lpx1 + _lpB2 * lpx2 - _lpA1 * lpy1 - _lpA2 * lpy2;
      lpx2 = lpx1; lpx1 = hpOut;
      lpy2 = lpy1; lpy1 = lpOut;
      // 原位写回
      data[i] = lpOut; 
    }
  }

  /// 原论文实现的 slowDifference: 时域算法
  void difference(final List<double> input) {
    buffer[0] = 0;
    for (int tau = 1; tau < buffer.length; tau++) {
      buffer[tau] = 0;
      // 两个差异窗口从input中心向两边移动
      final int startPoint = (buffer.length - tau) >> 1;
      final int endPoint = startPoint + buffer.length;
      for (int i = startPoint; i < endPoint; ++i) {
        final double delta = input[tau + i] - input[i];
        buffer[tau] += delta * delta;
      }
    }
  }

  void cumulativeMeanNormalizedDifference() {
    buffer[0] = 1;
    double runningSum = 0;
    for (int tau = 1; tau < buffer.length; tau++) {
      runningSum += buffer[tau];
      if (runningSum == 0) {
        buffer[tau] = 1;
      } else {
        buffer[tau] *= tau / runningSum;
      }
    }
  }

  int absoluteThreshold() {
    int minTau = 0;
    double minVal = 1000;
    for (int tau = 2; tau < buffer.length; ++tau) {
      if (buffer[tau] < threshold) {
        while (tau + 1 < buffer.length && buffer[tau + 1] < buffer[tau]) {
          tau++;
        }
        return tau;
      } else {
        if (buffer[tau] < minVal) {
          minVal = buffer[tau];
          minTau = tau;
        }
      }
    }
    // 负数表示未找到，但返回一个猜测值
    if (minTau > 0) return -minTau;
    return 0;
  }

  /// 抛物线插值
  double parabolicInterpolation(int tau) {
    if (tau == buffer.length) return tau.toDouble();
    if (tau > 0 && tau < buffer.length - 1) {
      double y1 = buffer[tau - 1];
      double y2 = buffer[tau];
      double y3 = buffer[tau + 1];
      double adjustment = (y3 - y1) / (2 * (y1 + y3 - 2 * y2));
      if (adjustment.abs() > 1) adjustment = 0;
      return tau - adjustment;
    } else {
      return tau.toDouble();
    }
  }

  static double sumSquare(List<double> input) {
    double sum = 0;
    for (final value in input) {
      sum += value * value;
    }
    return sum;
  }

  // 被放弃的pYIN算法
  // // length: 100; sum: 0.999997
  // // dart format off
  // // ignore: constant_identifier_names
  // static const List<double> CCDF = [0.999997,0.987383,0.964668,0.934022,0.897310,0.856126,0.811825,0.765548,0.718250,0.670722,0.623612,0.577441,0.532624,0.489480,0.448249,0.409102,0.372152,0.337462,0.305056,0.274923,0.247025,0.221303,0.197679,0.176065,0.156361,0.138461,0.122256,0.107635,0.094487,0.082702,0.072172,0.062795,0.054471,0.047105,0.040608,0.034896,0.029891,0.025519,0.021713,0.018411,0.015556,0.013096,0.010984,0.009178,0.007639,0.006332,0.005227,0.004296,0.003515,0.002863,0.002321,0.001872,0.001502,0.001199,0.000952,0.000751,0.000589,0.000459,0.000355,0.000273,0.000208,0.000157,0.000118,0.000088,0.000065,0.000047,0.000034,0.000024,0.000017,0.000012,0.000008,0.000005,0.000003,0.000002,0.000001,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000];  // dart format on
  // // dart format on

  // /// pYIN算法的概率峰值检测
  // /// [minTau0] 和 [maxTau0] 是可选的参数，用于限制峰值检测的范围，设置为sampleRate/minFreq和sampleRate/maxFreq
  // List<double> yinProb([int minTau0 = 0, int maxTau0 = 0]) {
  //   int minTau = 2;
  //   int maxTau = buffer.length;
  //   // 如果给出的 Tau0 合法就用合法的
  //   if (minTau0 > 0 && minTau0 < maxTau0) minTau = minTau0;
  //   if (maxTau0 > 0 && maxTau0 < maxTau && maxTau0 > minTau) maxTau = maxTau0;

  //   double minVal = double.infinity;
  //   int minInd = 0;
  //   double sumProb = 0;
  //   final List<double> peakProb = List<double>.filled(buffer.length, 0.0);
  //   for (int tau = minTau; tau + 1 < maxTau; tau++) {
  //     // >1的结果是0，不用算
  //     if (buffer[tau] < 1 && buffer[tau + 1] < buffer[tau]) {
  //       // 从左往右寻找局部最小值
  //       while (tau + 1 < maxTau && buffer[tau + 1] < buffer[tau]) {
  //         tau++;
  //       }
  //       // 更新全局最小值
  //       if (buffer[tau] < minVal && tau > 2) {
  //         minVal = buffer[tau];
  //         minInd = tau;
  //       }
  //       // 使用预先求好的CCDF省去了累加
  //       peakProb[tau] =
  //           CCDF[((buffer[tau] * CCDF.length).ceil() - 1).clamp(
  //             0,
  //             CCDF.length - 1,
  //           )];
  //       sumProb += peakProb[tau];
  //     }
  //   }

  //   double noPeakProb = 1; // 静音的概率 论文中提到设置为0.01会导致概率和不为0，缺的一部分就是静音概率
  //   if (sumProb > 0) {
  //     for (int i = minTau; i < maxTau; ++i) {
  //       peakProb[i] = peakProb[i] / sumProb * peakProb[minInd];
  //       noPeakProb -= peakProb[i];
  //     }
  //   }
  //   if (minInd > 0) peakProb[minInd] += noPeakProb * 0.01; // 0.01 是一个经验值，表示最小权重
  //   return peakProb;
  // }
}

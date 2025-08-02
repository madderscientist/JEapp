/// 消除尖峰 如果突变能维持trustLen个采样点则承认突变
class NoPeak {
  void Function(double) dataOutfn;  // 数据如何输出(和输入不同速) 接收一个数据参数
  double peakThres; // 判断尖刺的阈值 是倍数，因为音符频率按对数分布
  double captureRate; // 认为稳定的阈值 是倍数
  NoPeak({
    required this.dataOutfn,
    this.peakThres = 1.26,  // 默认1.26是因为4个半音，上下就是8个半音
    int trustLen = 4,  // 累计多少长度后信任突变
    this.captureRate = 1.1,
  }): buffer = List<double>.filled(trustLen, 0.0, growable: false);
  List<double> buffer;
  double stable = 0;
  int pointer = 0;

  void input(double freq) {
    if (freq < stable * peakThres && freq > stable / peakThres) {
      // 在平稳范围内
      stable = 0.3 * stable + 0.7 * freq; // 稍微平滑一下
      dataOutfn(freq);
      // 清除记录
      pointer = 0;
      return;
    }
    if (pointer > 0) {//已经有记录了
      // 求当前记录的均值
      double avg = 0;
      for (int i = 0; i < pointer; i++) {
        avg += buffer[i];
      }
      avg /= pointer;
      // 判断是否在捕获带内
      if (freq < avg * captureRate && freq > avg / captureRate) {
        // 在捕获带内则记录
        buffer[pointer] = freq;
        pointer++;
        // 如果满了就认为不是尖峰，全部输出
        if (pointer == buffer.length) {
          pointer = 0;
          stable = avg;
          for (final f in buffer) {
            dataOutfn(f);
          }
        }
      } else {
        // 不在捕获带内则重新记录
        buffer[0] = freq;
        pointer = 1;
      }
    } else {
      // 没有记录则直接记录
      buffer[0] = freq;
      pointer = 1;
    }
  }
}
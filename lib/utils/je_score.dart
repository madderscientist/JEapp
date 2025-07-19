class JeScoreOperator {
  // dart format off
  static const List<String> upNotes = ["1","#1","2","#2","3","4","#4","5","#5","6","#6","7"];
  static const List<String> downNotes = ["1","b2","2","b3","3","4","b5","5","b6","6","b7","7"];
  // dart format on
  static List<String> note = upNotes;

  /// 根据输入的半音数目对内容进行升降调转换
  ///
  /// - [bef]：要转换的内容
  /// - [x]：输入的半音数目，正数表示升调，负数表示降调
  /// - [Note_aft]：转换后的对照表
  static String convert(
    String bef,
    int x, {
    List<String>? noteAft,
    bool autoup = false,
  }) {
    final noteMap = noteAft ?? note;
    String aft = ''; // 转换后
    int n = 0; // 位置
    int octave = 0; // 八度音高
    int lastm = 0; // 用于自动升降号，记录上一个音是否升
    while (n < bef.length) {
      int m = 0; //升降半音
      if (bef[n] == ')' || bef[n] == '[') {
        ++octave;
      } else if (bef[n] == '(' || bef[n] == ']') {
        --octave;
      } else {
        if (bef[n] == '#') {
          m = 1;
        } else if (bef[n] == 'b') {
          m = -1;
        }
        int position = -1;
        if (n + m.abs() < bef.length) {
          position = note.indexOf(bef[n + m.abs()]); //在列表中的位置
        }

        int N = 0; //结果的位置
        String name = ''; //音名
        int pitch = 0; //音高
        String brackets = ''; //括号
        if (position == -1) {
          m = 0;
          aft = aft + bef[n];
        } else {
          N = m + position + x;
          pitch = octave + (N / 12).floor();
          N = (N % 12 + 12) % 12; // 取N除12的模，不是余数！
          if (autoup) {
            // 自动升号，针对#3和#7 原理是如果上一个升了，且这个是4或1就变为升记号的形式
            if (N == 0 && lastm == 1) {
              name = '(#7)';
            } else if (N == 5 && lastm == 1) {
              name = '#3';
            } else {
              name = noteMap[N];
            }
            lastm = name.contains("#") ? 1 : 0;
          } else {
            name = noteMap[N];
          }
          for (int i = 1; i <= pitch.abs(); i++) {
            brackets = '$brackets[';
          }
          aft =
              aft +
              ((pitch > 0) ? brackets : brackets.replaceAll('[', '(')) +
              name +
              ((pitch > 0)
                  ? brackets.replaceAll('[', ']')
                  : brackets.replaceAll('[', ')'));
        }
      }
      n = n + m.abs() + 1;
    }
    return aft;
  }

  /// content中有几个key
  static int countKey(String content, String key) {
    if (key.isEmpty) return 0;
    return key.allMatches(content).length;
  }

  /// 一键最简（#最少）
  static SimplifiedResult simplified(String bef) {
    int cvt = 0;
    int min = bef.length; // 最小#数目
    for (int i = -6; i < 6; i++) {
      String aft = convert(bef, i);
      int amount = countKey(aft, '#');
      // 取最接近0的转调次数
      if (amount < min || (amount == min && i.abs() < cvt.abs())) {
        min = amount;
        cvt = i;
        if (min == 0) break;
      }
    }
    return SimplifiedResult(
      result: convert(bef, cvt),
      times: cvt,
      minSharps: min,
    );
  }

  /// 找到极值音，返回序号（[最低，最高]）
  static (int?, int?) findExtreme(String content) {
    int len = content.length;
    int octave = 0;
    int? lowest;
    int? highest;
    int n = 0;
    while (n < len) {
      while (n < len) {
        //检测括号，判断八度
        if (content[n] == "[" || content[n] == ")") {
          octave += 12;
        } else if (content[n] == "]" || content[n] == "(") {
          octave -= 12;
        } else {
          break;
        }
        n++;
      }
      if (n < len) {
        int up = 0; //半音关系
        if (content[n] == "#") {
          up = 1;
        } else if (content[n] == "b") {
          up = -1;
        }
        int N = n + up.abs();
        if (N < len) {
          int position = note.indexOf(content[N]);
          if (position < 0) {
            n++;
          } //不在表格里
          else {
            position = position + up + octave;
            if (lowest == null || position < lowest) lowest = position;
            if (highest == null || position > highest) highest = position;
            n = N + 1;
          }
        } else {
          break;
        } //就是结束了，或者#后面没有东西了
      }
    }
    return (lowest, highest);
  }

  /// 把序号转换为je音符，0-->1
  static String indexToJe(int index, {List<String>? noteMap}) {
    final noteProvider = noteMap ?? note;
    int position = (index % 12 + 12) % 12;
    int k = (index / 12).floor();
    String brackets = '';
    for (int i = 0; i < k.abs(); i++) {
      brackets = '$brackets[';
    }
    return ((k > 0) ? brackets : brackets.replaceAll('[', '(')) +
        noteProvider[position] +
        ((k > 0)
            ? brackets.replaceAll('[', ']')
            : brackets.replaceAll('[', ')'));
  }
}

class SimplifiedResult {
  final String result;
  final int times;
  final int minSharps;

  SimplifiedResult({
    required this.result,
    required this.times,
    required this.minSharps,
  });
}
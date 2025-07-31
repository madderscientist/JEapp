class JeScoreOperator {
  JeScoreOperator._();

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
    List<String> aft = []; // 转换后 dart用 List&join 比 + 更合适
    int n = 0; // 位置
    int octave = 0; // 八度音高
    bool lastm = false; // 用于自动升降号，记录上一个音是否升
    while (n < bef.length) {
      if (bef[n] == ')' || bef[n] == '[') {
        ++octave;
      } else if (bef[n] == '(' || bef[n] == ']') {
        --octave;
      } else {
        // 升降半音
        final int m = switch (bef[n]) {
          '#' => 1,
          'b' => -1,
          _ => 0,
        };
        final noteEnd = n + m.abs();
        // 在列表中的位置
        int position = noteEnd < bef.length ? note.indexOf(bef[noteEnd]) : -1;
        if (position == -1) {
          aft.add(bef[n]);
        } else {
          int N = m + position + x; // 结果的位置
          final int pitch = octave + (N / 12).floor();
          N = (N % 12 + 12) % 12; // 取N除12的模，不是余数！

          final String name; //音名
          if (autoup) {
            // 自动升号，针对#3和#7 原理是如果上一个升了，且这个是4或1就变为升记号的形式
            if (N == 0 && lastm) {
              name = '(#7)';
            } else if (N == 5 && lastm) {
              name = '#3';
            } else {
              name = noteMap[N];
            }
            lastm = name.contains("#");
          } else {
            name = noteMap[N];
          }

          if (pitch >= 0) {
            aft.add('[' * pitch + name + ']' * pitch);
          } else {
            aft.add('(' * (-pitch) + name + ')' * (-pitch));
          }

          n = noteEnd; // 跳过音符
        }
      }
      n++;
    }
    return aft.join();
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

  /// 把序号转换为je音符，0-->'1'
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

  static List<TextNote> parseText(String txt) {
    final List<TextNote> parts = [];
    int n = 0; // 当前位置
    int octave = 0; // 八度音高
    while (n < txt.length) {
      if (txt[n] == ')' || txt[n] == '[') {
        ++octave;
        parts.add(TextNote(index: n, text: txt[n], note: null));
      } else if (txt[n] == '(' || txt[n] == ']') {
        --octave;
        parts.add(TextNote(index: n, text: txt[n], note: null));
      } else {
        // 升降半音
        final int m = switch (txt[n]) {
          '#' => 1,
          'b' => -1,
          _ => 0,
        };

        final noteEnd = n + m.abs();
        int position = noteEnd < txt.length ? note.indexOf(txt[noteEnd]) : -1;
        if (position == -1) {
          // 不是合法音符 挨个字符保存
          parts.add(TextNote(index: n, text: txt[n], note: null));
        } else {
          // 是音符，文本范围为 [n, noteEnd]
          parts.add(
            TextNote(
              index: n,
              text: txt.substring(n, noteEnd + 1),
              note: m + position + octave * 12,
            ),
          );
          n = noteEnd;
        }
      }
      n++;
    }
    return parts;
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

class TextNote {
  final int index;
  final String text; // 文字内容
  final int? note; // null表示不是音符 '1' -> 0 一个半音为1

  const TextNote({required this.index, required this.text, required this.note});
}
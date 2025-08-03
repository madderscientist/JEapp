import 'package:flutter/material.dart';
import 'package:je/utils/freq_table.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../mdEditor/panel.dart' show CheckButton;
import '../components/temp_textarea.dart' show TempTextArea;
import '../utils/list_notifier.dart';
import '../theme.dart';
import 'ring.dart';
import 'time_frequency.dart';

class Tuner extends StatefulWidget {
  const Tuner({super.key});
  @override
  State<Tuner> createState() => _TunerState();
}

class _TunerState extends State<Tuner> {
  final ValueNotifier<double> freqNotifier = ValueNotifier(-1);
  // 因为要被多个notifier影响 需要暴露notifier方法
  final LazyNotifier<double> pitchNotifier = LazyNotifier(-1);
  // 归一化视野中心 被TimeFrequency使用与设置 在!autoTrack时被本类使用
  final ValueNotifier<double> normedCenterNotifier = ValueNotifier(0);
  int _lastNormedCenter = 0; // 用于跟踪上次的归一化中心

  final ValueNotifier<double> sensitivityNotifier = ValueNotifier(0.2); // 灵敏度调节
  final ValueNotifier<bool> autoTrackNotifier = ValueNotifier(true); // 自动跟踪开关

  final FreqTable freqTable = FreqTable();

  // 是否展开panel
  ValueNotifier<bool> panelExpanded = ValueNotifier<bool>(false);

  ValueNotifier<bool?> isRinging = ValueNotifier<bool?>(false);
  late final Ring ring = Ring(isRinging);

  @override
  void initState() {
    super.initState();
    // 必须用 addPostFrameCallback 不然会在build时更新
    autoTrackNotifier.addListener(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        pitchNotifier.notify();
      });
    });
    normedCenterNotifier.addListener(() {
      if (!autoTrackNotifier.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          pitchNotifier.notify();
        });
        int rounded = normedCenterNotifier.value.round();
        if (_lastNormedCenter != rounded) {
          if (isRinging.value == true) {
            // 如果正在响铃，且中心变化了，则更新铃声频率
            ring.start(freqTable[rounded]);
          }
          _lastNormedCenter = rounded;
        }
      }
    });
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    freqNotifier.dispose();
    pitchNotifier.dispose();
    normedCenterNotifier.dispose();
    sensitivityNotifier.dispose();
    autoTrackNotifier.dispose();
    panelExpanded.dispose();
    ring.dispose();
    isRinging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 5,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: freqNotifier,
          builder: (context, value, child) {
            return Text(
              ' ${value < 0 ? "???" : value.toStringAsPrecision(5)}Hz',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontFamily: 'monospace'),
            );
          },
        ),
        Expanded(
          child: Stack(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: autoTrackNotifier,
                builder: (context, autoTrack, child) {
                  if (autoTrack) return const SizedBox.shrink();
                  return Center(
                    child: Container(
                      height: double.infinity,
                      width: 8,
                      color: const Color.fromARGB(128, 255, 255, 0),
                    ),
                  );
                },
              ),
              Center(
                child: ValueListenableBuilder<double>(
                  valueListenable: pitchNotifier,
                  builder: (context, value, child) {
                    if (autoTrackNotifier.value) {
                      return _buildCenterNote(value.round(), value);
                    } else {
                      return _buildCenterNote(
                        normedCenterNotifier.value.round(),
                        value,
                      );
                    }
                  },
                ),
              ),
              TimeFrequency(
                freqTable: freqTable,
                autoTrackNotifier: autoTrackNotifier,
                freqNotifier: freqNotifier,
                pitchNotifier: pitchNotifier,
                sensitivityNotifier: sensitivityNotifier,
                normedCenterNotifier: normedCenterNotifier,
              ),
              // 正弦波发生
              Positioned(
                right: 16,
                bottom: 16,
                child: ValueListenableBuilder<bool>(
                  valueListenable: autoTrackNotifier,
                  builder: (context, autoTrack, child) {
                    return AnimatedScale(
                      scale: autoTrack ? 0.0 : 1.0, // 0 消失，1 显示
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.fastOutSlowIn,
                      alignment: Alignment.center, // 中心缩放
                      child: ValueListenableBuilder<bool?>(
                        valueListenable: isRinging,
                        builder: (context, ringing, child) {
                          return GestureDetector(
                            onTap: _ringAction,
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.color,
                              child: Icon(
                                switch (ringing) {
                                  true => Icons.notifications_active,
                                  false => Icons.notifications,
                                  null => Icons.notifications_paused,
                                },
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        _buildHead(),
      ],
    );
  }

  Widget _buildCenterNote(int target, double pitch) {
    if (target < 0 || target >= freqTable.length) {
      return const SizedBox.shrink();
    }
    String noteName = FreqTable.noteName[target % 12];
    double diff = pitch - target;
    double t = diff.abs();
    Color noteColor;
    if (t < 0.1) {
      noteColor = Colors.lightGreenAccent;
    } else if (t < 0.25) {
      noteColor = Colors.orangeAccent;
    } else {
      noteColor = Colors.deepPurpleAccent;
    }
    String tip;
    if (t < 0.1) {
      tip = '完美';
    } else if (diff < 0) {
      tip = '偏低';
    } else {
      tip = '偏高';
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RichText(
          text: buildSupSub(
            base: noteName[0],
            sup: noteName.length > 1 ? noteName[1] : ' ',
            sub: (target ~/ 12 + 1).toString(),
            style: TextStyle(
              fontSize: 200,
              fontWeight: FontWeight.bold,
              color: noteColor.withAlpha(64),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(0, -70),
          child: Text(
            tip,
            style: TextStyle(
              fontSize: 28,
              color: noteColor.withAlpha(64),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _ringAction() {
    if (isRinging.value == null) return;
    if (isRinging.value == false) {
      ring.start(freqTable[normedCenterNotifier.value.round()]);
    } else {
      ring.stop();
    }
  }

  void _switchTrackMode() {
    if (autoTrackNotifier.value == false && isRinging.value == true) {
      ring.stop();
    }
    autoTrackNotifier.value = !autoTrackNotifier.value;
  }

  Widget _buildHead() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(32),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.of(context).maybePop();
                  },
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Center(child: Text('调音器')),
                      ValueListenableBuilder<bool>(
                        valueListenable: autoTrackNotifier,
                        builder: (context, autoTrack, child) {
                          return CheckButton(
                            text: autoTrack ? '自动跟踪' : '手动调节',
                            checked: autoTrack,
                            onPressed: _switchTrackMode,
                            disabledStyle: AppTheme.primaryElevatedButtonStyle,
                            disabledTextStyle: const TextStyle(
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // 收起
                ValueListenableBuilder<bool>(
                  valueListenable: panelExpanded,
                  builder: (context, expanded, child) {
                    return IconButton(
                      icon: Icon(
                        expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                      ),
                      onPressed: () {
                        panelExpanded.value = !expanded;
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: panelExpanded,
            builder: (context, expanded, child) {
              return AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 300),
                sizeCurve: Curves.fastOutSlowIn,
                crossFadeState: expanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: _buildHeadContent(),
                secondChild: const SizedBox(height: 0, width: double.infinity),
                alignment: Alignment.bottomCenter,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeadContent() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          _buildQuickNotes(),
          // yin算法敏感度
          Row(
            children: [
              const Text('迟钝'),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: sensitivityNotifier,
                  builder: (context, sensitivity, child) {
                    return Slider(
                      value: sensitivity,
                      min: 0.05,
                      max: 1.0,
                      divisions: 19,
                      label: sensitivity.toStringAsFixed(2),
                      onChanged: (value) {
                        sensitivityNotifier.value = value;
                      },
                    );
                  },
                ),
              ),
              const Text('敏感'),
            ],
          ),
          Row(
            children: [
              const Expanded(child: Text('A4频率: ')),
              IconButton(
                icon: const Icon(Icons.arrow_left),
                onPressed: () {
                  setState(() {
                    freqTable.A4 = freqTable.A4 - 1;
                  });
                },
              ),
              GestureDetector(onTap: _setA4, child: Text('${freqTable.A4} Hz')),
              IconButton(
                icon: const Icon(Icons.arrow_right),
                onPressed: () {
                  setState(() {
                    freqTable.A4 = freqTable.A4 + 1;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setA4() {
    const int maxFreq = 622;
    const int minFreq = 311;
    const String overError = '频率最大为${maxFreq}Hz';
    const String underError = '频率最小为${minFreq}Hz';
    const String emptyError = '请输入频率';
    final controller = TextEditingController();
    String getLabelText() {
      if (controller.text.isEmpty) return emptyError;
      int? newBPM = int.tryParse(controller.text);
      if (newBPM == null) return emptyError;
      if (newBPM > maxFreq) {
        return overError;
      } else if (newBPM < minFreq) {
        return underError;
      }
      return '';
    }

    final labelNotifier = ValueNotifier<String>(getLabelText());
    controller.addListener(() {
      labelNotifier.value = getLabelText();
    });
    bool canDispose = false;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置BPM'),
          content: ValueListenableBuilder<String>(
            valueListenable: labelNotifier,
            builder: (context, labelText, child) {
              return TempTextArea(
                controller: controller,
                decoration: InputDecoration(
                  labelText: labelText,
                  labelStyle: TextStyle(color: Colors.red),
                ),
                expands: false,
                maxLines: 1,
                onDispose: () {
                  if (canDispose) {
                    controller.dispose();
                    labelNotifier.dispose();
                  }
                },
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                autofocus: true,
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isEmpty) return;
                double? newFreq = double.tryParse(controller.text);
                if (newFreq == null) return;
                if (newFreq > maxFreq || newFreq < minFreq) return;
                canDispose = true;
                Navigator.of(context).pop();
                setState(() {
                  freqTable.A4 = newFreq;
                });
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  static const presetNotes = {
    '吉他': [
      ('E4', 40),
      ('B3', 35),
      ('G3', 31),
      ('D3', 26),
      ('A2', 21),
      ('E2', 16),
    ],
    '小提琴': [('E5', 52), ('A4', 45), ('D4', 38), ('G3', 31)],
    '尤克里里': [('A4', 45), ('E4', 40), ('C4', 36), ('G4', 43)],
  };

  Widget _buildQuickNotes() {
    return ValueListenableBuilder<bool>(
      valueListenable: autoTrackNotifier,
      builder: (context, autoTrack, child) {
        return AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          reverseDuration: const Duration(milliseconds: 300),
          alignment: Alignment.center,
          sizeCurve: Curves.fastOutSlowIn,
          crossFadeState: autoTrack
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: const SizedBox(height: 0, width: double.infinity),
          secondChild: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presetNotes.entries.map((entry) {
                return _buildPresetNotes(entry.key, entry.value);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetNotes(String name, List<(String, int)> notes) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Color(0xFEDCBA98 + name.hashCode.abs() % 0xFFFFFF).withAlpha(38),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          ...notes.map((note) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    normedCenterNotifier.value = note.$2.toDouble();
                  });
                },
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  // radius: 18,
                  child: Text(
                    note.$1,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 把单个字符渲染成上/下标，偏移量与字体匹配
TextSpan buildSupSub({
  required String base,
  required String sup,
  required String sub,
  required TextStyle style,
}) {
  final smallStyle = style.copyWith(fontSize: style.fontSize! * 0.45);
  double offset = smallStyle.fontSize! * 0.35; // 上下标偏移量
  return TextSpan(
    style: style,
    children: [
      TextSpan(text: base),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, offset), // 上标往下挪
              child: Text(sup, style: smallStyle),
            ),
            Transform.translate(
              offset: Offset(0, -offset), // 下标往上挪
              child: Text(sub, style: smallStyle),
            ),
          ],
        ),
      ),
    ],
  );
}

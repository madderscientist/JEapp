import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../theme.dart';
import '../utils/list_notifier.dart';
import '../utils/background_service_handler.dart';
import 'beat_circle.dart';
import 'shot_player.dart';
import 'beat_level.dart';
import 'beat_manager.dart';
import '../mdEditor/panel.dart' show CheckButton;
import '../components/temp_textarea.dart' show TempTextArea;

class Metronome extends StatefulWidget {
  const Metronome({super.key});
  static const int bpmMax = 400;
  static const int bpmMin = 10;

  @override
  State<Metronome> createState() => _MetronomeState();
}

class _MetronomeState extends State<Metronome> {
  // 节奏产生
  late final BeatManager _manager;
  late final StreamSubscription<void> _beatSub; // 节拍流订阅
  // 播放器
  late final ShotPlayer player;
  // 初始化状态
  bool initialized = false;

  // bpm关联一个视觉元素，用_handle的ValueNotifier
  // 下面直接设置即可，无需setState
  int get bpm => _manager.bpm;
  set bpm(int newBPM) => _manager.bpm = newBPM;

  /// head区的选项
  // 静音
  ValueNotifier<bool> muteNotifier = ValueNotifier<bool>(false);
  // 震动
  ValueNotifier<bool> vibrateNotifier = ValueNotifier<bool>(false);

  // 节奏型 4种状态 静音为0 数字越大越重
  final ListNotifier<ValueNotifier<int>> beatLevels = ListNotifier([
    ValueNotifier<int>(3),
    ValueNotifier<int>(1),
    ValueNotifier<int>(2),
    ValueNotifier<int>(1),
  ]);
  final LazyNotifier<int> _beatCnt = LazyNotifier<int>(0);

  // 是否展开panel
  ValueNotifier<bool> panelExpanded = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    // 播放器初始化 & BeatManager初始化(包括AudioService初始化)
    Future.wait([
      ShotPlayer.create().then((p) => player = p),
      BackGroundServiceHandler.getAudioServiceHandler()
          .then((handler) => BeatManager.create(handler))
          .then((manager) => _manager = manager),
    ]).then((_) {
      _beatSub = _manager.beatStream.listen(_onBeat);
      setState(() => initialized = true);
    });
  }

  void _onBeat(void _) {
    _beatCnt.notify();
    if (vibrateNotifier.value) HapticFeedback.heavyImpact();
    if (!muteNotifier.value) {
      player.beat(beatLevels.value[_beatCnt.value].value);
    }
    _beatCnt.setValue((_beatCnt.value + 1) % beatLevels.value.length);
  }

  // beatCircle滚动音效与节拍变化
  void _onBeatChange(int delta) {
    final lastBPM = bpm;
    bpm = (bpm + delta);
    if (bpm == lastBPM + delta) {
      player.rollInRange();
    } else {
      player.rollOverRange();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    if (initialized) {
      _beatSub.cancel();
      player.dispose();
      _manager.dispose();
    }
    for (final notifier in beatLevels.value) {
      notifier.dispose();
    }
    beatLevels.dispose();
    muteNotifier.dispose();
    vibrateNotifier.dispose();
    panelExpanded.dispose();
    _beatCnt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        // 动效
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: BeatCircle(
                  beatStream: _manager.beatStream,
                  enable: _manager.enableNotifier,
                  onBeatChange: _onBeatChange,
                ),
              ),
              // 圆心按钮
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        bpm = bpm - 1;
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        _manager.enable = !_manager.enable;
                        if (_manager.enable == false) {
                          _beatCnt.setValue(0); // 不要触发
                        }
                      },
                      onLongPress: _typeInBPM,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _manager.bpmNotifier,
                        builder: (context, bpm, child) {
                          return Text(
                            bpm.toString(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.normal,
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        bpm = bpm + 1;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 设置界面
        _buildHead(),
      ],
    );
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
      // 避开底部导航栏
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
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('     节拍器'),
                      ValueListenableBuilder<bool>(
                        valueListenable: muteNotifier,
                        builder: (context, muted, child) {
                          return IconButton(
                            icon: Icon(
                              muted ? Icons.volume_off : Icons.volume_up,
                              color: muted ? Colors.grey : Colors.black,
                            ),
                            onPressed: () {
                              muteNotifier.value = !muted;
                            },
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
    return Column(
      spacing: 6,
      children: [
        ValueListenableBuilder<List<ValueNotifier<int>>>(
          valueListenable: beatLevels,
          builder: (context, value, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(value.length, (i) {
                return ValueListenableBuilder<int>(
                  valueListenable: value[i],
                  builder: (context, level, child) {
                    return BeatLevel(
                      id: i,
                      level: level,
                      onTap: (newLevel) => value[i].value = newLevel,
                      beatTick: _beatCnt,
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () {
                if (beatLevels.value.length <= 1) return;
                final last = beatLevels.value.last;
                beatLevels.value.removeLast();
                beatLevels.notify();
                last.dispose(); // 释放资源
                if (_beatCnt.value >= beatLevels.value.length) {
                  _beatCnt.setValue(0); // 重置计数
                }
              },
              icon: Icon(Icons.remove),
            ),
            _buildBeatGroup(),
            _buildTap(),
            ValueListenableBuilder<bool>(
              valueListenable: vibrateNotifier,
              builder: (context, value, child) {
                return CheckButton(
                  text: '震动',
                  checked: value,
                  onPressed: () {
                    vibrateNotifier.value = !vibrateNotifier.value;
                  },
                );
              },
            ),
            IconButton(
              onPressed: () {
                if (beatLevels.value.length >= 16) return;
                beatLevels.value.add(ValueNotifier<int>(2));
                beatLevels.notify();
              },
              icon: Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  /// Tap确定节拍
  DateTime _lastTapTime = DateTime.now();
  bool _validTap = false;
  void _onTap() {
    player.tap();
    final now = DateTime.now();
    final delta = now.difference(_lastTapTime);
    final newBPM = (60000 / delta.inMilliseconds).round();
    _lastTapTime = now;
    if (_validTap) {
      _validTap = false;
      bpm = newBPM;
      return;
    }
    if ((newBPM - bpm).abs() / bpm < 0.2) {
      bpm = (newBPM * 0.7 + bpm * 0.3).toInt();
    } else {
      _validTap = true;
    }
  }

  Widget _buildTap() {
    return GestureDetector(
      onTapDown: (_) => _onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(32),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'Tap',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBeatGroup() {
    return ValueListenableBuilder<int>(
      valueListenable: player.beatGroupNotifier,
      builder: (context, group, child) {
        String groupName;
        switch (group) {
          case 1:
            groupName = '音效2';
            break;
          case 2:
            groupName = '音效3';
            break;
          default:
            groupName = '音效1';
            break;
        }
        return ElevatedButton(
          onPressed: () {
            player.beatGroup = group + 1;
          },
          style: AppTheme.secondaryElevatedButtonStyle.copyWith(
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          child: Text(groupName),
        );
      },
    );
  }

  /// 输入BPM 模仿detail.dart
  void _typeInBPM() {
    const String overError = 'BPM最大为${BeatManager.bpmMax}';
    const String underError = 'BPM最小为${BeatManager.bpmMin}';
    const String emptyError = '请输入BPM';
    final controller = TextEditingController();
    String getLabelText() {
      if (controller.text.isEmpty) return emptyError;
      int? newBPM = int.tryParse(controller.text);
      if (newBPM == null) return emptyError;
      if (newBPM > BeatManager.bpmMax) {
        return overError;
      } else if (newBPM < BeatManager.bpmMin) {
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
                keyboardType: TextInputType.number,
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
                canDispose = true;
                Navigator.of(context).pop();
                if (controller.text.isEmpty) return;
                bpm = int.tryParse(controller.text) ?? bpm;
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }
}

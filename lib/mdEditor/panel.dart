import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toastification/toastification.dart';
import '../utils/je_score.dart';
import '../theme.dart';
import '../config.dart';
import '../components/searchbar.dart';

/// 转调器&编辑器 确认取消按键由别的页面完成
class Panel extends StatefulWidget {
  /// 外部用于读取编辑的内容的
  final TextEditingController? controller;

  /// 外部用于获取最音数据的 如果传递了则本组件不再渲染
  final ValueNotifier<(String, String)>? extremeNotes;

  /// dispose发生在complete之后，所以必须在回调中controller.dispose
  final void Function()? onDispose;
  const Panel({super.key, this.controller, this.onDispose, this.extremeNotes});

  @override
  State<Panel> createState() => _PanelState();
}

class _PanelState extends State<Panel> {
  late final TextEditingController _mainController;
  final FocusNode _mainFocusNode = FocusNode();
  late final TextEditingController _semitoneController;
  final FocusNode _semitoneFocusNode = FocusNode();
  late final TextEditingController _extremeController;
  final FocusNode _extremeFocusNode = FocusNode();

  TextEditingController? _currentController;

  final List<String> _noteAft = [...JeScoreOperator.upNotes];

  late final ValueNotifier<(String, String)> _extremeNotes;

  // 转调方式
  final ValueNotifier<int> _pitchSelect = ValueNotifier(-1);
  final ValueNotifier<int> _pitchUpDown = ValueNotifier(1);

  final ValueNotifier<int> _tonalityFrom = ValueNotifier(0);
  final ValueNotifier<int> _tonalityTo = ValueNotifier(0);

  final ValueNotifier<bool> _extremeMode = ValueNotifier(false); // 0-最低 1-最高

  // 转调模式
  final ValueNotifier<bool> _ifLessBrackets = ValueNotifier(true);
  final ValueNotifier<bool> _semiMode = ValueNotifier(true);
  final ValueNotifier<bool> _up3 = ValueNotifier(false);
  final ValueNotifier<bool> _up7 = ValueNotifier(false);
  final ValueNotifier<bool> _autoup = ValueNotifier(false);

  bool get autoup => _autoup.value && _semiMode.value;

  // 快捷输入
  final ValueNotifier<bool> _ifShowInputBar = ValueNotifier(false);
  bool _kbdExpansion = false;

  @override
  void initState() {
    super.initState();
    _mainController = widget.controller ?? TextEditingController();
    _semitoneController = TextEditingController();
    _extremeController = TextEditingController(text: '(1)');
    // focus绑定
    _mainFocusNode.addListener(_handleFocusChange);
    _extremeFocusNode.addListener(_handleFocusChange);
    _semitoneFocusNode.addListener(_handleFocusChange);
    _semitoneFocusNode.addListener(() {
      if (_semitoneFocusNode.hasFocus) {
        // 延迟设置，确保在 TextField 获得焦点后执行
        Future.delayed(Duration(milliseconds: 10), () {
          _semitoneController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _semitoneController.text.length,
          );
        });
      }
    });
    // value notifier
    _extremeNotes = widget.extremeNotes ?? ValueNotifier(('?', '?'));
    // 初始化时计算一次 如果是外部传入extremeNotes的且外部监听(editable_mdwidget.dart:_showPanel)，必须延迟一下
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateExtreme());
  }

  @override
  void dispose() {
    if (widget.controller == null) _mainController.dispose();
    _extremeController.dispose();
    _semitoneController.dispose();

    _mainFocusNode.dispose();
    _semitoneFocusNode.dispose();
    _extremeFocusNode.dispose();

    if (widget.extremeNotes == null) _extremeNotes.dispose();
    _pitchSelect.dispose();
    _pitchUpDown.dispose();
    _tonalityFrom.dispose();
    _tonalityTo.dispose();
    _extremeMode.dispose();
    _autoup.dispose();
    _ifLessBrackets.dispose();
    _ifShowInputBar.dispose();
    _semiMode.dispose();

    if (widget.extremeNotes != null || widget.controller != null) {
      widget.onDispose?.call();
    }

    super.dispose();
  }

  void _handleFocusChange() {
    if (_mainFocusNode.hasFocus) {
      _currentController = _mainController;
    } else if (_extremeFocusNode.hasFocus) {
      _currentController = _extremeController;
    } else {
      _currentController = null;
    }
    _updateInputBarStatus();
  }

  void _updateInputBarStatus() {
    _ifShowInputBar.value = _kbdExpansion && _currentController != null;
  }

  void _updateExtreme() {
    var (lowest, highest) = JeScoreOperator.findExtreme(_mainController.text);
    _extremeNotes.value = (
      (lowest == null)
          ? '?'
          : JeScoreOperator.indexToJe(lowest, noteMap: _noteAft),
      (highest == null)
          ? '?'
          : JeScoreOperator.indexToJe(highest, noteMap: _noteAft),
    );
  }

  String _niceBrackets(String score) {
    score = score.replaceAll('[(', '').replaceAll(')]', '');
    if (_ifLessBrackets.value) {
      return score
          .replaceAll('][', '')
          .replaceAll(')(', '')
          .replaceAll('][', '')
          .replaceAll(')(', '');
    }
    return score;
  }

  Widget _buildNum(BuildContext context, TextStyle? textStyle) {
    return Row(
      spacing: 6,
      children: [
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: _pitchSelect,
            builder: (context, value, child) {
              return DropdownButtonFormField<int>(
                style: textStyle,
                value: value,
                items: const [
                  DropdownMenuItem(value: -1, child: Text('所有音')),
                  DropdownMenuItem(value: 0, child: Text('所有do')),
                  DropdownMenuItem(value: 2, child: Text('所有re')),
                  DropdownMenuItem(value: 4, child: Text('所有mi')),
                  DropdownMenuItem(value: 5, child: Text('所有fa')),
                  DropdownMenuItem(value: 7, child: Text('所有so')),
                  DropdownMenuItem(value: 9, child: Text('所有la')),
                  DropdownMenuItem(value: 11, child: Text('所有si')),
                ],
                onChanged: (newValue) {
                  if (newValue != null) {
                    _pitchSelect.value = newValue;
                  }
                },
              );
            },
          ),
        ),
        IntrinsicWidth(
          child: ValueListenableBuilder<int>(
            valueListenable: _pitchUpDown,
            builder: (context, value, child) {
              return DropdownButtonFormField<int>(
                style: textStyle,
                value: value,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('升')),
                  DropdownMenuItem(value: -1, child: Text('降')),
                ],
                onChanged: (newValue) {
                  if (newValue != null) {
                    _pitchUpDown.value = newValue;
                  }
                },
              );
            },
          ),
        ),
        Expanded(
          child: TextField(
            style: textStyle,
            textAlign: TextAlign.center,
            controller: _semitoneController,
            focusNode: _semitoneFocusNode,
            decoration: InputDecoration(
              labelStyle: textStyle,
              labelText: '半音数',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        ElevatedButton(onPressed: _byNum, child: const Text('转换')),
      ],
    );
  }

  void _byNum() {
    int by = _pitchUpDown.value * (int.tryParse(_semitoneController.text) ?? 0);
    int n = _pitchSelect.value;
    if (n >= 0) {
      List<String> tempNotes = [..._noteAft];
      tempNotes[n] = JeScoreOperator.convert(
        tempNotes[n],
        by,
        noteAft: _noteAft,
        autoup: false,
      );
      _mainController.text = _niceBrackets(
        JeScoreOperator.convert(
          _mainController.text,
          0,
          noteAft: tempNotes,
          autoup: autoup,
        ),
      );
    } else {
      _mainController.text = _niceBrackets(
        JeScoreOperator.convert(
          _mainController.text,
          by,
          noteAft: _noteAft,
          autoup: autoup,
        ),
      );
    }
    _updateExtreme();
  }

  Widget _buildTonality(BuildContext context, TextStyle? textStyle) {
    const tonality = [
      DropdownMenuItem(value: 0, child: Text('1 = C')),
      DropdownMenuItem(value: 1, child: Text('1 = #C')),
      DropdownMenuItem(value: 2, child: Text('1 = D')),
      DropdownMenuItem(value: 3, child: Text('1 = #D')),
      DropdownMenuItem(value: 4, child: Text('1 = E')),
      DropdownMenuItem(value: 5, child: Text('1 = F')),
      DropdownMenuItem(value: 6, child: Text('1 = #F')),
      DropdownMenuItem(value: 7, child: Text('1 = G')),
      DropdownMenuItem(value: 8, child: Text('1 = #G')),
      DropdownMenuItem(value: 9, child: Text('1 = A')),
      DropdownMenuItem(value: 10, child: Text('1 = #A')),
      DropdownMenuItem(value: 11, child: Text('1 = B')),
    ];
    return Row(
      spacing: 6,
      children: [
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: _tonalityFrom,
            builder: (context, value, child) {
              return DropdownButtonFormField<int>(
                style: textStyle,
                decoration: InputDecoration(
                  labelText: '转换前',
                  labelStyle: textStyle,
                ),
                value: value,
                items: tonality,
                onChanged: (newValue) {
                  if (newValue != null) {
                    _tonalityFrom.value = newValue;
                  }
                },
              );
            },
          ),
        ),
        Text('到', style: textStyle),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: _tonalityTo,
            builder: (context, value, child) {
              return DropdownButtonFormField<int>(
                style: textStyle,
                decoration: InputDecoration(
                  labelText: '转换后',
                  labelStyle: textStyle,
                ),
                value: value,
                items: tonality,
                onChanged: (newValue) {
                  if (newValue != null) {
                    _tonalityTo.value = newValue;
                  }
                },
              );
            },
          ),
        ),
        ElevatedButton(onPressed: _byTonality, child: const Text('转换')),
      ],
    );
  }

  void _byTonality() {
    int x = _tonalityFrom.value - _tonalityTo.value;
    _mainController.text = _niceBrackets(
      JeScoreOperator.convert(
        _mainController.text,
        x,
        noteAft: _noteAft,
        autoup: autoup,
      ),
    ); // setter不会触发onChange
    _updateExtreme();
  }

  Widget _buildExtreme(BuildContext context, TextStyle? textStyle) {
    return Row(
      spacing: 6,
      children: [
        IntrinsicWidth(
          child: ValueListenableBuilder<bool>(
            valueListenable: _extremeMode,
            builder: (context, value, child) {
              return DropdownButtonFormField<bool>(
                style: textStyle,
                value: value,
                items: const [
                  DropdownMenuItem(value: false, child: Text('最低音')),
                  DropdownMenuItem(value: true, child: Text('最高音')),
                ],
                onChanged: (newValue) {
                  if (newValue != null) {
                    _extremeMode.value = newValue;
                  }
                },
              );
            },
          ),
        ),
        Text('为', style: textStyle),
        Expanded(
          child: TextField(
            style: textStyle,
            controller: _extremeController,
            focusNode: _extremeFocusNode,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelStyle: textStyle,
              labelText: '目标音',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        ElevatedButton(
          onPressed: () => _byExtreme(context),
          child: const Text('转换'),
        ),
      ],
    );
  }

  void _byExtreme(BuildContext context) {
    final (targetLowest, targetHighest) = JeScoreOperator.findExtreme(
      _extremeController.text,
    );
    int? target = _extremeMode.value ? targetHighest : targetLowest;
    if (target == null) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.flatColored,
        title: Text('${_extremeController.text}不是有效的je谱'),
        alignment: Alignment.topCenter,
        autoCloseDuration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(12.0),
        showProgressBar: false,
        dragToClose: true,
        applyBlurEffect: false,
      );
      return;
    }
    var (lowest, highest) = JeScoreOperator.findExtreme(_mainController.text);
    int? now = _extremeMode.value ? highest : lowest;
    if (now == null) {
      // 正文不合格不管
      return;
    }
    _mainController.text = _niceBrackets(
      JeScoreOperator.convert(
        _mainController.text,
        target - now,
        noteAft: _noteAft,
        autoup: autoup,
      ),
    );
    _updateExtreme();
  }

  Widget _buildTools(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: () {
            final result = JeScoreOperator.simplified(_mainController.text);
            _mainController.text = result.result;
            late String title;
            if (result.times < 0) {
              title = '降${-result.times}调';
            } else if (result.times > 0) {
              title = '升${result.times}调';
            } else {
              title = '♯已经最少了';
            }
            toastification.show(
              context: context,
              type: ToastificationType.info,
              style: ToastificationStyle.flatColored,
              title: Text(title),
              description: Text('最少${result.minSharps}个♯'),
              alignment: Alignment.bottomCenter,
              autoCloseDuration: const Duration(seconds: 2),
              borderRadius: BorderRadius.circular(12.0),
              showProgressBar: false,
              dragToClose: true,
              applyBlurEffect: false,
            );
          },
          child: const Text('最少#'),
        ),
        ElevatedButton(
          onPressed: () {
            String x = JeScoreOperator.convert(_mainController.text, -1);
            x = x
                .replaceAll('#1', 'b2')
                .replaceAll('#2', 'b3')
                .replaceAll('#4', 'b5')
                .replaceAll('#5', 'b6')
                .replaceAll('#6', 'b7');
            _mainController.text = _niceBrackets(x);
            _updateExtreme();
          },
          child: const Text('1=#C'),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _semiMode,
          builder: (context, sharpMode, child) {
            return CheckButton(
              text: '半音:${sharpMode ? '#' : 'b'}',
              checked: sharpMode,
              disabledStyle: AppTheme.primaryElevatedButtonStyle,
              disabledTextStyle: const TextStyle(color: Colors.white),
              onPressed: () {
                _semiMode.value = !sharpMode;
                if (_semiMode.value) {
                  _noteAft
                    ..clear()
                    ..addAll(JeScoreOperator.upNotes);
                  if (_up3.value) {
                    _noteAft[5] = '#3';
                  } else {
                    _noteAft[5] = '4';
                  }
                } else {
                  _noteAft
                    ..clear()
                    ..addAll(JeScoreOperator.downNotes);
                }
                _mainController.text = _niceBrackets(
                  JeScoreOperator.convert(
                    _mainController.text,
                    0,
                    noteAft: _noteAft,
                    autoup: autoup,
                  ),
                );
                _updateExtreme();
              },
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _ifLessBrackets,
          builder: (context, value, child) {
            return CheckButton(
              text: '更少括号',
              checked: value,
              onPressed: () => _ifLessBrackets.value = !value,
            );
          },
        ),
      ],
    );
  }

  Widget _buildOptions(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: ValueListenableBuilder<bool>(
          valueListenable: _semiMode,
          builder: (context, sharpMode, child) {
            if (sharpMode) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _up3,
                    builder: (context, value, child) {
                      return CheckButton(
                        text: '4→#3',
                        checked: value,
                        onPressed: () {
                          _up3.value = !_up3.value;
                          if (_semiMode.value == false) return;
                          _noteAft[5] = _up3.value ? '#3' : '4';
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _up7,
                    builder: (context, value, child) {
                      return CheckButton(
                        text: '[1]→#7',
                        checked: value,
                        onPressed: () {
                          _up7.value = !_up7.value;
                          if (_semiMode.value == false) return;
                          _noteAft[0] = _up7.value ? '(#7)' : '1';
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _autoup,
                    builder: (context, value, child) {
                      return CheckButton(
                        text: '自动升记号(口琴专用)',
                        checked: value,
                        onPressed: () {
                          _autoup.value = !_autoup.value;
                        },
                      );
                    },
                  ),
                ],
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Row(
      spacing: 4,
      children: [
        for (final symbol in const ['(', ')', '[', ']', 'b', '#'])
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final ctrl = _currentController;
                if (ctrl == null) return;
                final text = ctrl.text;
                final selection = ctrl.selection;
                final start = selection.start;
                final end = selection.end;
                final newText = text.replaceRange(start, end, symbol);
                ctrl.text = newText;
                final newOffset = start + symbol.length;
                ctrl.selection = TextSelection.collapsed(offset: newOffset);
                _updateExtreme();
              },
              style: AppTheme.secondaryElevatedButtonStyle,
              child: Text(symbol),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    return Column(
      children: [
        // 音域显示
        if (widget.extremeNotes == null)
          ValueListenableBuilder<(String, String)>(
            valueListenable: _extremeNotes,
            // ignore: non_constant_identifier_names
            builder: (context, low_high, child) {
              return Text('最低音 ${low_high.$1}  最高音 ${low_high.$2}');
            },
          ),
        Expanded(
          child: TextField(
            style: textStyle,
            controller: _mainController,
            focusNode: _mainFocusNode,
            decoration: const InputDecoration(
              hintText:
                  '◉ (低音) 中音 [高音]，括号可嵌套 #升半音 b降半音\n'
                  '◉ E调→C调 ⇔ 1→3\n'
                  '◉ 1=#C是口琴的记谱方式，这里用降记号代替还原号\n'
                  '◉ “自动升记号”会根据上一个音符决定用4/#3、1/#7\n'
                  '◎ 编辑文字时仅支持markdown行内元素语法',
              contentPadding: EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 8,
              ),
            ),
            maxLines: null, // 允许多行输入
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => _updateExtreme(),
          ),
        ),
        // 转调选择
        _buildNum(context, textStyle),
        _buildTonality(context, textStyle),
        _buildExtreme(context, textStyle),
        _buildTools(context),
        _buildOptions(context),
        // 快捷输入 出现有动画
        ValueListenableBuilder<bool>(
          valueListenable: _ifShowInputBar,
          builder: (context, value, child) {
            return AnimatedSwitcher(
              duration: const Duration(
                milliseconds: Config.keyboardAnimationDuration ~/ 3,
              ),
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axis: Axis.vertical,
                  child: child,
                );
              },
              child: value
                  ? _buildInputBar(context)
                  : const SizedBox.shrink(key: ValueKey('empty')),
            );
          },
        ),
        KeyboardSpacer(
          initExpanded: false,
          onExpand: () {
            _kbdExpansion = true;
            _updateInputBarStatus();
          },
          onCollapse: () {
            _kbdExpansion = false;
            _updateInputBarStatus();
            FocusScope.of(context).unfocus();
          },
        ),
      ],
    );
  }
}

class CheckButton extends StatelessWidget {
  final String text;
  final bool checked;
  final VoidCallback? onPressed;
  final ButtonStyle? disabledStyle;
  final TextStyle? disabledTextStyle;

  const CheckButton({
    super.key, 
    required this.text,
    required this.checked,
    this.onPressed,
    this.disabledStyle,
    this.disabledTextStyle = const TextStyle(color: Colors.grey),
  });

  @override
  Widget build(BuildContext context) {
    final style = checked
        ? AppTheme.secondaryElevatedButtonStyle
        : (disabledStyle ?? AppTheme.disabledElevatedButtonStyle);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: ElevatedButton(
        key: ValueKey(checked),
        onPressed: onPressed,
        style: style.copyWith(
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
        child: Text(text, style: checked ? null : disabledTextStyle),
      ),
    );
  }
}

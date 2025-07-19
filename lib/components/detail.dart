import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../mdEditor/builder.dart';
import '../mdEditor/branch.dart' as branch;
import '../utils/file.dart';
import '../config.dart';
import '../theme.dart';
import 'long_press_copy.dart';

class Detail extends StatefulWidget {
  final String title;
  final String? raw;
  final String? user;
  final String? time;
  final File? local; // 是否为本地数据
  /// local=File，进入本地模式。优先使用raw的，若raw==null则从文件中读取
  /// local=null，raw!=null，说明是网络数据，不能编辑
  /// local=null，raw==null，进入模板模式
  const Detail({
    super.key,
    required this.title,
    required this.raw,
    required this.local,
    this.user,
    this.time,
  });

  @override
  State<Detail> createState() => _DetailState();
}

class _DetailState extends State<Detail> {
  late File? local; // 保存后变为本地文件路径
  late branch.Common ast;
  late String _lastSaved;
  late String localTitle; // 保存后的title可能和传入的不一样

  @override
  void initState() {
    super.initState();
    local = widget.local;
    localTitle = widget.title;
    if (widget.raw == null) {
      if (local == null) {
        // 非本地还不传raw，说明是新建，使用模板
        _lastSaved = _template;
      } else {
        // 如果是本地数据但没有raw，说明要从文件读取
        _lastSaved = "## 正在加载中\n_(:з)∠)_";
        local!.readAsString().then((value) {
          if (context.mounted) {
            setState(() {
              _lastSaved = value;
              ast = fromMarkdown(value);
            });
          }
        });
      }
    } else {
      _lastSaved = widget.raw!;
    }
    ast = fromMarkdown(_lastSaved);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        bottom: true,
        top: false,
        child: PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            FocusManager.instance.primaryFocus?.unfocus();
            if (didPop) return; // 已经pop，无需拦截
            if (local == null) {
              Navigator.of(context).pop();
              return;
            }
            String finalMd = MdNode.mdCode(ast);
            if (finalMd == _lastSaved) {
              Navigator.of(context).pop();
              return; // 没有修改，直接返回
            }
            final action = await showDialog<bool?>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('内容未保存'),
                content: const Text('是否保存？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('不保存'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('保存'),
                  ),
                ],
              ),
            );
            if (!context.mounted) return;
            if (action == null) {
              return;
            } else if (action == false) {
              Navigator.of(context).pop();
            } else if (action == true) {
              if (!await save(context)) return;
              if (!context.mounted) return;
              Navigator.of(context).pop();
            }
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: LongPressCopyBubble(text: widget.title),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                floating: true, // 向上滑动时立即出现
                snap: true, // 快速滑动时立即出现
                pinned: false, // 不固定在顶部
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      _showEditor(context).then((newMarkdown) {
                        if (context.mounted) FocusScope.of(context).unfocus();
                        if (newMarkdown != null) {
                          setState(() => ast = fromMarkdown(newMarkdown));
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      local == null
                          ? Icons.favorite_outline
                          : Icons.save_outlined,
                    ),
                    onPressed: () => save(context),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Column(
                    // 下面的key很关键。如果不设置，在markdown编辑中修改了内容但结构不变，则setState不会刷新UI
                    // 如果设置了UniqueKey，则长按出现编辑框都会重建，导致子组件延迟的setState报错：widget已经不在tree中
                    // 考虑到Detail中setState会重建ast，所以这里使用ValueKey
                    key: ValueKey(ast),
                    children: [
                      ast.build(context),
                      if (widget.user != null || widget.time != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            [
                              if (widget.user != null) 'by ${widget.user}',
                              if (widget.time != null) 'at ${widget.time}',
                            ].join(' '),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showEditor(BuildContext context) {
    final controller = TextEditingController(text: MdNode.mdCode(ast));
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        const padding = EdgeInsets.symmetric(horizontal: 6);
        return SafeArea(
          // 跳过底部状态栏
          child: Padding(
            // 使得输入框不被键盘遮挡
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  padding: padding,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: '取消',
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                      Expanded(
                        child: const Text(
                          'Markdown编辑',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        tooltip: '确认',
                        onPressed: () {
                          Navigator.of(
                            sheetContext,
                          ).pop(controller.text.trim());
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: padding,
                    child: TempTextArea(
                      controller: controller,
                      expands: true,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: '请输入Markdown内容',
                      ),
                      onDispose: () {
                        controller.dispose();
                      },
                    ),
                  ),
                ),
                _buildInputBar(context, controller),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar(
    BuildContext context,
    TextEditingController controller,
  ) {
    // 显示内容和实际插入内容分开
    final displaySymbols = ['#', '-', '`', '*', 'Tab'];
    final insertSymbols = ['#', '-', '`', '*', '    '];
    return Row(
      children: [
        for (int i = 0; i < displaySymbols.length; i++)
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final txt = insertSymbols[i];
                final text = controller.text;
                final selection = controller.selection;
                final start = selection.start;
                final end = selection.end;
                final newText = text.replaceRange(start, end, txt);
                controller.text = newText;
                final newOffset = start + txt.length;
                controller.selection = TextSelection.collapsed(
                  offset: newOffset,
                );
              },
              style: AppTheme.secondaryElevatedButtonStyle,
              child: Text(displaySymbols[i]),
            ),
          ),
      ],
    );
  }

  // 文件保存相关
  Future<bool> save(BuildContext context) {
    if (local != null) {
      return local!.parent
          .create(recursive: true)
          .then((_) => local!.writeAsString(MdNode.mdCode(ast)))
          // ignore: use_build_context_synchronously
          .then((_) => _saveSucceeded(context))
          // ignore: use_build_context_synchronously
          .catchError((e) => _saveFailed(context, e as Exception));
    } else {
      return _saveAs(context);
    }
  }

  static const _emptyError = '文件名不能为空';
  static const _repeatError = '文件名重复';
  static const _ok = '请输入文件名';
  Future<bool> _saveAs(BuildContext context) async {
    final controller = TextEditingController(text: localTitle.trim());
    bool nameRepeat = Config.checkRepeatName(localTitle);
    bool canDispose = false; // onchange时会反复触发onDispose
    String getLabelText() => controller.text.isEmpty
        ? _emptyError
        : (nameRepeat ? _repeatError : _ok);
    // 为true时可用
    final labelNotifier = ValueNotifier<String>(getLabelText());
    controller.addListener(() {
      final text = controller.text.trim();
      nameRepeat = Config.checkRepeatName(text);
      labelNotifier.value = getLabelText();
    });
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('保存到本地'),
          content: ValueListenableBuilder<String>(
            valueListenable: labelNotifier,
            builder: (context, labelText, child) {
              final Color labelColor = switch (labelText) {
                _emptyError => Colors.red,
                _repeatError => Colors.red,
                _ => Colors.green,
              };
              return TempTextArea(
                controller: controller,
                decoration: InputDecoration(
                  hintText: _ok,
                  labelText: labelText,
                  labelStyle: TextStyle(color: labelColor),
                ),
                expands: false,
                maxLines: 1,
                onDispose: () {
                  if (canDispose) {
                    controller.dispose();
                    labelNotifier.dispose();
                  }
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isEmpty || nameRepeat) {
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    style: ToastificationStyle.flatColored,
                    title: Text(labelNotifier.value),
                    alignment: Alignment.topCenter,
                    autoCloseDuration: const Duration(seconds: 3),
                    borderRadius: BorderRadius.circular(12.0),
                    showProgressBar: false,
                    dragToClose: true,
                    applyBlurEffect: false,
                  );
                } else {
                  Navigator.of(context).pop(controller.text.trim());
                  canDispose = true;
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
    if (result == null) return false;
    try {
      final savedContent = MdNode.mdCode(ast);
      final newFile = await FileUtils.writeText(
        '${Config.localScorePath}/$result.md',
        savedContent,
        false,
      );
      Config.addLocalScore(newFile);
      if (!context.mounted) return true;
      setState(() {
        localTitle = result;
        _lastSaved = savedContent;
        local = newFile;
      });
      return _saveSucceeded(context);
    } catch (e) {
      // ignore: use_build_context_synchronously
      return _saveFailed(context, e as Exception);
    }
  }

  bool _saveFailed(BuildContext context, Exception e) {
    if (!context.mounted) return false;
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      title: const Text('保存失败'),
      description: Text(e.toString()),
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 3),
      borderRadius: BorderRadius.circular(12.0),
      showProgressBar: true,
      dragToClose: true,
      applyBlurEffect: true,
    );
    return false;
  }

  bool _saveSucceeded(BuildContext context) {
    if (!context.mounted) return true;
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      title: const Text('保存成功'),
      description: Text('已保存到 ${local!.path}'),
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 3),
      borderRadius: BorderRadius.circular(12.0),
      showProgressBar: true,
      dragToClose: true,
      applyBlurEffect: false,
    );
    return true;
  }
}

class TempTextArea extends StatefulWidget {
  final TextEditingController controller;
  final bool expands;
  final int? maxLines;
  final InputDecoration? decoration;
  final void Function() onDispose;
  const TempTextArea({
    super.key,
    required this.controller,
    required this.onDispose,
    this.expands = true,
    this.maxLines,
    this.decoration,
  });

  @override
  State<TempTextArea> createState() => _TempTextAreaState();
}

class _TempTextAreaState extends State<TempTextArea> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: Theme.of(context).textTheme.bodyMedium,
      controller: widget.controller,
      decoration: widget.decoration,
      maxLines: widget.maxLines,
      expands: widget.expands,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
    );
  }
}

const _template = '''# 曲谱标题

![封面](assets/icon.png)

## 歌曲信息

- 作词：【点击图片并长按可以更改】
- 作曲：【长按文本即可编辑】
- 编曲：【右上角有编辑markdown的入口】
- 歌手：【最后点击爱心保存本地】
- 附注：TV动画《XXX》片头曲

## 谱
```
(7)#126#4#43#4
3#463#12#1#1(7)(#4)
```

扒谱：是谁呢
''';

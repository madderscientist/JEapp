import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'branch.dart';
import 'leaf.dart' as leaf;
import 'mdstyle.dart';
import 'builder.dart';
import 'panel.dart';
import '../utils/image.dart';
import 'package:flutter/services.dart';

/// p h1 h2 h3 h4 h5 h6 th td
class MdInlineWidget extends StatefulWidget {
  final MdTree ast;
  final TextStyle style;
  const MdInlineWidget({super.key, required this.ast, required this.style});
  @override
  State<MdInlineWidget> createState() => _MdInlineWidgetState();
}

class _MdInlineWidgetState extends State<MdInlineWidget> {
  final List<MdInline> _children = [];
  final Map<MdInline, TapGestureRecognizer> _recognizers = {};

  @override
  void initState() {
    super.initState();
    _getChild();
  }

  @override
  void dispose() {
    _clearAction();
    super.dispose();
  }

  void _clearAction() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _getChild() {
    _children.clear();
    for (final child in widget.ast.children) {
      if (child is MdInline) {
        _children.add(child as MdInline);
        if (child is Link) {
          _recognizers[child] = child.action(context);
        }
      }
    }
  }

  void _fromMarkdown(String markdown) {
    if (!context.mounted) return;
    setState(() {
      _clearAction();
      widget.ast.children.clear();
      widget.ast.children.addAll(parseInline(markdown));
      _getChild();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> children = [];
    for (final child in _children) {
      children.add(child.build(context, recognizer: _recognizers[child]));
    }
    final richtext = GestureDetector(
      onLongPress: () async {
        HapticFeedback.lightImpact();
        String? text = await _showPanel(context, widget.ast.content);
        if (text != null) {
          _fromMarkdown(text);
        }
      },
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.merge(widget.style),
          children: children,
        ),
      ),
    );
    // 调试模式下显示边框
    if (kDebugMode) {
      return Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.pinkAccent)),
        child: richtext,
      );
    }
    return richtext;
    // 暂时没写编辑
  }
}

class MdH extends MdInlineWidget {
  final int level;
  MdH(this.level, {required super.ast, super.key})
    : super(
        style: TextStyle(
          fontSize: MdStyle.hFontSize[level - 1],
          fontWeight: FontWeight.bold,
        ),
      );
}

class MdP extends MdInlineWidget {
  const MdP({required super.ast, super.key})
    : super(style: const TextStyle(fontSize: 16));
}

class MdCode extends StatefulWidget {
  final CodeBlock ast;
  const MdCode({super.key, required this.ast});
  @override
  State<MdCode> createState() => _MdCodeState();
}

class _MdCodeState extends State<MdCode> {
  void _fromRaw(String raw) {
    setState(() {
      widget.ast.clear();
      widget.ast.addText(raw);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () async {
        String? text = await _showPanel(context, widget.ast.content);
        if (text != null) {
          _fromRaw(text);
        }
      },
      child: Container(
        margin: MdStyle.codeblock['margin'] as EdgeInsets,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: MdStyle.codeblock['padding'] as EdgeInsets, // 你想要的左右margin
            child: Text(
              widget.ast.content,
              style: MdStyle.codeblock['fontStyle'] as TextStyle,
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> _showPanel(BuildContext context, String init) {
  final controller = TextEditingController(text: init);
  final ValueNotifier<(String, String)> extremeNotes = ValueNotifier(('', ''));
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      const padding = EdgeInsets.symmetric(horizontal: 6);
      return SafeArea(
        // 保证跳过底部状态栏
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    child: ValueListenableBuilder<(String, String)>(
                      valueListenable: extremeNotes,
                      // ignore: non_constant_identifier_names
                      builder: (context, low_high, child) {
                        return Text(
                          '最低音 ${low_high.$1}  最高音 ${low_high.$2}',
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    tooltip: '确认',
                    onPressed: () {
                      Navigator.of(sheetContext).pop(controller.text);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: padding,
                child: Panel(
                  controller: controller,
                  extremeNotes: extremeNotes,
                  onDispose: () {
                    controller.dispose();
                    extremeNotes.dispose();
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class MdImageWidget extends StatefulWidget {
  final leaf.Image ast;
  const MdImageWidget({super.key, required this.ast});

  @override
  State<MdImageWidget> createState() => _MdImageWidgetState();
}

class _MdImageWidgetState extends State<MdImageWidget> {
  late final ValueNotifier<ImageProvider> imageProviderNotifier;
  late final String herotag;

  @override
  void initState() {
    super.initState();
    imageProviderNotifier = ValueNotifier<ImageProvider>(
      ImageUtils.getImageProvider(widget.ast.src),
    );
    herotag = UniqueKey().toString();
  }

  @override
  void dispose() {
    imageProviderNotifier.dispose();
    super.dispose();
  }

  void _updateSrc(String src) {
    widget.ast.src = src;
    imageProviderNotifier.value = ImageUtils.getImageProvider(src);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              // src: widget.ast.src, 传了provider就不需要src了
              src: '',
              imageProviderNotifier: imageProviderNotifier,
              herotag: herotag,
              onChange: _updateSrc,
            ),
          ),
        );
      },
      child: Hero(
        tag: herotag,
        child: ValueListenableBuilder<ImageProvider>(
          valueListenable: imageProviderNotifier,
          builder: (context, imageProvider, _) {
            return Image(
              image: imageProvider,
              width: widget.ast.w,
              height: widget.ast.h,
              gaplessPlayback: true,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: widget.ast.w ?? MdStyle.imageLoadingSize,
                        height: widget.ast.h ?? MdStyle.imageLoadingSize,
                        child: const CircularProgressIndicator(),
                      ),
                      if (widget.ast.alt != null && widget.ast.alt!.isNotEmpty)
                        Text(widget.ast.alt!),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

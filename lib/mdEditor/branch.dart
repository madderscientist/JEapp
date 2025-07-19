import 'package:flutter/material.dart';
import 'definition.dart';
import 'mdstyle.dart';
import 'editable_mdwidget.dart';
import 'package:flutter/foundation.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter/gestures.dart';
import 'leaf.dart' as leaf;
import '../utils/action.dart';
import 'context.dart';

/// 其他标签
class Common extends MdTree implements MdBlock {
  @override
  Widget build(BuildContext context) {
    return commonBuild(context, children, false);
  }

  /// 用于处理<li>这种里面可以没<p>直接写inline的情况
  static Widget commonBuild(
    BuildContext context,
    List<MdNode> children, [
    bool autoText = false,
  ]) {
    final List<MdBlock> tree = [];
    // 对于单独的inline节点，使用Paragraph包裹
    for (final child in children) {
      if (child is MdInline) {
        if (!autoText) {
          continue;
        }
        if (tree.isEmpty || tree.last is! Paragraph) {
          tree.add(Paragraph());
        }
        (tree.last as Paragraph).addChild(child);
      } else {
        tree.add(child as MdBlock);
      }
    }
    if (tree.isEmpty) {
      return const SizedBox.shrink();
    }
    if (tree.length == 1) {
      return tree.first.build(context);
    }
    final colum = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tree.length; i++) ...[
          tree[i].build(context),
          if (i < tree.length - 1) SizedBox(height: MdStyle.blockSpacing),
        ],
      ],
    );
    // 调试模式下显示边框
    if (kDebugMode) {
      return Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.lightGreen)),
        child: colum,
      );
    }
    return colum;
  }
}

/// 以下`<hx>`和`<p>`是MdInline的容器
class Header extends Common {
  final int level;
  Header(this.level);

  @override
  String get content => children.map((it) => it.content).join();

  @override
  String markdown([MdContext? context]) => '${'#' * level} ${super.markdown(context)}\n';

  @override
  Widget build(BuildContext context) {
    return MdH(level, ast: this);
  }
}

class Paragraph extends Common {
  @override
  String markdown([MdContext? context]) => '${super.markdown(context)}\n\n';

  @override
  String get content => children.map((it) => it.content).join();

  @override
  Widget build(BuildContext context) {
    final p = MdP(ast: this);
    // 仅有一张图片，居中
    if (children.isNotEmpty && children.first is leaf.Image) {
      return Center(child: p);
    }
    return p;
  }
}

/// 以下`<blockquote>`和`<li>`是container，这里视为MdBlock的容器
class BlockQuote extends Common {
  @override
  String markdown([MdContext? context]) {
    final String childRaw = super.markdown(context).trim();
    return '${addLinePrefix(childRaw, '> ', trim: true, skipEmpty: false)}\n\n';
  }

  @override
  Widget build(BuildContext context) {
    final content = super.build(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: MdStyle.blockquote['borderColor'] as Color,
            width: MdStyle.blockquote['borderWidth'] as double,
          ),
        ),
      ),
      padding: MdStyle.blockquote['padding'] as EdgeInsets,
      child: content,
    );
  }
}

class ListItem extends Common {
  @override
  String markdown([MdContext? context]) {
    if (children.isNotEmpty && children.first is Common) {
      if (children.length == 1 && children.first is Paragraph) {
        // 可以当作简单列表处理。如果兄弟列表项是复杂的，所有同级都会变为复杂。这里消除了同级的传染性，更好看一些
        return '${children.first.markdown(context).trim()}\n';
      }
      // 说明是复杂列表
      return '${joinWithBreak(children.map((node) => switch (node) {
        Paragraph() || Header() => ' ' * 4 + node.markdown(context).trim(),
        _ => addLinePrefix(node.markdown(context), ' ' * 4),
      }), 2).trim()}\n\n'; // trim消除了开头的缩进，便于list加上前缀；但也消除了后面的换行，所以要额外加上
    }
    return '${children.map((node) => switch (node) {
      OrderedList() || UnorderedList() => '\n${addLinePrefix(node.markdown(context), ' ' * 4)}\n',
      _ => node.markdown(context),
    }).join().trim()}\n';
  }

  @override
  Widget build(BuildContext context) {
    return Common.commonBuild(context, children, true);
  }
}

/// 以下`<ul>`和`<ol>`的子元素只可能是`<li>`
class UnorderedList extends Common {
  late String prefix = '-'; // 连续的列表（用+和-分隔）不能合并

  void next2([UnorderedList? previous]) {
    prefix = previous?.prefix == '-' ? '+' : '-';
  }

  @override
  String markdown([MdContext? context]) {
    // li处理自己的末尾换行
    return '${children.map((child) => '$prefix ${child.markdown(context)}').join()}\n';
  }

  @override
  Widget build(BuildContext context) {
    final Text show = Text(switch (prefix) {
      '+' => '✿ ',
      _ => '❁ ',
    }, style: MdStyle.listfont);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((child) {
        final itemContent = (child as ListItem).build(context);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(width: 10.0),
            show,
            Expanded(child: itemContent),
          ],
        );
      }).toList(),
    );
  }
}

class OrderedList extends Common {
  @override
  String markdown([MdContext? context]) =>
      '${children.asMap().entries.map((e) => '${e.key + 1}. ${e.value.markdown(context)}').join()}\n';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        final itemContent = (child as ListItem).build(context);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(width: 10.0),
            Text('${index + 1}.', style: MdStyle.listfont),
            const SizedBox(width: 8.0),
            Expanded(child: itemContent),
          ],
        );
      }).toList(),
    );
  }
}

/// 以下子元素只能是`<p>`
class CodeBlock extends Common {
  // <pre><code>表示代码块
  final String language;
  CodeBlock({this.language = ''});
  final _buf = StringBuffer();

  @override
  String get content => _buf.toString().trim();

  @override
  String markdown([MdContext? _]) {
    final text = content;
    final fence = findFence(text, '```');
    return '$fence$language\n$text\n$fence\n';
  }

  @override
  Widget build(BuildContext context) {
    return MdCode(ast: this);
  }

  @override
  void addText(String text) {
    _buf.write(text);
  }

  void clear() {
    _buf.clear();
  }
}

class CodeInline extends MdTree implements MdInline {
  final _buf = StringBuffer();

  @override
  String markdown([MdContext? _]) {
    final text = _buf.toString();
    final fence = findFence(text, '`');
    return '$fence$text$fence';
  }

  // 作为行内元素，content和markdown保持一致，因为要和text区分

  @override
  InlineSpan build(BuildContext context, {TapGestureRecognizer? recognizer}) {
    final space = MdStyle.codeinline['space'] as TextSpan;
    return TextSpan(
      style: MdStyle.codeinline['fontStyle'] as TextStyle,
      children: [
        space,
        TextSpan(
          text: _buf.toString(),
          recognizer: recognizer,
        ),
        space,
      ],
    );
  }

  @override
  void addText(String text) {
    _buf.write(text);
  }
}

class HorizontalRule extends MdNode implements MdBlock {
  @override
  String markdown([MdContext? _]) => '***\n';

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: Colors.grey,
      thickness: 1.2,
      height: 3.0,
      indent: 10,
      endIndent: 10,
    );
  }
}

/// 以下也是inline的容器，但本身也是inline
class Emphasis extends MdTree implements MdInline {
  @override
  String markdown([MdContext? context]) => '*${super.markdown(context)}*';

  @override
  String get content => children.map((it) => it.content).join();

  @override
  InlineSpan build(BuildContext context, {TapGestureRecognizer? recognizer}) {
    return TextSpan(
      children: getInlineChildren(children, context, recognizer: recognizer),
      style: MdStyle.em,
      recognizer: recognizer,
    );
  }
}

class Strong extends MdTree implements MdInline {
  @override
  String markdown([MdContext? context]) => '**${super.markdown(context)}**';

  @override
  String get content => '**${children.map((it) => it.content).join()}**';

  @override
  InlineSpan build(BuildContext context, {TapGestureRecognizer? recognizer}) {
    return TextSpan(
      children: getInlineChildren(children, context, recognizer: recognizer),
      style: MdStyle.strong,
      recognizer: recognizer,
    );
  }
}

class Deletion extends MdTree implements MdInline {
  @override
  String markdown([MdContext? context]) => '~~${super.markdown(context)}~~';

  @override
  String get content => '~~${children.map((it) => it.content).join()}~~';

  @override
  InlineSpan build(BuildContext context, {TapGestureRecognizer? recognizer}) {
    return TextSpan(
      children: getInlineChildren(children, context, recognizer: recognizer),
      style: const TextStyle(decoration: TextDecoration.lineThrough),
      recognizer: recognizer,
    );
  }
}

class Link extends MdTree implements MdInline {
  // link的方括号内只能有行内元素
  String href;
  String? title;

  Link({this.href = '', this.title});

  @override
  String markdown([MdContext? context]) {
    final alt = super.markdown(context);
    final inBrackets = '$href${title != null ? ' "$title"' : ''}';
    if ((context == null) ||
        (!context.autoRef && context.inlineLinks) ||
        (context.autoRef && inBrackets.length < 512)) {
      return '[$alt]($inBrackets)';
    }
    final id = context.nextId();
    context.ref[id] = inBrackets;
    return '[$alt][$id]';
  }

  @override
  String get content {
    final alt = children.map((it) => it.content).join();
    return '[$alt]($href${title != null ? ' "$title"' : ''})';
  }

  @override
  InlineSpan build(BuildContext context, {TapGestureRecognizer? recognizer}) {
    final List<InlineSpan> alt = getInlineChildren(children, context, recognizer: recognizer);
    return TextSpan(
      text: alt.isEmpty ? href : null,
      children: alt.isEmpty ? null : alt,
      style: MdStyle.link,
      recognizer: recognizer
    );
  }

  // recognizer在父元素中管理，见MdInlineWidget
  TapGestureRecognizer action(BuildContext context) =>
      TapGestureRecognizer()
        ..onTap = () async {
          try {
            await launchUrlWrap(href);
          } catch (e) {
            if (!context.mounted) return;
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.flat,
              title: Text("无法打开链接"),
              description: Text("请检查链接地址/网络连接/应用权限"),
              alignment: Alignment.bottomCenter,
              autoCloseDuration: const Duration(seconds: 3),
              borderRadius: BorderRadius.circular(12.0),
              showProgressBar: true,
              dragToClose: true,
              applyBlurEffect: true,
            );
          }
        };
}

// 表格未实现
// sub和sup未实现
// 公式未实现

List<InlineSpan> getInlineChildren(
  List<MdNode> children,
  BuildContext context, {
  TapGestureRecognizer? recognizer,
}) {
  final List<InlineSpan> inlineChildren = [];
  for (final child in children) {
    if (child is MdInline) {
      inlineChildren.add((child as MdInline).build(context, recognizer: recognizer));
    } else {
      // 当纯文本节点处理
      inlineChildren.add(TextSpan(text: child.markdown(null), recognizer: recognizer));
    }
  }
  return inlineChildren;
}

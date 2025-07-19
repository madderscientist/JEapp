import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'leaf.dart' as leaf;
import 'branch.dart' as branch;
import 'context.dart';

/// |  type  |              MdInline             |     MdBlock    |
/// | ------ | --------------------------------- | -------------- |
/// | MdNode |         Text, Break, Image        | HorizontalRule |
/// | MdTree | CodeInline, Em, Strong, Del, Link | Head, Paragraph, BlockQuote, List, ListItem, CodeBlock |

// 借鉴了https://github.com/f3ath/marker

/// 下面是视图上的接口，用implements ///
abstract class MdInline {
  // BuildContext 是为了image的页面跳转
  // TapGestureRecognizer 是为了传染式处理link子元素的可点击性
  InlineSpan build(BuildContext context, {TapGestureRecognizer? recognizer});
}

abstract class MdBlock {
  Widget build(BuildContext context);
}

/// 下面两个是AST的结构，用extends ///
/// 可以变为markdown的；无子节点的<叶子>
abstract class MdNode {
  /// AST -> markdown code, eg. br->'<br>'
  String markdown([MdContext? context]);

  /// AST -> text preview (in editor), eg. br->'\n'，text keeps linebreak. 要和md.inline解析方式一致
  String get content => markdown(null);

  /// 原始的markdown代码，trim是因为换行用于衔接其他块
  static String mdCode(MdNode node) {
    final ctx = MdContext(autoRef: true);
    String mdcode = node.markdown(ctx).trim();
    String ref = ctx.references();
    if (ref.isEmpty) return mdcode;
    return '$mdcode\n\n$ref';
  }
}

/// 有子节点的<枝干>
class MdTree extends MdNode {
  final List<MdNode> children = [];

  @override
  String markdown([MdContext? context]) =>
      children.map((it) => it.markdown(context)).join();

  // 不重载content，因为content仅有承载inline的元素才用，其余的和markdown一致

  // 下面两个add都是从htmlAST转过来用的，Text会删除\n，不适用于inlineAST转换
  void addText(String text) {
    final t = leaf.Text(text);
    if (t.text.isEmpty) return;
    children.add(t);
  }

  void addChild(MdNode node) {
    if (node is branch.UnorderedList &&
        children.isNotEmpty &&
        children.last is branch.UnorderedList) {
      node.next2(children.last as branch.UnorderedList);
    }
    children.add(node);
  }
}

/// tools ///
const _splitter = LineSplitter();
String addLinePrefix(
  String text,
  String prefix, {
  bool trim = false,
  bool skipEmpty = true,
}) {
  var result = _splitter
      .convert(text)
      .map((it) => it.isEmpty && skipEmpty ? it : prefix + it);
  if (trim) {
    result = result.map((it) => it.trim());
  }
  return result.join('\n');
}

/// 对于code，找到合适的"```"
String findFence(String text, String block) {
  var fence = '';
  do {
    fence += block;
  } while (text.contains(fence));
  return fence;
}

final _beginEndBreak = RegExp(r'^\n+|\n+$');
String joinWithBreak(Iterable<String> lines, int breakCount) {
  if (lines.isEmpty) return '';
  final breaks = '\n' * breakCount;
  final buffer = StringBuffer();
  for (final line in lines) {
    buffer.write(line.replaceAll(_beginEndBreak, ''));
    buffer.write(breaks);
  }
  return buffer.toString();
}

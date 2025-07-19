import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart';
import 'definition.dart';
import 'package:flutter/gestures.dart';
import 'context.dart';
import 'editable_mdwidget.dart';

abstract class MdSpan extends MdNode implements MdInline {}

class Text extends MdSpan {
  late String text;

  Text(String text) {
    // 从AST获取的text带有一些结构信息，需要删除
    // 解析后的换行应该都被处理为<br>，所以解析后的不能有换行
    this.text = text.replaceAll('\n', '');
  }

  static final _header = RegExp(r'^#');
  static final _orderedListItem = RegExp(r'^(\d+)\. ');
  static final _specialChars = RegExp(r'[*_~|\[\]]');
  static final _unorderedListItem = RegExp(r'^[+-] ');

  @override
  String markdown([MdContext? _]) => text
      // dot after a number in the beginning of the string is a list item
      .replaceAllMapped(_orderedListItem, (m) => '${m[1]}\\. ')
      // Special markdown chars: emphasis, strikethrough, table cell, links
      .replaceAllMapped(_specialChars, (m) => '\\${m[0]}')
      // + and - in the beginning of the string is a list item
      .replaceAllMapped(_unorderedListItem, (m) => '\\${m[0]}')
      // # in the beginning of the string is a header
      .replaceAllMapped(_header, (m) => '\\${m[0]}');

  @override
  String get content => text;

  @override
  m.InlineSpan build(
    m.BuildContext context, {
    TapGestureRecognizer? recognizer,
  }) {
    return m.TextSpan(text: content, recognizer: recognizer);
  }
}

class Break extends MdSpan {
  @override
  String markdown([MdContext? context]) => '<br>';

  @override
  String get content => '\n';

  @override
  m.InlineSpan build(
    m.BuildContext context, {
    TapGestureRecognizer? recognizer,
  }) {
    return m.TextSpan(text: content);
  }
}

/// <img> & attributes: {src: a.jpg, alt: } 图片（如果是单独成行会被<p>包围；方括号里是raw，无子）
class Image extends MdSpan {
  String src;
  double? w;
  double? h;
  String? alt;

  Image(this.src, {this.w, this.h, this.alt});

  @override
  String markdown([MdContext? context]) {
    if ((context == null) || // 默认使用inline
        (!context.autoRef && context.inlineImages) || // 不自动时明确使用inline
        (context.autoRef && src.length < 512)) // 自动时src短
    {
      return '![$alt]($src)';
    }
    final id = context.nextId();
    context.ref[id] = src;
    return '![$alt][$id]';
  }

  @override
  m.InlineSpan build(
    m.BuildContext context, {
    TapGestureRecognizer? recognizer,
  }) {
    return m.WidgetSpan(
      alignment: m.PlaceholderAlignment.middle,
      child: MdImageWidget(
        // 很关键。不然通过长按修炼了src后图片不会更新
        key: ValueKey(src + hashCode.toString()),
        ast: this
      ),
    );
  }
}

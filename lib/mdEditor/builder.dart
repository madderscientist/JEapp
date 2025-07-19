import 'package:html/dom.dart' as html_dom;
import 'package:markdown/markdown.dart' as md;
import 'package:html/parser.dart' as html_parser;
import 'definition.dart';
import 'branch.dart' as branch;
import 'leaf.dart' as leaf;

export 'definition.dart';

/// 处理Markdown中的html换行符
class BrSyntax extends md.InlineSyntax {
  BrSyntax() : super(r'(?:<br\s*/?>|\\\n)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty('br'));
    return true;
  }
}

branch.Common fromMarkdown(String markdown) {
  // 处理内联html非常粗暴：先变为html，再解析html。所以不用BrSyntax
  // 如果是空字符串，则返回一个children为[]的branch.Common
  final html = md.markdownToHtml(
    markdown,
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
  final htmlAst = html_parser.parse(html);
  final visitor = _HtmlVisitor();
  return visitor.convert(htmlAst.body!);
}

class _HtmlVisitor {
  final List<MdTree> _stack = [];
  MdTree get _current => _stack.last;

  branch.Common convert(html_dom.Element body) {
    final root = branch.Common();
    _stack.add(root);

    for (final node in body.nodes) {
      _visit(node);
    }

    return root;
  }

  void _visit(html_dom.Node node) {
    if (node is html_dom.Text) {
      _current.addText(node.text);
      return;
    }

    if (node is html_dom.Element) {
      late MdTree newNode;
      switch (node.localName) {
        // 以下为MdTree
        case 'h1':
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
          newNode = branch.Header(int.parse(node.localName!.substring(1)));
          break;
        case 'p':
          newNode = branch.Paragraph();
          break;
        case 'blockquote':
          newNode = branch.BlockQuote();
          break;
        case 'ul':
          newNode = branch.UnorderedList();
          // 对prefix的处理在addChild中进行
          break;
        case 'ol':
          newNode = branch.OrderedList();
          break;
        case 'li':
          newNode = branch.ListItem();
          break;
        case 'strong':
        case 'b':
          newNode = branch.Strong();
          break;
        case 'em':
        case 'i':
          newNode = branch.Emphasis();
          break;
        case 'del':
        case 's':
          newNode = branch.Deletion();
          break;
        case 'a':
          newNode = branch.Link(
            href: node.attributes['href'] ?? '',
            title: node.attributes['title'],
          );
          break;
        // 将<pre><code>合并为一个CodeBlock
        case 'pre':
          // 尝试找到内部的 <code> 元素
          final codeElement =
              node.children.isNotEmpty &&
                  node.children.first.localName == 'code'
              ? node.children.first
              : null;

          final langClass = codeElement?.attributes['class'] ?? '';
          const langPrefix = 'language-';
          newNode = branch.CodeBlock(
            language: langClass.startsWith(langPrefix)
                ? langClass.substring(langPrefix.length)
                : '',
          );
          // 如果有<code>元素，用它的文本；否则用<pre>自己的文本
          newNode.addText(codeElement?.text ?? node.text);
          _current.addChild(newNode);
          return;
        case 'code': // Inline code
          newNode = branch.CodeInline();
          break;
        // 以下为MdNode，直接插入且不考虑其子节点。Text有专门的函数。这里和Text一样处理
        case 'img':
          _current.addChild(
            leaf.Image(
              node.attributes['src'] ?? '',
              alt: node.attributes['alt'],
            ),
          );
          return;
        case 'br':
          _current.addChild(leaf.Break());
          return;
        case 'hr':
          _current.addChild(branch.HorizontalRule());
          return;
        // 其他标签使用通用容器
        default:
          newNode = branch.Common();
          break;
      }

      _stack.add(newNode);
      for (final child in node.nodes) {
        _visit(child);
      }
      _stack.removeLast();
      _current.addChild(newNode);
    }
  }
}

final document = md.Document(
  extensionSet: md.ExtensionSet.gitHubFlavored,
  inlineSyntaxes: [BrSyntax()], // 不能加md.InlineHtmlSyntax()
  encodeHtml: false,
);

Iterable<MdNode> parseInline(String textInView) {
  textInView = textInView.replaceAll('\n', '<br>');
  final parser = md.InlineParser(textInView, document);
  List<md.Node> nodes = parser.parse();
  final visitor = _MdInlineVisitor();
  for (final node in nodes) {
    node.accept(visitor);
  }
  return visitor.root.children;
}

/// 遍历AST的类 专注于inlineAST解析 ///
class _MdInlineVisitor extends md.NodeVisitor {
  final List<MdTree> _stack = [branch.Common()];
  MdTree get root => _stack.last;

  @override
  bool visitElementBefore(md.Element element) {
    late MdTree newNode;
    switch (element.tag) {
      case 'em':
        newNode = branch.Emphasis();
        break;
      case 'strong':
        newNode = branch.Strong();
        break;
      case 'del':
        newNode = branch.Deletion();
        break;
      case 'a':
        newNode = branch.Link(
          href: element.attributes['href'] ?? '',
          title: element.attributes['title'],
        );
        break;
      case 'code':
        newNode = branch.CodeInline();
        break;
      // 以下为MdNode，直接插入且不考虑其子节点。Text有专门的函数。这里和Text一样处理
      case 'img':
        root.addChild(
          leaf.Image(
            element.attributes['src'] ?? '',
            alt: element.attributes['alt'],
          ),
        );
        return false;
      case 'br':
        root.addChild(leaf.Break());
        return false;
      // 其他标签都是Block，不管
      default:
        return false;
    }
    _stack.add(newNode);
    return true;
  }

  @override
  void visitText(md.Text text) {
    root.addText(text.text);
  }

  @override
  void visitElementAfter(md.Element element) {
    final MdNode last = _stack.last;
    _stack.removeLast();
    root.addChild(last);
  }
}

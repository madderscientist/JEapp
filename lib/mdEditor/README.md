# Markdown 查看、编辑器

## 目标与基本实现思路
1. 查看markdown：基于`dart:markdown`库，将文本解析为语法树，再定义渲染widget
2. 修改内容：不支持修改结构，但支持修改内容（转调需求），呼出方式是长按：
    1. 段落：可编辑markdown，比如用加粗、倾斜、段内代码块等。实际实现时，段落是所有inline元素的载体，所以段落可编辑意味着文字都可编辑（代码块除外）。
    2. 代码块（本应用中即为曲谱）：可编辑raw的内容。代码块是另一类承载文字的载体。

    如果要修改结构，可提供markdown原代码修改，不打算设计可视化编辑界面（毕竟只是个看谱工具）
3. 导出源码：用于本地保存，模仿了`dart:marker`库的做法，即创建自己的AST，不同tag对应不同类型的节点，每类节点有自己的导出方法。

综合以上，基本思路是：先解析为语法树，再转化为我自己的AST和Node，每类节点不仅可以导出md源码，还对应一种widget的构造，widget保存了自己的Node，并负责修改任务。上述结构可以参考[procedure.drawio](./procedure.drawio)。

## 基本概念
### inline元素
以下是inline元素：
- `md.Text` 正常文本
- `<strong>` 粗体
- `<em>` 斜体
- `<code>` 代码块（如果包裹在pre里面，且仅有code一个child，则为代码块）
- `<img> & attributes: {src: a.jpg, alt: inlineText}` 图片

inline不可能单独作为block出现，这些块内会有inline:
- `<p>`
- `<hx>`
- `<li>`: 需要特别说明的是，`<li>`有两种模式，紧凑模式下inline元素不会被`<p>`包裹，html为``<li>c*o*n`t`e**n**t</li>``，和`<hx>` `<p>`的行为一致；但`<li>`本身是container，可以包裹其他的block，一旦某个`<li>`中有block，则所有`<li>`的inline都会被`<p>`包裹，即``<li><p>c*o*n`t`e**n**t</p></li>``。实际显示的时候，不管是不是紧凑列表，都要合并li内的inline元素，视为`<p>`处理。这个逻辑在`branch.dart::Common::commonBuild`中实现。
- `<th>`
- `<td>`

### 叶子块 (Leaf Blocks)
不能包含其他块级元素，它们是内容的终点。
- 段落 `<p>`
- 标题 `<h1> - <h6>`
- 代码块 `<pre>`
- 水平分割线 `<hr>`
- `<th>`
- `<td>`

### 容器块 (Container Blocks)
可以包含其他块级元素（包括叶子块和其他容器块）。
- 引用块 `<blockquote>`
- 列表项 `<li>`


## HTML的解析
为了兼顾内嵌的html（我个人还挺常用的），决定先将md解析为html，再解析为html语法树。然而转换为html会带来一些问题：

有如下markdown代码：
```
1
\
2

3
```
显示结果：

***
1
\
2

3
***

mdAST（使用codeUnits是为了展示换行`\n = char(10)`）:
```
<document> & attributes: {}
  <p> & attributes: {}
    Text: 1
, codeUnits: [49, 10]
    <br> & attributes: {}
    Text: 2, codeUnits: [50]
  <p> & attributes: {}
    Text: 3, codeUnits: [51]
```

html:
```html
<p>1
<br />
2</p>
<p>3</p>
```

htmlAST:
```
- Element: <body>
  - Element: <p>
    - Text: "[49, 10]"
    - Element: <br>
    - Text: "[10, 50]"
  - Text: "[10]"
  - Element: <p>
    - Text: "[51]"
  - Text: "[10]"
```

在mdAST中，`1`后面多了个`\n`；解析为htmlAST后，不光`2`前面多了一个`\n`，还有很多因为格式美观而产生的`\n`。所以Text首尾的换行都不能留。更进一步，所有换行都不能留。这个处理是模仿html中对空格和换行的显示，虽然有些粗暴了。


## 编辑区格式
段内换行本应由 `LineBrak` 承担，但其markdown语法比较丑陋(`\+换行`)，所以编辑区将`LineBrak`语法用更符合认知的`\n`替代，为此加入了`content`属性，对于`LineBrak`，返回的就是`\n`，区分于markdown返回的`\\\n`；但markdown的换行语法`\\\n`限制太大，比如不能用于标题的换行，所以生成的源码一律改为用`<br>`。段内解析时一切换行都要保证解析为`<br>`，具体做法是将`\n`替换为`<br>`再解析，为此增加了`dart:markdown::inline`的`<br>`的解析器。
import 'package:flutter/material.dart';
import '../config.dart';
import 'builder.dart';
import '../theme.dart';

final String raw = '''

# Brainiac<br>Maniac

![pvz](http://p2.music.126.net/8ZScS5RBR1ibMCYDr-YYdw==/109951167480957763.jpg?param=130y130)

## Info
- **作词** : Laura Shigihara
- **作曲** : [](https://music.163.com/#/artist?id=65977)
+ **专辑** : Plants Vs. Zombies (Original Video Game Soundtrack)
+ **链接** : [网易`云`音乐:*Brainiac Maniac*](https://music.163.com/#/song?id=3019756)
    - *子*列表
    - # 子列表中的标题

## Score

```dart
void main() {
  print('Hello hello hello hello hello hello, world!');
}
```

> This is a blockquote.
>
> > This is a nested blockquote.

<hr />

This is a `paragraph` with **bold text**, *italic text*, and ~~strikethrough~~; `here is a long long long span`.
''';
final mdTree = fromMarkdown(raw);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Config.init(); // 初始化配置
  runApp(
    MaterialApp(
      theme: AppTheme.defaultTheme,
      home: Scaffold(
        appBar: AppBar(title: Text('Markdown Editor Test')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 6.0),
            child: Builder(
              builder: (context) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      mdTree.build(context),
                      Text(MdNode.mdCode(mdTree)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

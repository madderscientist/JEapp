import 'package:flutter/material.dart';

class MdStyle {
  MdStyle._();

  static const em = TextStyle(fontStyle: FontStyle.italic);
  static const strong = TextStyle(fontWeight: FontWeight.bold);
  static const link = TextStyle(
    color: Colors.blue,
    decoration: TextDecoration.underline,
  );
  static const codeblock = {
    "margin": EdgeInsets.symmetric(horizontal: 2),
    "padding": EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    "fontStyle": TextStyle(
      fontFamily: 'monospace',
      fontWeight: FontWeight.normal,
      color: Colors.black,
    ),
  };
  static const codeinline = {
    "space": TextSpan(
      text: ' ',
      style: TextStyle(fontFamily: 'Roboto'), // 窄字体
    ),
    "fontStyle": TextStyle(
      fontFamily: 'monospace',
      fontWeight: FontWeight.normal,
      color: Colors.deepOrangeAccent,
      backgroundColor: Color(0xFFEEEEEE), // 背景色通过 TextStyle 设置
    ),
  };
  static const listfont = TextStyle(
    fontFamily: 'monospace',
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );
  static const blockquote = {
    'borderColor': Colors.lightBlue,
    'borderWidth': 3.0,
    'padding': EdgeInsets.only(left: 8.0, top: 5.0, bottom: 5.0),
  };
  static const blockSpacing = 6.0;
  static const hFontSize = [
    32.0, // h1
    29.0, // h2
    26.0, // h3
    23.0, // h4
    20.0, // h5
    17.0, // h6
  ];

  static const imageLoadingSize = 24.0;
}

import 'package:flutter/material.dart';
import 'metronome.dart';
import '../theme.dart';

/// 单独可用的节拍器
void main() {
  runApp(MaterialApp(
    title: 'JE节拍器',
    theme: AppTheme.defaultTheme,
    home: Scaffold(
      body: Metronome(),
    ),
  ));
}

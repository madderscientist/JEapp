import 'package:flutter/material.dart';
import 'tuner.dart';
import '../theme.dart';

/// 单独可用的时频分析页面
void main() {
  runApp(MaterialApp(
    title: 'JE时频分析',
    theme: AppTheme.defaultTheme,
    home: Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Tuner()
      ),
    ),
  ));
}

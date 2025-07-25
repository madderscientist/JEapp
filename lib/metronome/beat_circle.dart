import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// 水波纹数据结构
class _Ripple {
  final int startTime;
  final double progress;
  _Ripple(this.startTime, [this.progress = 0]);
  _Ripple copyWithProgress(double p) => _Ripple(startTime, p.clamp(0, 1));
}

typedef BeatChangeCallback = void Function(int delta);

class BeatCircle extends StatefulWidget {
  /// 父元素控制 每次改变的时候开始节拍动画
  final Stream<void> beatStream;

  /// 父元素控制 是否启用节拍圈
  final ValueNotifier<bool> enable;

  /// 在画布上滑动时触发的回调，参数为变化量
  final BeatChangeCallback? onBeatChange;
  const BeatCircle({
    super.key,
    required this.beatStream,
    required this.enable,
    this.onBeatChange,
  });

  @override
  State<BeatCircle> createState() => _BeatCircleState();
}

class _BeatCircleState extends State<BeatCircle>
    with SingleTickerProviderStateMixin {
  late final StreamSubscription _beatSub;
  late final AnimationController _controller;
  late final Animation<double> borderWidthAnim;
  late final Animation<Color?> borderColorAnim;
  static const int risingTime = 75;
  static const int fallingTime = 180;
  static const int rippleDuration = 1500; // ms 水波纹持续时间
  /// _lastAngle为null表示没有按压
  double? _lastAngle;

  /// dropAngle不为null，但distance为null表示液滴不用绘制
  double dropAngle = 0;
  double? dropDistance;
  final List<_Ripple> _ripples = <_Ripple>[];
  late Ticker _rippleTicker;

  @override
  void initState() {
    super.initState();
    // 圆圈动效 分为粗细和颜色
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: risingTime + fallingTime),
    );
    borderWidthAnim = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 5,
          end: 10,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: risingTime / (risingTime + fallingTime),
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 10,
          end: 5,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: fallingTime / (risingTime + fallingTime),
      ),
    ]).animate(_controller);
    borderColorAnim = TweenSequence([
      TweenSequenceItem(
        tween: ColorTween(
          begin: Colors.green,
          end: Colors.lightGreenAccent,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: risingTime / (risingTime + fallingTime),
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: Colors.lightGreenAccent,
          end: Colors.green,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: fallingTime / (risingTime + fallingTime),
      ),
    ]).animate(_controller);
    // 启动水波纹ticker (兼drop松手动效)
    _rippleTicker = Ticker((_) {
      if (mounted && (_ripples.isNotEmpty || dropDistance != null)) setState(() {});
    });
    _rippleTicker.start();
    // 监听节拍事件
    _beatSub = widget.beatStream.listen((_) => _onBeat());
    // 监听enable状态变化
    widget.enable.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _onBeat() {
    if (!mounted) return;
    // 圆圈动效
    _controller.forward(from: 0);
    // 添加水波纹
    _ripples.add(_Ripple(DateTime.now().millisecondsSinceEpoch));
    // 触发重绘
    setState(() {});
  }

  @override
  void dispose() {
    _rippleTicker.dispose();
    _beatSub.cancel();
    _controller.dispose();
    super.dispose();
  }

  static double _clampAngle(double angle) {
    if (angle < -pi) {
      return angle + 2 * pi;
    } else if (angle > pi) {
      return angle - 2 * pi;
    }
    return angle;
  }

  /// 处理手势开始事件
  void _handlePanStart(DragStartDetails details, BoxConstraints constraints) {
    final local = details.localPosition;
    final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    final angle = atan2(local.dy - center.dy, local.dx - center.dx);
    final distance = (local - center).distance;
    setState(() {
      dropAngle = angle;
      _lastAngle = angle;
      dropDistance = distance;
    });
  }

  /// 处理手势滑动事件
  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final local = details.localPosition;
    final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    final angle = atan2(local.dy - center.dy, local.dx - center.dx);
    final distance = (local - center).distance;
    if (_lastAngle == null) {
      _lastAngle = angle;
      dropDistance = distance;
      return;
    }
    double deltaAngle = _clampAngle(angle - _lastAngle!);
    // 每10度触发一次
    const double deltaTheta = pi / 18;
    int steps = (deltaAngle.abs() / deltaTheta).floor();
    if (steps > 0) {
      final int delta = (deltaAngle.sign * steps).toInt();
      widget.onBeatChange?.call(delta);
      _lastAngle = _clampAngle(_lastAngle! + delta * deltaTheta);
    }
    setState(() {
      dropAngle = angle;
      dropDistance = distance;
    });
  }

  /// 处理手势抬起事件
  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      // 表示没有按压
      _lastAngle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color boardColor;
    if (widget.enable.value) {
      boardColor = borderColorAnim.value ?? Colors.green;
    } else {
      boardColor = Colors.red;
    }
    // 清理过期水波纹
    final now = DateTime.now().millisecondsSinceEpoch;
    _ripples.removeWhere((r) => now - r.startTime > rippleDuration);
    return LayoutBuilder(
      // 主要为了constrains而使用LayoutBuilder
      builder: (context, constraints) {
        final minLength = min(constraints.maxWidth, constraints.maxHeight);
        final R = minLength * 0.55 * 0.5;
        return GestureDetector(
          onPanStart: (details) => _handlePanStart(details, constraints),
          onPanUpdate: (details) => _handlePanUpdate(details, constraints),
          onPanEnd: _handlePanEnd,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // 更新每个水波纹的进度
              final now = DateTime.now().millisecondsSinceEpoch;
              final ripples = _ripples
                  .map(
                    (r) => r.copyWithProgress(
                      (now - r.startTime) / rippleDuration,
                    ),
                  )
                  .toList();
              // dropDistance的衰退
              if (_lastAngle == null) {
                if (dropDistance != null) {
                  double shrink = (R - dropDistance!) * 0.2;
                  dropDistance = dropDistance! + shrink;
                  if ((dropDistance! - R).abs() < 1) {
                    dropDistance = null; // 达到圆边界后清除液滴
                  }
                }
              }
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _BeatPainter(
                  borderWidth: borderWidthAnim.value,
                  borderColor: boardColor,
                  dropAngle: dropAngle,
                  dropDistance: dropDistance,
                  R: R,
                  ripples: ripples,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BeatPainter extends CustomPainter {
  final double borderWidth;
  final Color borderColor;
  final double? dropAngle;
  final double? dropDistance;
  final double R;
  final List<_Ripple> ripples;

  _BeatPainter({
    required this.borderWidth,
    required this.borderColor,
    this.dropAngle,
    this.dropDistance,
    required this.R,
    required this.ripples,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = center.distance;
    // 主圆
    canvas.drawCircle(
      center,
      R,
      Paint()
        ..color = borderColor
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke,
    );
    // 多个水波扩散
    for (final ripple in ripples) {
      final rippleProgress = ripple.progress;
      if (rippleProgress > 0 && rippleProgress < 1) {
        final rippleRadius = R + rippleProgress * (maxRadius - R);
        canvas.drawCircle(
          center,
          rippleRadius,
          Paint()
            ..color = borderColor.withAlpha(
              ((1 - rippleProgress) * 255).toInt(),
            )
            ..strokeWidth = 3 * (1 - rippleProgress)
            ..style = PaintingStyle.stroke,
        );
      }
    }
    // 液滴效果
    if (dropDistance != null) {
      double dropWidthAngle = pi / 4; // 液滴张角
      final dis = dropDistance! - R;
      double dropHeight = sqrt(dis.abs()) * dis.sign;
      dropWidthAngle *= (sqrt(dis.abs() / R) - 0.5) + 1; // 根据距离调整张角
      _drawDrop(canvas, center, R, dropAngle!, dropHeight, dropWidthAngle);
    }
  }

  void _drawDrop(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    double dropLength,
    double widthAngle,
  ) {
    // 液滴张角，宽度与圆心夹角相关
    final baseRadius = radius + borderWidth / 2 * dropLength.sign;
    final leftAngle = angle - widthAngle / 2;
    final rightAngle = angle + widthAngle / 2;
    // 波形点数
    const int N = 32;
    final path = Path();
    // 从left到right，绘制cos波形
    for (int i = 0; i <= N; i++) {
      final t = i / N;
      final a = leftAngle + (rightAngle - leftAngle) * t;
      final basePt = Offset(
        center.dx + cos(a) * baseRadius,
        center.dy + sin(a) * baseRadius,
      );
      // cos波形，最大高度为dropLength，正负方向由dropLength符号决定
      final h = (cos(2 * t * pi - pi) + 1) * dropLength;
      final pt = Offset(basePt.dx + cos(angle) * h, basePt.dy + sin(angle) * h);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    // 用圆弧闭合底部
    path.arcTo(
      Rect.fromCircle(center: center, radius: baseRadius),
      rightAngle,
      -(rightAngle - leftAngle),
      false,
    );
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _BeatPainter oldDelegate) => true;
}

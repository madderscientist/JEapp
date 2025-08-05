import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'yin.dart';
import 'nopeak.dart';
import 'latest_array.dart';
import '../theme.dart';
import '../utils/list_notifier.dart';
import '../utils/freq_table.dart';

class TimeFrequency extends StatefulWidget {
  final FreqTable freqTable;
  final ValueNotifier<bool> autoTrackNotifier;
  final ValueNotifier<double>? freqNotifier; // 实时频率
  final ValueNotifier<double>? pitchNotifier; // 稳定后的音高
  final ValueNotifier<double>? normedCenterNotifier;  // 中心音符
  final ValueNotifier<double>? sensitivityNotifier;
  const TimeFrequency({
    super.key,
    required this.freqTable,
    required this.autoTrackNotifier,
    this.freqNotifier,
    this.pitchNotifier,
    this.normedCenterNotifier,
    this.sensitivityNotifier,
  });
  @override
  State<TimeFrequency> createState() => _TimeFrequencyState();
}

class _TimeFrequencyState extends State<TimeFrequency>
    with TickerProviderStateMixin {
  static const int sampleRate = 22050; // 采样率
  final AudioRecorder recorder = AudioRecorder();
  final yin = YIN(frameSize: 2048, sampleRate: sampleRate);

  late LazyNotifier<LatestArray> pitches; // 控制重绘

  double stablePitch = -440;

  DateTime _lastDragEnd = DateTime.now();
  bool _isDragging = false;
  set isDragging(bool value) {
    if (_isDragging == value) return;
    _isDragging = value;
    if (value) {
      _tempController?.dispose();
      _tempController = null;
    } else {
      _lastDragEnd = DateTime.now();
    }
  }

  // 用户拖动结束 1 秒内视为“仍在拖动”
  bool get _userHolding =>
      _isDragging ||
      DateTime.now().difference(_lastDragEnd).inMilliseconds < 800;

  late ValueNotifier<double> viewCenterNormNotifier; // 归一化视野中心
  double get viewCenterNorm => viewCenterNormNotifier.value;
  // 这个setter会联动viewLeft 如果不联动（比如从viewLeft得到）请使用 viewCenterNormNotifier.value = 
  set viewCenterNorm(double value) {
    viewCenterNormNotifier.value = value.clamp(0, widget.freqTable.length - 1);
    _updateViewLeft();
  }

  double _viewLeft = 0;
  double _semiToneWidth = 60;
  set semiToneWidth(double value) {
    _semiToneWidth = value.clamp(w / 36, w2 - 8);
    _updateViewLeft();
    pitches.notify();
  }

  AnimationController? _tempController;
  double w = 2;
  double w2 = 1;
  void _updateViewLeft() {
    _viewLeft = (viewCenterNorm * _semiToneWidth - w2).clamp(
      -w2,
      _canvasWidth - w2,
    );
    viewCenterNormNotifier.value = (_viewLeft + w2) / _semiToneWidth;
  }

  void _animation2Center([double? to, void Function()? onCompleted]) {
    // 动画到对齐
    final nearest = to ?? viewCenterNorm.round();
    _tempController?.dispose();
    _tempController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (500 * (nearest - viewCenterNorm).abs())
            .clamp(100, 500)
            .toInt(),
      ),
      lowerBound: double.negativeInfinity,
      upperBound: double.infinity,
      value: viewCenterNorm,
    );
    _tempController!.addListener(() {
      if (!mounted) return;
      viewCenterNorm = _tempController!.value;
      pitches.notify();
    });
    _tempController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _tempController?.dispose(); // 动画完成后自动销毁
        _tempController = null;
        onCompleted?.call();
      }
    });
    _tempController!.animateTo(nearest.toDouble(), curve: Curves.easeOut);
  }

  @override
  void initState() {
    super.initState();
    pitches = LazyNotifier(LatestArray(120));
    viewCenterNormNotifier =
        widget.normedCenterNotifier ?? ValueNotifier<double>(0);
    viewCenterNorm = _canvasWidth / 2 / _semiToneWidth;
    widget.autoTrackNotifier.addListener(() {
      if (widget.autoTrackNotifier.value) {
        // 处理无数据时
        stablePitch = pitches.value.latest;
        if (stablePitch < 0) stablePitch = viewCenterNorm;
        _animation2Center(stablePitch);
      } else {
        _animation2Center();
      }
    });
    if (widget.sensitivityNotifier != null) {
      setThreshold() =>
          yin.threshold = widget.sensitivityNotifier!.value.clamp(0.01, 0.8);
      widget.sensitivityNotifier!.addListener(setThreshold);
      setThreshold();
    } else {
      yin.threshold = 0.2; // 默认灵敏度
    }
    _init();
  }

  // 更新 freqs
  Future<void> _init() async {
    if (await Permission.microphone.request() != PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('没有麦克风权限，JE酱听不到声音啦www'),
          action: SnackBarAction(label: '去授权', onPressed: openAppSettings),
        ),
      );
    }

    // PCM16 但是数据是 Uint8
    final recordStream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: sampleRate,
        autoGain: false,
        noiseSuppress: true,
      ),
    );

    var audioSampleBufferedStream = _bufferedListStream(
      recordStream.map((event) => event.convertPCM16ToFloat()),
      yin.frameSize,
      yin.frameSize ~/ 3,
    );

    final nopeak = NoPeak(
      dataOutfn: (f) {
        // 按440Hz计算音高 如果以后更改 A4 频率，只需要加上偏移量
        final pitch = musiclog2(f / 440) + FreqTable.A4at;
        widget.pitchNotifier?.value = pitch;
        if (stablePitch < 0) {
          stablePitch = pitch;
        } else {
          stablePitch = stablePitch * 0.95 + pitch * 0.05;
        }
        pitches.value.push(pitch);
        pitches.notify();
      },
    );

    await for (final audioSample in audioSampleBufferedStream) {
      final freq = yin.getPitch(audioSample);
      if (freq > 0) {
        widget.freqNotifier?.value = freq;
        nopeak.input(freq);
      }
    }
  }

  @override
  void dispose() {
    recorder.cancel().whenComplete(() => recorder.dispose());
    pitches.dispose();
    _tempController?.dispose();
    if (widget.normedCenterNotifier == null) {
      viewCenterNormNotifier.dispose();
    }
    super.dispose();
  }

  double get _canvasWidth => widget.freqTable.length * _semiToneWidth;

  static double musiclog2(double f) {
    return 12 * math.log(f) / math.ln2;
  }

  double pitch2Px(double pitch) =>
      _semiToneWidth * (pitch + musiclog2(440 / widget.freqTable.A4));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 尺寸变化时以 _viewCenter 为准重新计算
        w = constraints.maxWidth;
        w2 = w / 2;
        _updateViewLeft();
        double originalWidth = _semiToneWidth;
        return GestureDetector(
          // 改变视野
          onHorizontalDragStart: (details) {
            isDragging = true;
          },
          onHorizontalDragUpdate: (details) {
            _viewLeft = (_viewLeft - details.delta.dx).clamp(
              -w2,
              _canvasWidth - w2,
            );
            viewCenterNormNotifier.value = (_viewLeft + w2) / _semiToneWidth;
            pitches.notify();
          },
          onHorizontalDragEnd: (details) {
            isDragging = false;
            if (widget.autoTrackNotifier.value == false) {
              _animation2Center();
            }
          },
          // 缩放手势 保持中心
          onScaleStart: (details) {
            isDragging = true;
          },
          onScaleUpdate: (details) {
            semiToneWidth = (originalWidth * details.scale);
          },
          onScaleEnd: (detail) {
            originalWidth = _semiToneWidth;
            isDragging = false;
          },
          child: ValueListenableBuilder<LatestArray>(
            valueListenable: pitches,
            builder: (context, latestArray, child) {
              // 自动移动视野 以稳定频率为中心 如果最后一个频率超出则以其为准
              if (_userHolding == false) {
                double p = latestArray.latest;
                if (p < 0)  p = viewCenterNorm;
                final pAt = pitch2Px(p);
                if (widget.autoTrackNotifier.value && _tempController == null) {
                  final centerPx = stablePitch > 0
                      ? pitch2Px(stablePitch)
                      : (_canvasWidth / 2);
                  double viewLeft = centerPx - w2;
                  if (pAt < viewLeft) {
                    viewLeft = pAt - _semiToneWidth / 2;
                  } else if (pAt > viewLeft + w) {
                    viewLeft = pAt - w + _semiToneWidth / 2;
                  }
                  viewLeft = viewLeft.clamp(-w2, _canvasWidth - w2);
                  if (viewLeft != _viewLeft) {
                    _viewLeft = viewLeft;
                    viewCenterNormNotifier.value = (viewLeft + w2) / _semiToneWidth;
                    stablePitch = viewCenterNorm;
                  }
                } else if (!widget.autoTrackNotifier.value) {
                  // 根据当前音高自适应拓展范围
                  if (p != viewCenterNorm) {
                    semiToneWidth = w2 / (viewCenterNorm - p).abs() - 4;
                  }
                }
              }

              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _TimeFrequencyPainter(
                  pitches: latestArray,
                  freqTable: widget.freqTable,
                  viewLeft: _viewLeft,
                  semiToneWidth: _semiToneWidth,
                  lineColor: AppTheme.color,
                  textColor: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TimeFrequencyPainter extends CustomPainter {
  final LatestArray pitches;
  final FreqTable freqTable;
  final double viewLeft;
  final double semiToneWidth;
  final Color lineColor;
  final Color textColor;
  final double fontSize; // 负数说明不要绘制

  _TimeFrequencyPainter({
    required this.pitches,
    required this.freqTable,
    required this.viewLeft,
    required this.semiToneWidth,
    this.lineColor = Colors.blue,
    this.textColor = Colors.black,
    this.fontSize = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int startIndex = (viewLeft / semiToneWidth).floor().clamp(
      0,
      freqTable.length,
    );
    final int endIndex = ((viewLeft + size.width) / semiToneWidth).ceil().clamp(
      0,
      freqTable.length,
    );
    final hY = 2 * fontSize;
    final lY = size.height;

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill
      ..strokeWidth = 1;
    final textStyle = TextStyle(
      color: textColor,
      fontSize: fontSize > 0 ? fontSize : 0,
    );
    double lastNameEnd = -100;
    double lastFreqEnd = -100;
    for (int i = startIndex; i < endIndex; i++) {
      final x = i * semiToneWidth - viewLeft;
      canvas.drawLine(Offset(x, hY), Offset(x, lY), paint);
      if (fontSize > 0) {
        // 顶部绘制音名和频率
        final (nameTextPainter, nameTextAnchor) = calcText(
          '${FreqTable.noteName[i % 12]}${i ~/ 12 + 1}',
          (x, hY),
          ratio: (-0.5, -1),
          style: textStyle,
        );
        double xnameend = x + nameTextPainter.width / 2;
        if (xnameend - lastNameEnd > nameTextPainter.width) {
          lastNameEnd = xnameend;
          nameTextPainter.paint(canvas, nameTextAnchor);
        }
        // 顶部绘制频率
        final (freqTextPainter, freqTextAnchor) = calcText(
          freqTable[i].toStringAsPrecision(4),
          (x, hY),
          ratio: (-0.5, -2),
          style: textStyle,
        );
        double xfreqend = x + freqTextPainter.width / 2;
        if (xfreqend - lastFreqEnd > freqTextPainter.width) {
          lastFreqEnd = xfreqend;
          freqTextPainter.paint(canvas, freqTextAnchor);
        }
      }
    }

    // 绘制频率线 平滑+渐变
    final double step = (lY - hY) / pitches.size();
    final double pitchOffset = _TimeFrequencyState.musiclog2(
      440 / freqTable.A4,
    );
    double y = lY;
    final points = <Offset>[];
    for (final p in pitches.values) {
      final px = semiToneWidth * (p + pitchOffset) - viewLeft;
      points.add(Offset(px, y));
      y -= step;
    }
    if (points.isNotEmpty) {
      final path = _smoothPath(points);
      final gradient = ui.Gradient.linear(points.first, points.last, [
        lineColor.withAlpha(96),
        Colors.blue,
      ]);
      canvas.drawPath(
        path,
        Paint()
          ..shader = gradient
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke,
      );
    }
  }

  /// 把折线点变成平滑三次贝塞尔曲线
  Path _smoothPath(List<Offset> points, {double tension = 0.25}) {
    if (points.isEmpty) return Path();
    final path = Path()..moveTo(points.first.dx, points.first.dy);

    Offset control(Offset p0, Offset p1, Offset p2, double t) => Offset(
      p1.dx + t * (p2.dx - p0.dx) * 0.5,
      p1.dy + t * (p2.dy - p0.dy) * 0.5,
    );

    for (int i = 1; i < points.length - 1; i++) {
      final cp1 = control(points[i - 1], points[i], points[i + 1], tension);
      final cp2 = control(points[i], points[i + 1], points[i + 1], -tension);
      path.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }
    return path;
  }

  (TextPainter, Offset) calcText(
    String text,
    (double, double) anchor, {
    (double, double) ratio = (-0.5, 0),
    TextStyle? style,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(); // 计算尺寸

    // 计算绘制起点：水平居中，顶部对齐
    final offset = Offset(
      anchor.$1 + textPainter.width * ratio.$1,
      anchor.$2 + textPainter.height * ratio.$2,
    );
    return (textPainter, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Stream<List<T>> _bufferedListStream<T>(
  Stream<List<T>> stream,
  int bufferSize,
  int hop,
) async* {
  assert(bufferSize > 0, 'bufferSize must be greater than 0');
  final buffer = <T>[];
  await for (final data in stream) {
    buffer.addAll(data);
    while (buffer.length >= bufferSize) {
      yield List<T>.from(buffer.getRange(0, bufferSize));
      buffer.removeRange(0, hop);
    }
  }
  // 最后的不要了，因为数目不够一帧，且应该发生在dispose后
  // if (buffer.isNotEmpty) {
  //   yield List<T>.from(buffer);
  // }
}

/// Converts PCM16 encondig to float.
extension _PCMConversions on Uint8List {
  List<double> convertPCM16ToFloat() {
    ByteData byteData = buffer.asByteData();
    List<double> floatList = [
      for (var offset = 0; offset < length; offset += 2)
        ((byteData.getUint16(offset)) - 32768) / 32768,
    ];
    return floatList;
  }
}

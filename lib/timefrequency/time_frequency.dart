import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'yin.dart';
import 'nopeak.dart';
import 'latest_array.dart';
import '../utils/list_notifier.dart';
import '../utils/freq_table.dart';

class TimeFrequency extends StatefulWidget {
  final ValueNotifier<double>? freqNotifier;
  final FreqTable freqTable;
  const TimeFrequency({super.key, this.freqNotifier, required this.freqTable});
  @override
  State<TimeFrequency> createState() => _TimeFrequencyState();
}

class _TimeFrequencyState extends State<TimeFrequency> {
  static const int sampleRate = 22050; // 采样率
  final AudioRecorder recorder = AudioRecorder();
  final yin = YIN(frameSize: 2048, sampleRate: sampleRate, threshold: 0.2);

  late LazyNotifier<LatestArray> pitches;

  double stablePitch = -440;

  DateTime _lastDragEnd = DateTime.now();
  bool _isDragging = false;
  // 用户拖动结束 1 秒内视为“仍在拖动”
  bool get _userHolding =>
      _isDragging ||
      DateTime.now().difference(_lastDragEnd).inMilliseconds < 1000;

  late double _viewCenterNorm; // 归一化视野中心
  double _viewLeft = 0;
  double _semiToneWidth = 60;

  @override
  void initState() {
    super.initState();
    _viewCenterNorm = _canvasWidth / 2 / _semiToneWidth;
    pitches = LazyNotifier(LatestArray(120));
    _init();
  }

  // 更新 freqs
  Future<void> _init() async {
    if (await Permission.microphone.request() != PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('没有麦克风权限，JE酱听不到声音啦www'),
          action: SnackBarAction(
            label: '去授权',
            onPressed: openAppSettings,
          ),
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
      // print(freq);
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
        final w = constraints.maxWidth;
        final w2 = w / 2;
        _viewLeft = (_viewCenterNorm * _semiToneWidth - w2).clamp(
          0,
          _canvasWidth - w,
        );
        double originalWidth = _semiToneWidth;
        return GestureDetector(
          // 改变视野
          onHorizontalDragStart: (details) {
            _isDragging = true;
          },
          onHorizontalDragUpdate: (details) {
            _viewLeft = (_viewLeft - details.delta.dx).clamp(
              0,
              _canvasWidth - w,
            );
            _viewCenterNorm = (_viewLeft + w2) / _semiToneWidth;
            pitches.notify();
          },
          onHorizontalDragEnd: (details) {
            _isDragging = false;
            _lastDragEnd = DateTime.now();
          },
          // 缩放手势 保持中心
          onScaleUpdate: (details) {
            _semiToneWidth = (originalWidth * details.scale).clamp(w / 36, w);
            _viewLeft = (_viewCenterNorm * _semiToneWidth - w2).clamp(
              0,
              _canvasWidth - w,
            );
            pitches.notify();
          },
          onScaleEnd: (detail) {
            originalWidth = _semiToneWidth;
          },
          child: ValueListenableBuilder<LatestArray>(
            valueListenable: pitches,
            builder: (context, latestArray, child) {
              // 自动移动视野 以稳定频率为中心 如果最后一个频率超出则以其为准
              if (_userHolding == false) {
                final centerPx = stablePitch > 0
                    ? pitch2Px(stablePitch)
                    : (_canvasWidth / 2);
                double viewLeft = centerPx - w2;
                final fAt = pitch2Px(latestArray.latest);
                if (fAt < viewLeft) {
                  viewLeft = fAt - _semiToneWidth / 2;
                } else if (fAt > viewLeft + w) {
                  viewLeft = fAt - w + _semiToneWidth / 2;
                }
                _viewLeft = viewLeft.clamp(0, _canvasWidth - w);
                _viewCenterNorm = (_viewLeft + w2) / _semiToneWidth;
                stablePitch = _viewCenterNorm;
              }

              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _TimeFrequencyPainter(
                  pitches: latestArray,
                  freqTable: widget.freqTable,
                  viewLeft: _viewLeft,
                  semiToneWidth: _semiToneWidth,
                  lineColor: Theme.of(context).colorScheme.primary,
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
    required viewLeft,
    required this.semiToneWidth,
    this.lineColor = Colors.blue,
    this.textColor = Colors.black,
    this.fontSize = 12,
  }) : viewLeft = viewLeft - semiToneWidth / 2;

  @override
  void paint(Canvas canvas, Size size) {
    int startIndex = (viewLeft / semiToneWidth).floor().clamp(
      0,
      freqTable.length,
    );
    int endIndex = ((viewLeft + size.width) / semiToneWidth).ceil().clamp(
      0,
      freqTable.length,
    );
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill
      ..strokeWidth = 1;
    final hY = fontSize;
    final lY = size.height - fontSize;
    final textStyle = TextStyle(
      color: textColor,
      fontSize: fontSize > 0 ? fontSize : 0,
    );
    for (int i = startIndex; i < endIndex; i++) {
      final x = i * semiToneWidth - viewLeft;
      canvas.drawLine(Offset(x, hY), Offset(x, lY), paint);
      if (fontSize > 0) {
        // 底部绘制音名
        drawText(
          canvas,
          '${FreqTable.noteName[i % 12]}${i ~/ 12 + 1}',
          (x, lY),
          ratio: (-0.5, 0),
          style: textStyle,
        );
        // 顶部绘制频率
        drawText(
          canvas,
          freqTable[i].toStringAsPrecision(4),
          (x, hY),
          ratio: (-0.5, -1),
          style: textStyle,
        );
      }
    }

    // 绘制频率线
    final linePainter = Paint()
      ..color = lineColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    double step = (size.height - 2 * fontSize) / pitches.length;
    final double pitchOffset = _TimeFrequencyState.musiclog2(
      440 / freqTable.A4,
    );
    final path = Path();
    bool first = true;
    double y = size.height - fontSize;
    for (final p in pitches.values) {
      final px = semiToneWidth * (p + pitchOffset) - viewLeft;
      if (first) {
        path.moveTo(px, y);
        first = false;
      } else {
        path.lineTo(px, y);
      }
      y -= step;
    }
    canvas.drawPath(path, linePainter);
  }

  void drawText(
    Canvas canvas,
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

    textPainter.paint(canvas, offset);
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
  if (buffer.isNotEmpty) {
    yield List<T>.from(buffer);
  }
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

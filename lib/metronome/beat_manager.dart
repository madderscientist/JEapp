import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../utils/background_service_handler.dart';
import '../utils/lazy_notifier.dart';
import 'shot_player.dart';

class BeatManager {
  final BackGroundServiceHandler handler;
  final ShotPlayer player;
  SoLoud get _soloud => player.soloud;

  BeatManager({required this.handler, required this.player}) {
    bpmNotifier.addListener(() {
      _reschedule(tempoChanged: true);
      _statusBar();
    });
    player.onBeatSourcesChanged = _reschedule;
    _deviceErrors = _soloud.audioDeviceStartFailures.listen((error) {
      _reportFailure(error, StackTrace.current);
    });
    enableNotifier.addListener(_statusBar);
    handler.playbackQueue.add(play);
    handler.pauseQueue.add(pause);
    handler.skipToPreviousQueue.add(skipToPrevious);
    handler.skipToNextQueue.add(skipToNext);
    handler.seekQueue.add(seek);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    final stopped = pause();
    _disposed = true;
    player.onBeatSourcesChanged = null;
    handler.playbackQueue.remove(play);
    handler.pauseQueue.remove(pause);
    handler.skipToPreviousQueue.remove(skipToPrevious);
    handler.skipToNextQueue.remove(skipToNext);
    handler.seekQueue.remove(seek);
    try {
      await Future.wait([stopped, handler.stop(), _deviceErrors.cancel()]);
    } finally {
      bpmNotifier.dispose();
      enableNotifier.dispose();
      await _beatController.close();
    }
  }

  /// bpm管理 外界应该用bpm的getter和setter
  final LazyNotifier<int> bpmNotifier = LazyNotifier<int>(120);
  int get bpm => bpmNotifier.value;
  set bpm(int newBPM) => bpmNotifier.value = newBPM.clamp(bpmMin, bpmMax);
  static const int bpmMax = 400;
  static const int bpmMin = 10;

  /// 节拍产生开关 外界应该用enable的getter和setter
  /// enableNotifier在play和pause中修改，其他地方不允许修改
  final LazyNotifier<bool> enableNotifier = LazyNotifier<bool>(false);
  bool get enable => enableNotifier.value;
  set enable(bool value) => value ? play() : pause();

  static const _lead = Duration(milliseconds: 50);
  static const _ahead = Duration(milliseconds: 1500);
  Timer? _timer;
  late final StreamSubscription<Object> _deviceErrors;
  bool _disposed = false;
  List<int> _pattern = [3, 1, 2, 1];
  bool _muted = false;
  int currentBeat = 0;
  int _nextIndex = 0;
  double _nextMicros = 0;
  final _pending = <({Duration time, int index})>[];
  final _voices = <SoundHandle, Duration>{};

  // 事件桥梁，用stream传递beat事件
  final StreamController<void> _beatController =
      StreamController<void>.broadcast();
  Stream<void> get beatStream => _beatController.stream;

  /// 配置只在编辑时复制，定时检查不读取页面对象
  void configure(Iterable<int> pattern, {required bool muted}) {
    if (_disposed) return;
    _pattern = List.of(pattern);
    assert(_pattern.isNotEmpty && _pattern.length <= 16);
    assert(_pattern.every((level) => level >= 0 && level <= 3));
    _muted = muted;
    _reschedule();
    if (_nextIndex >= _pattern.length) _nextIndex = 0;
  }

  /// 发声由原生引擎定时；轮询只刷新当前拍号并补充有限的未来拍点
  void _tick() {
    if (_disposed || !enable) return;
    final now = _soloud.getEngineTime();
    _advance(now);
    _voices.removeWhere((handle, _) => !_soloud.getIsValidVoiceHandle(handle));
    final interval = 60000000 / bpm;
    // 超过预排窗口时跳过错过的声音，保持原时间轴，不立即补播
    if (_nextMicros < now.inMicroseconds) {
      final skipped =
          ((now.inMicroseconds + _lead.inMicroseconds - _nextMicros) / interval)
              .ceil();
      _nextMicros += skipped * interval;
      _nextIndex = (_nextIndex + skipped) % _pattern.length;
    }
    final horizon = now + _ahead;
    while (_pending.isEmpty || _nextMicros <= horizon.inMicroseconds) {
      final time = Duration(microseconds: _nextMicros.round());
      final handle = player.scheduleBeat(
        _muted ? 0 : _pattern[_nextIndex],
        time,
      );
      if (handle != null) _voices[handle] = time;
      _pending.add((time: time, index: _nextIndex));
      _nextMicros += interval;
      _nextIndex = (_nextIndex + 1) % _pattern.length;
    }
  }

  void _advance(Duration now) {
    var count = 0;
    while (count < _pending.length && _pending[count].time <= now) {
      currentBeat = _pending[count].index;
      count++;
    }
    if (count == 0) return;
    _pending.removeRange(0, count);
    // 卡顿后仅通知最新一拍，避免动画与震动连续补发
    _beatController.add(null);
  }

  Future<void> _cancelSounds({Duration? after}) {
    final handles = _voices.entries
        .where((entry) => after == null || entry.value > after)
        .map((entry) => entry.key)
        .toList();
    for (final handle in handles) {
      _voices.remove(handle);
    }
    return Future.wait(handles.map(_soloud.stop));
  }

  void _reschedule({bool tempoChanged = false}) {
    if (_disposed || !enable) return;
    final now = _soloud.getEngineTime();
    _advance(now);
    if (_pending.isNotEmpty) {
      _nextIndex = _pending.first.index;
      _nextMicros = _pending.first.time.inMicroseconds.toDouble();
    }
    if (_nextIndex >= _pattern.length) _nextIndex = 0;
    if (tempoChanged) _nextMicros = now.inMicroseconds + 60000000 / bpm;
    _pending.clear();
    unawaited(
      _cancelSounds(after: _muted ? null : now).catchError(_reportFailure),
    );
    _poll();
  }

  void _poll() {
    try {
      _tick();
    } catch (error, stack) {
      _reportFailure(error, stack);
    }
  }

  void _reportFailure(Object error, StackTrace stack) {
    unawaited(pause().catchError(_logError));
    _logError(error, stack);
  }

  static void _logError(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
  }

  /// 通知栏Card管理，将bpm映射为进度
  /// 随bpm的变化而变化
  static const _durationMax = Duration(seconds: 1);
  void _statusBar() {
    if (enableNotifier.value) {
      handler.mediaItem.add(
        MediaItem(
          id: 'je-Metronome',
          album: 'Metronome',
          title: 'BPM: ${bpmNotifier.value}',
          artist: 'JE节拍器',
          duration: _durationMax,
        ),
      );
    } else {
      handler.mediaItem.add(null);
    }
    handler.playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
        // 可拖动进度条
        systemActions: {MediaAction.seek},
        speed: 0,
        playing: enableNotifier.value,
        processingState: AudioProcessingState.ready,
        bufferedPosition: _durationMax,
        updatePosition: Duration(
          milliseconds:
              ((_durationMax.inMilliseconds) *
                      ((bpmNotifier.value - bpmMin) / (bpmMax - bpmMin)))
                  .round(),
        ),
      ),
    );
  }

  /// 和通知栏Card联动的重载 需要注册到handler中
  Future<void> play() async {
    if (_disposed || enable) return;
    enableNotifier.value = true;
    try {
      _soloud.setAudioDeviceIdleTimeout(null);
      _nextMicros = (_soloud.getEngineTime() + _lead).inMicroseconds.toDouble();
      _timer = Timer.periodic(const Duration(milliseconds: 20), (_) => _poll());
      _poll();
    } catch (error, stack) {
      _reportFailure(error, stack);
    }
  }

  Future<void> pause() async {
    if (_disposed || !enable) return;
    if (_soloud.isInitialized) _advance(_soloud.getEngineTime());
    if (_pending.isNotEmpty) _nextIndex = _pending.first.index;
    _pending.clear();
    _timer?.cancel();
    _timer = null;
    enableNotifier.value = false;
    if (_soloud.isInitialized) {
      _soloud.setAudioDeviceIdleTimeout(const Duration(milliseconds: 500));
      await _cancelSounds();
    } else {
      _voices.clear();
    }
  }

  Future<void> skipToPrevious() async => bpm = bpm - 1;

  Future<void> skipToNext() async => bpm = bpm + 1;

  Future<void> seek(Duration position) async {
    // 将 position 映射到 bpmMin ~ bpmMax
    final clamped = position.inMilliseconds.clamp(
      0,
      _durationMax.inMilliseconds,
    );
    bpm =
        bpmMin +
        ((bpmMax - bpmMin) * clamped / _durationMax.inMilliseconds).round();
  }
}

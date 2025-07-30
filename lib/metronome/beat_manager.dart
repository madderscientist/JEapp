import 'dart:async';
import 'package:audio_service/audio_service.dart';
import '../utils/background_service_handler.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class BeatManager {
  final BackGroundServiceHandler handler;

  Future<void> _init() async {
    bpmNotifier.addListener(() {
      bpmInterval = fromBPM(bpmNotifier.value);
      _statusBar();
    });
    await _initSilencePlayer();
    enableNotifier.addListener(_statusBar);
    handler.playbackQueue.add(play);
    handler.pauseQueue.add(pause);
    handler.skipToPreviousQueue.add(skipToPrevious);
    handler.skipToNextQueue.add(skipToNext);
    handler.seekQueue.add(seek);
  }

  BeatManager({required this.handler, void Function()? onInitialized}) {
    _init().then((_) => onInitialized?.call());
  }

  BeatManager._(this.handler);

  static Future<BeatManager> create(BackGroundServiceHandler handler) async {
    final manager = BeatManager._(handler);
    await manager._init();
    return manager;
  }

  void dispose() {
    handler.stop();
    handler.playbackQueue.remove(play);
    handler.pauseQueue.remove(pause);
    handler.skipToPreviousQueue.remove(skipToPrevious);
    handler.skipToNextQueue.remove(skipToNext);
    handler.seekQueue.remove(seek);
    _posSub?.cancel();
    _silencePlayer.dispose();
    bpmNotifier.dispose();
    enableNotifier.dispose();
    _beatController.close();
  }

  /// bpm管理 外界应该用bpm的getter和setter
  final ValueNotifier<int> bpmNotifier = ValueNotifier<int>(120);
  Duration bpmInterval = fromBPM(120);
  int get bpm => bpmNotifier.value;
  set bpm(int newBPM) => bpmNotifier.value = newBPM.clamp(bpmMin, bpmMax);
  static const int bpmMax = 400;
  static const int bpmMin = 10;
  static Duration fromBPM(int bpm) =>
      Duration(milliseconds: (60000 / bpm).round());

  /// 节拍产生开关 外界应该用enable的getter和setter
  /// enableNotifier在play和pause中修改，其他地方不允许修改
  final ValueNotifier<bool> enableNotifier = ValueNotifier<bool>(false);
  bool get enable => enableNotifier.value;
  set enable(bool value) => value ? play() : pause();

  /// 静音播放器 用于计时产生beat
  final AudioPlayer _silencePlayer = AudioPlayer();
  StreamSubscription<Duration>? _posSub; // 管理beat回调
  // 事件桥梁，用stream传递beat事件
  final StreamController<void> _beatController =
      StreamController<void>.broadcast();
  Stream<void> get beatStream => _beatController.stream;
  // 初始化静音播放器
  Future<void> _initSilencePlayer() async {
    await _silencePlayer.setAudioSource(
      // SilenceAudioSource 只支持android而且有bug，所以用实际音频+静音
      AudioSource.asset('assets/metronome/silent.aac'),
    );
    await _silencePlayer.setLoopMode(LoopMode.one);
    await _silencePlayer.setVolume(0);  // 手动静音不会被杀，音频为0会被杀
  }

  /// beat通知
  DateTime? _lastBeatTime; // 上次节拍的时间点 之所以不用Duration pos是因为loop切换的时候不稳定
  void _onPosition(Duration pos) async {
    final now = DateTime.now();
    if (_lastBeatTime == null) {
      _lastBeatTime = now;
    } else {
      final interval = now.difference(_lastBeatTime!);
      if (interval < bpmInterval) return;
      // 考虑到系统卡顿，可能空了好多拍
      _lastBeatTime = _lastBeatTime!.add(
        bpmInterval * (interval.inMilliseconds ~/ bpmInterval.inMilliseconds),
      );
    }
    if (_beatController.isClosed) return;
    _beatController.add(null);
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
    enableNotifier.value = true;
    _lastBeatTime = null;
    _posSub?.cancel();
    _posSub = _silencePlayer.positionStream.listen(_onPosition);
    await _silencePlayer.play();
    _onPosition(_silencePlayer.position);
  }

  Future<void> pause() async {
    enableNotifier.value = false;
    _posSub?.cancel();
    _posSub = null;
    await _silencePlayer.pause();
    await _silencePlayer.seek(Duration.zero);
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

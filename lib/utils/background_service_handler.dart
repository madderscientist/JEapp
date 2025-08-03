import 'dart:async';
import 'package:audio_service/audio_service.dart';

typedef Fv = Future<void> Function();
typedef FvD = Future<void> Function(Duration);

class BackGroundServiceHandler extends BaseAudioHandler {
  final List<Fv> playbackQueue = [];
  final List<Fv> pauseQueue = [];
  final List<Fv> skipToPreviousQueue = [];
  final List<Fv> skipToNextQueue = [];
  final List<FvD> seekQueue = [];

  /// 和通知栏Card联动的重载
  @override
  Future<void> play() async {
    await Future.wait(playbackQueue.map((f) => f()));
  }

  @override
  Future<void> pause() async {
    await Future.wait(pauseQueue.map((f) => f()));
  }

  @override
  Future<void> skipToPrevious() async {
    await Future.wait(skipToPreviousQueue.map((f) => f()));
  }

  @override
  Future<void> skipToNext() async {
    await Future.wait(skipToNextQueue.map((f) => f()));
  }

  @override
  Future<void> seek(Duration position) async {
    await Future.wait(seekQueue.map((f) => f(position)));
  }

  @override
  Future<void> stop() async {
    // 当用户划掉通知栏里的卡片 关闭后台
    pause();
    await super.stop();
  }

  /// 全局单例
  static BackGroundServiceHandler? audioServiceHandler;
  static Future<BackGroundServiceHandler> getAudioServiceHandler() async {
    BackGroundServiceHandler.audioServiceHandler ??= await AudioService.init(
      builder: () => BackGroundServiceHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.maddersientist.je.metronome.channel.audio',
        androidNotificationChannelName: 'je-Metronome',
        androidNotificationOngoing: true,
        // androidStopForegroundOnPause: false,
      ),
    );
    return BackGroundServiceHandler.audioServiceHandler!;
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:je/config.dart';

// 播放音效 要求及时响应
class ShotPlayer {
  final soloud = SoLoud.instance;
  List<AudioSource> sources = [];
  List<AudioSource> beatSources = [];
  void Function()? onBeatSourcesChanged;
  Future<void> _groupLoad = Future.value();
  int _loadedGroup = -1;
  bool _disposed = false;

  /// 不准直接设置 beatGroupNotifier.value
  LazyNotifier<int> beatGroupNotifier = LazyNotifier<int>(0);
  set beatGroup(int group) {
    beatGroupNotifier.value = group % 3;
  }

  int get beatGroup => beatGroupNotifier.value;

  ShotPlayer._();

  static Future<ShotPlayer> create() async {
    final player = ShotPlayer._();
    player.beatGroupNotifier.addListener(() {
      player._groupLoad = player._groupLoad
          .then((_) async {
            if (player._disposed) return;
            await player._loadBeatGroup(player.beatGroup);
          })
          .catchError((Object error, StackTrace stack) {
            if (!player._disposed) {
              player.beatGroupNotifier.setValue(player._loadedGroup);
              player.beatGroupNotifier.notify();
            }
            FlutterError.reportError(
              FlutterErrorDetails(exception: error, stack: stack),
            );
          });
    });
    try {
      await Config.initSoLoud();
      player.sources = await player._loadSources([
        'assets/metronome/tap.wav',
        'assets/metronome/roll.wav',
        'assets/metronome/rollover.wav',
      ]);
      await player._loadBeatGroup();
    } catch (_) {
      await player.dispose();
      rethrow;
    }
    return player;
  }

  SoundHandle tap() => soloud.play(sources[0]);
  SoundHandle rollInRange() => soloud.play(sources[1]);
  SoundHandle rollOverRange() => soloud.play(sources[2]);
  SoundHandle? scheduleBeat(int intensity, Duration atTime) {
    if (intensity == 0) return null;
    return soloud.playScheduled(beatSources[intensity - 1], atTime);
  }

  Future<void> _loadBeatGroup([int group = 0]) async {
    if (group == _loadedGroup) return;
    final folder = group + 1;
    final loaded = await _loadSources([
      'assets/metronome/$folder/3.wav',
      'assets/metronome/$folder/2.wav',
      'assets/metronome/$folder/1.wav',
    ]);
    if (_disposed || group != beatGroup) {
      await Future.wait(loaded.map(soloud.disposeSource));
      return;
    }
    final previous = beatSources;
    beatSources = loaded;
    _loadedGroup = group;
    // 先用新组重排未来拍点，再释放旧组，避免计划引用已释放音源
    onBeatSourcesChanged?.call();
    await Future.wait(previous.map(soloud.disposeSource));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    onBeatSourcesChanged = null;
    beatGroupNotifier.dispose();
    await _groupLoad;
    // 引擎与乐谱合成器共享，页面退出只释放自己的音源
    await Future.wait([...sources, ...beatSources].map(soloud.disposeSource));
    sources = [];
    beatSources = [];
  }

  Future<List<AudioSource>> _loadSources(List<String> paths) => Future.wait(
    paths.map(soloud.loadAsset),
    cleanUp: (source) {
      soloud.disposeSource(source);
    },
  );
}

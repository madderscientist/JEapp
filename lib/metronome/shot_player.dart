import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:je/config.dart';

// 播放音效 要求及时响应
class ShotPlayer {
  final soloud = SoLoud.instance;
  late final bool alreadyInit;
  late List<AudioSource> sources;
  List<AudioSource> beatSources = [];

  /// 不准直接设置 beatGroupNotifier.value
  ValueNotifier<int> beatGroupNotifier = ValueNotifier<int>(0);
  set beatGroup(int group) {
    beatGroupNotifier.value = group % 3;
  }

  int get beatGroup => beatGroupNotifier.value;

  ShotPlayer._();

  static Future<ShotPlayer> create() async {
    final player = ShotPlayer._();
    player.beatGroupNotifier.addListener(() {
      player._loadBeatGroup(player.beatGroupNotifier.value);
    });
    await player._initSoloud();
    return player;
  }

  Future<SoundHandle> tap() => soloud.play(sources[0]);
  Future<SoundHandle> rollInRange() => soloud.play(sources[1]);
  Future<SoundHandle> rollOverRange() => soloud.play(sources[2]);
  Future<SoundHandle>? beat([int intensity = 1]) {
    if (intensity == 0) return null;
    return soloud.play(beatSources[intensity - 1]);
  }

  Future<void> _loadBeatGroup([int group = 0]) async {
    group = (group % 3) + 1;
    final temp = beatSources;
    beatSources = await Future.wait([
      soloud.loadAsset('assets/metronome/$group/3.wav'),
      soloud.loadAsset('assets/metronome/$group/2.wav'),
      soloud.loadAsset('assets/metronome/$group/1.wav'),
    ]);
    for (final source in temp) {
      soloud.disposeSource(source);
    }
  }

  void dispose() {
    beatGroupNotifier.dispose();
    if (alreadyInit) {
      for (var source in sources) {
        soloud.disposeSource(source);
      }
      for (var source in beatSources) {
        soloud.disposeSource(source);
      }
    } else {
      soloud.deinit();
    }
  }

  Future<void> _initSoloud() async {
    // 本类析构后要回到之前的样子。如果之前没有初始化，说明生命周期自己掌握，需要deinit
    alreadyInit = await Config.initSoLoud();
    await Future.wait([
      _loadBasicSource(),
      _loadBeatGroup(beatGroupNotifier.value),
    ]);
  }

  Future<void> _loadBasicSource() async {
    sources = await Future.wait([
      soloud.loadAsset('assets/metronome/tap.wav'),
      soloud.loadAsset('assets/metronome/roll.wav'),
      soloud.loadAsset('assets/metronome/rollover.wav'),
    ]);
  }
}

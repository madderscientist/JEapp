# 节拍器
对标的是`Pro Metornome`，实现起来比想象的困难一些，有如下难点：

## 【最大的难点1】精准计时
后台使用 `audio_service`，精准计时需要一个更高频的心跳，用timer不够精准还会被杀掉。所以使用了 `just_audio` 作为驱动，用 `positionStream` 充当心跳（类似notedigger中midi和audio的对齐的实现）。

本来使用了 `SilenceAudioSource`，在模拟器上一切正常，但在我的红米手机上，后台运行一会就挂掉了。苦苦寻找答案未果，发现 `SilenceAudioSource` 只能在安卓上用，于是换成了一个超弱音的音频（此音频有问题，见后）：
```bash
ffmpeg -f lavfi -i "sine=frequency=110:duration=20:sample_rate=22050" -filter:a "volume=0.001" silence_low.mp3
```
发现此时可以后台不被冻结了。但是回调的 `Duration position` 并不精准（和实际的事件流逝不同，还喜欢抽风），还是使用了现实时间。

这部分封装为了 [BeatManager](beat_manager.dart)，专门管理节拍，通过 `beatStream` 通知其他部分。

目前的问题是后台偶尔还是会乱，仿佛打了个瞌睡然后猛补。应该是音频流怠慢了。此外播放静音的那个播放器有各种bug，比如整个App第一次启动silence播放器会idle，因此初始化使用了播放瞬间暂停；但第二次进入本页面，就会卡在`await _silencePlayer.play();`，因此不能用。

试着找了一下原因，第二次卡住是 `play` 的最后一行 `await playCompleter.future;` 卡住，而这个有关联到 `_sendPlayRequest` 的 `await platform.play(PlayRequest());` 卡住，可能就是原生代码的问题。

### 第一次播放失败
silenceplayer第一次play会失败，但第二次就可以。询问Kimi结果如下：

    第一次失败是因为解码器初始化失败，第二次成功是因为 ExoPlayer 自动换了备用解码器，但你不设置 setEnableDecoderFallback(true)，它不会主动告诉你可以这么做。

告诉我用 `ffprobe silence_low.mp3` 检查格式，结果如下：
```
Input #0, mp3, from 'silence_low.mp3':
  Metadata:
    encoder         : Lavf62.0.102
  Duration: 00:00:20.00, start: 0.050113, bitrate: 32 kb/s
  Stream #0:0: Audio: mp3 (mp3float), 22050 Hz, mono, fltp, 32 kb/s, Start 0.050113
```

问题是：

    在 部分 Android 机型 / 系统版本 上，MediaCodec 的 MP3 解码器 对「低采样率 + 低码率 + LAME 标志」的组合存在 bug：第一次初始化时解析帧头失败 → 抛 IllegalArgumentException；ExoPlayer 捕获后改用 软件解码器（FFmpeg extension 或备用解码器）→ 第二次就正常。

于是换用更兼容的aac：
```bash
ffmpeg -f lavfi -i "sine=frequency=1:duration=20:sample_rate=16000" -c:a aac -b:a 16k -ar 16000 -ac 1 silence.aac
```

volume=0会后台被杀，但应用内静音可以正常播放。这样一来连后台的计时混乱也解决了。

## 【最大的难点2】后台运行
这部分封装为了 [BackgroundServiceHandler类](background_metronome_handler.dart)。一个遗憾是 `AudioService` 是全局的，一旦设置了就关不掉了（插件没有析构，我也不会原生）（如果写原生，安卓可以新开一个activity，但IOS我真不懂）。目前是打开了本界面就注册 `AudioService` 并添加到 `Config` 中作为全局单例。

由于是全局单例，就不能按照节拍器定制。所以写成了功能注册的形式。

## 音效及时播放
最终选择了 `flutter_soloud`，相比 `just_audio` 可以提前加载且延时很小。音效的播放封装于 [ShotPlayer类](shot_player.dart)，写死了。注意 `SoLoud` 也是全局单例，不过可以析构。

## UI动效
借鉴了 Pulse ，还增加了液滴效果。液滴使用余弦函数的一个周期，响应 `BackgroundMetronomeHandler.beatStream` 进行一次动效。封装于 [BeatCircle类](beat_circle.dart)。
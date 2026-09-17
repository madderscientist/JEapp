# 节拍器

## 节拍调度
[BeatManager](beat_manager.dart) 使用 SoLoud 的 `getEngineTime()` 与 `playScheduled()` 提前安排发声。每 20ms 检查一次，补充未来 1.5 秒内的拍点；低 BPM 时至少保留下一拍，启动提前量为 50ms。

时间轴按拍长累计，短时 Dart 卡顿不影响已排定的声音。卡顿超过预排窗口时跳过错过的声音，界面仅通知最新已到达的拍点，避免连续补播和补震动。

变速从当前引擎时间加新拍长重新排程；修改拍型、静音或音色保留下一拍时间。暂停取消自己的节拍句柄，继续时保留下一拍索引。

## 后台运行
[BackGroundServiceHandler](../utils/background_service_handler.dart) 通过 `audio_service` 提供通知栏及后台控制，各页面注册、注销自己的操作回调。

播放期间设置 `setAudioDeviceIdleTimeout(null)`，让音频设备在静音及长拍间隔中继续运行；暂停时恢复应用默认的 500ms 空闲超时，无需循环播放静音文件。

引擎时间仅在设备混音时推进。厂商后台限制、蓝牙及来电中断仍需实际设备验证，有限预排窗口无法覆盖无限期挂起。

## 音效与资源
[ShotPlayer](shot_player.dart) 预加载 WAV，强度 1/2/3 分别对应所选组的 3/2/1.wav，强度 0 不发声。Tap 与旋钮音效即时播放。

音色切换串行加载，新组就绪后重排未来拍点并释放旧组。页面退出只释放自己的音源，保留与合成器共享的 SoLoud 引擎。

## UI 动效
[BeatCircle](beat_circle.dart) 通过 `BeatManager.beatStream` 驱动动效。拍号与震动跟随引擎已到达的拍点，仍可能受 Dart 回调延迟影响。
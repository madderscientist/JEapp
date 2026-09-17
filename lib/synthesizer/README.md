# 合成器
用于演奏音符。没有使用FluidSynth，而是复用了`SoLoud`的PCM功能，再找了一个使用soundfont的库。

## 难点
### SoLoud的stream播放同步
即填充适量PCM数据，使之不断流、不溢出。等到回调触发的时候已经pause了，所以要提前预测。采用了定时器主动查询的方法。

### SoLoud的buffer大小
一开始为了及时响应，将每次填充的数据量设置得比较小。然而发现fill小了无法开始播放，即使buffer里面有内容。为了启动初始的播放，需要先填一块0。然而fill的取值非常玄学。目前在22050Hz下，每次填充512帧，总容量为四块。真机试过将容量改为三块、不预填或只预填410帧，都没有声音。如果换成44100Hz，这么小的fill还会导致音频断断续续，即填充跟不上播放，这是render拖累了。

### SoLoud的初始化和Assets读取
决定在Isolate中运行，因为计时器频率挺高，且render挺费算力。isolate间内存隔离，导致Dart封装的SoLoud不是一个；但底层的SoLoud是C++全局单例，多个Isolate共用。rootBundle留在主线程使用，后台直接通过`SoLoudIsolate.instance.bindings`操作原生引擎，无需初始化BinaryMessenger。

因此，soundfont文件数据在主线程加载并发送，SoLoud也在主线程初始化，后台只负责合成和填充PCM。

## SoLoud 的冲突
SoLoud是全局单例，共用C++层，因此在任意一个线程init都可以。但是如果不是在主线程，会导致加载asset的“Temporary directory hasn't been initialized”（原因见上），这会导致节拍器的SoLoud加载音源失败，会出现这样的情况：
- 如果先使用了合成器，再使用节拍器，会导致asset加载失败；
- 如果先使用了节拍器，再使用合成器，一切正常。

因此统一在主线程init，后台不再重复初始化，避免接管原生回调导致主线程loadAsset一直等待。停止播放或退出页面只释放自己的音频流，不析构共享引擎。
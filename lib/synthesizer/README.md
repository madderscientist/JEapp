# 合成器
用于演奏音符。没有使用FluidSynth，而是复用了`SoLoud`的PCM功能，再找了一个使用soundfont的库。在此之前有一个失败的尝试: [audioGraph](../audioGraph/README.md)

## 难点
### SoLoud的stream播放同步
即填充适量PCM数据，使之不断流、不溢出。等到回调触发的时候已经pause了，所以要提前预测。采用了定时器主动查询的方法。

### SoLoud的buffer大小
一开始为了及时响应，将每次填充的数据量设置得比较小。然而发现fill小了无法开始播放，即使buffer里面有内容。为了启动初始的播放，需要先将buffer填充满0。然而fill的取值非常玄学。在audioGraph文件夹中，在24000采样率下用512足以运行，但这里512是临界值，取513都可以运行，但小于512就是不行（指不播放，即使一直在填充；一直填充但没报错充满，说明消耗掉了，但是就是没声音）。如果换成44100Hz，这么小的fill还会导致音频断断续续，即填充跟不上播放，这是render拖累了。

### SoLoud的初始化和Assets读取
决定在Isolate中运行，因为计时器频率挺高，且render挺费算力。isolate间内存隔离，导致Dart封装的SoLoud不是一个；但底层的SoLoud是C++全局单例，多个Isolate共用（因此主线程先init，在其他线程可以发现已经初始化）。创建Dart和C++的通信需要“二进制消息通道（BinaryMessenger）”，因此需要在通道初始化(BackgroundIsolateBinaryMessenger.ensureInitialized)后运行。但Isolate中只会初始化BinaryMessenger，其他的binding都不会，所以rootBundle不能在Isolate中用，也就是isolate中不能读取assets。

因此，soundfont文件数据在主线程加载并发送（为此设计成没有合成器也能播放），Soloud初始化还是放到Isolate中，等待消息通道初始化完成后进行。
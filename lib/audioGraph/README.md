# 简易合成器
目的是做一个简单的合成器。其实有一些插件，但是都基于SoundFont，这会极大增加应用体积，但我并不需要很多的音色。

> 实际并未使用本库。发现合成效果和 Web Audio API 相差甚远，原因未知。使用了 [dart_melty_soundfont](https://github.com/chipweinberger) ，并用 [Polyphone](https://www.polyphone.io/en) 得到了只有三个音色的soundfont文件，大大减小了体积。

模仿的是Web Audio API。本来想简单做一个振荡器，其幅度、频率也都可以是振荡器，以实现AM、FM调制，但这个方案不好实现 `setTargetAtTime` 一类的计时规划功能，因此最好还是将Gain单独分离，还能实现加法器功能。我的想法是构造的时候就传入，但这样不够灵活，最终还是变成了Web Audio API的“connect”方式。

## 获取值的方法
有两种控制-数据流方向：
- 自底而上：从源头一路forward传播值
- 自顶而下：递归向源头索取值

自底而上可能不是好选择，因为要考虑依赖关系，值传播需要按照拓扑顺序。不考虑。

从完成上来说，自顶而下更为简单，因为只需要保存根节点：被索取值的节点走一个时间步。但考虑到一个节点会被连接到多个其他的节点，这样会导致一个节点被多次访问，导致一次取值多次更新。解决这个问题有两个办法：
- 保证只有一连一。不够灵活，pass。
- 取消了“索取就更新”的步骤，且增加全局量AudioContext，管理全部的源并更新。一个想法是创建一个就注册一个，但这样会导致对象一直被引用，无法自动GC（除非增加析构函数）。因此AudioContext管理时间刻。但问题是一秒钟就增加44100，很可能导致上溢出。因此改用了注册的方式，`step()` 由AudioContext统一驱动。

## AudioParam
AudioNode表示所有音频节点，每个节点有 `currentValue` 属性，用于递归取值。每个节点的属性为AuidoParam，可以被其他的AudioNode影响（调制），也可以计划值变化。这是AudioParam最重要的两个功能。https://webaudio.github.io/web-audio-api/#dom-audioparam

AudioParam最终值的公式是：$computedValue = intrinsicValue + inputSignal$，其中：
- computedValue：最终输出值。有下界和上界，比如频率和幅度为非负数。
- intrinsicValue：由 setValueAtTime、setTargetAtTime、linearRampToValueAtTime 等方法调度的时间线值，即`.value`。（赋值时取消所有schedule）
- inputSignal：来自其他节点通过 connect() 连接到该 AudioParam 的音频信号（已下混为单声道）。如果没有连接则为0。


## 更新
要step的有：
- AudioContext：要更新时间。必须是第一个更新的，因为AudioParam依赖时间。
- AudioParam：要根据Schedule计算新值。依赖AudioContext的时间
- AudioNode：依赖AudioParam，所以先要更新其AudioParam

因此AudioContext先step，然后驱动所有AudioNode更新，AudioNode更新前先驱动各自的AudioParam更新。更新后再递归得到最终值。

## 结构
`Connectable`: 最底层的基类，描述了图结构（connect方法等，有向图、双向连接）和信号传递（currentValue属性）。以下派生类作为Mixin。
    - `SI`: 即"single in"，只有一个输入，比如`AudioParam`只能被一个信号调制
        - `AudioParam` 只能被一个信号调制
    - `MO`: 即"multi out"，有多个输出。所有的音频节点都可以多输出
    - `SIMO`: 即"single in multi out"，比如滤波器（未实现）
    - `MIMO`: 即"multi in multi out"，比如GainNode（充当加法器）

`AudioParam` with `SI`: 管理了 `ValueSchedule`。

`AudioNode` extends `Connectable`: 音频节点，定义了向 `AudioContext` 注册与注销的动作
    - `GainNode` with `MIMO`
    - `AudioSource` with `MO`
        - `Oscillator`: 拥有属性 `AudioParam frequency` ，在 `step` 中更新相位。派生类是根据相位输出波形的具体振荡器
            - `SineOscillator`
            - `SquareOscillator`
            - `TriangleOscillator`
            - `SawtoothOscillator`
            - `CustomOscillator`
        - 自定义波形。未实现

`AudioContext`: 管理注册的 `AudioNode` 并通知 `step`；管理时间；负责向 `SoLoud` 输送PCM流。全局单例。

## 音符
上述内容仅仅实现了基本的音频节点，实际用的是音色，用各种调制实现音色，在[NoteManager](note.dart)中实现了合成器。本实现参考了 https://github.com/madderscientist/noteDigger/blob/main/tinySynth.js。但听起来效果完全不一样，不知道哪里出问题了。
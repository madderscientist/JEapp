<p align="center"><img src="assets/icon.png" alt="JEapp Icon" /></p>

# JE曲谱库·移动端

基于 [github曲谱库](https://github.com/zytx121/je/issues) 和 [Acgmuse论坛](https://www.acgmuse.com) 两个数字谱曲谱库 的 曲谱库客户端，纯前端无后端。

使用 `Flutter` 开发以支持Android和IOS，但由于没有果系设备，仅保证Android端可用。没做平板的适配，仅适用于竖屏小屏幕。

## 谱库应用开发历史
- 2018年: 爱上ACG演奏→发现je吧→发现[github曲谱库](https://github.com/zytx121/je/issues)，他们有一个安卓程序“哔谱哔谱”，但是废弃了许多功能。萌生了取而代之的想法。
- 2021年: 高考完的暑假里，用AppInventor制作了第一个[谱库app](https://www.bilibili.com/video/BV1bP4y1P7EC)，实现了诸多功能，但受图形化编程的制约，许多实现都是不得已为之，差强人意，且性能较差。项目在Wxbit平台开发，但后来平台收费，项目遗失，无法维护。
- 2022年: 大一迅速掌握了js，在暑假一周速成了曲谱库的微信小程序[JElib](https://github.com/madderscientist/JElib)，但是因为没有果系设备，因此ios还是不能用……此外微信对个人开发者限制颇大，不仅开发时因此阉割了许多功能，后续更新甚至无法通过审核，遂无法维护。
- 2025年: 暑期实习走的校招路线，刚好在发offer当天毕了业，暑期“失业”在家。恰逢手机故障换新，“哔谱哔谱”在新机无法使用，而我又嫌弃图形化开发的安卓应用是屎山，于是开始开发新的谱库应用——就是本项目！

## 文件结构
```
│  config.dart  【全局变量】
│  main.dart    【程序入口】
│  theme.dart   【默认样式】
│
├─audioGraph    【弃用。模仿WebAudioAPI的合成器】
│      audio_context.dart
│      audio_node.dart
│      audio_param.dart
│      connectable.dart
│      example.dart
│      note.dart
│      README.md
│      value_schedule.dart
│  
├─components
│      bgimg.dart   【home的头图】
│      capsule_selector.dart    【search的源选择】
│      detail.dart  【曲谱详情展示页】
|      github_login 【github登录界面】
│      home.dart    【首页，展示github谱库的最新谱】
│      long_press_copy.dart 【detail中 长按appbar出现的弹窗】
│      mine.dart    【我的，展示本地保存的曲谱】
│      search.dart  【搜索界面，展示历史记录】
│      searchbar.dart   【home和search的搜索框】
│      search_results.dart  【搜索结果】
│      settings.dart    【设置界面】
|      temp_textarea【带dispose回调的输入组件】
│      tool.dart    【工具界面】
│      
├─mdEditor  【Markdown解析于反解析、可视化、长按操作】
│      branch.dart  【block元素的Widget】
│      builder.dart 【提供解析、反解析的接口】
│      context.dart 【主要用于收集转md时的reference】
│      definition.dart  【基本定义】
│      editable_mdwidget.dart
│      leaf.dart    【inline元素的Widget】
│      mdstyle.dart 【样式管理】
│      panel.dart   【转调器】
│      procedure.drawio 【系统结构图】
│      README.md    【实现说明】
│      test.dart    【测试本文件夹的模块】
│
├─metronome     【节拍器】
│      beat_circle.dart 【绘制中心动态圆】
│      beat_level.dart  【选择节奏强度】
│      beat_manager.dart【管理节拍心跳】
│      metronome.dart   【集成各模块的主界面】
│      README.md        【实现说明】
│      shot_player.dart 【音效播放】
│      test.dart        【作为单独的应用】
│
├─synthesizer   【音符声音合成器】
│      README.md            【实现说明】
│      synth_context.dart   【管理合成与输出】
│      synth_worker.dart    【在另一个线程开启合成器】
│      test.dart            【测试本文件夹的模块】
|
├─timefrequency 【调音器（时频曲线）】
│      latest_array.dart    【保存历史频率的循环数组】
│      nopeak.dart          【消除突变】
│      ring.dart            【正弦波发生器】
│      test.dart            【作为单独的应用】
│      time_frequency.dart  【时频绘图】
│      tuner.dart           【集成各模块的主界面】
│      yin.dart             【YIN算法基频提取】
│
└─utils
        action.dart 【url_action的封装】
        background_service_handler.dart 【后台播放相关】
        file.dart   【文件操作】
        freq_table  【12平均律频率表】
        image.dart  【图像操作，与图片仔细浏览界面】
        je_score.dart   【翻译自https://github.com/madderscientist/je_score_operator】
        list_notifier.dart  【暴露notifyListeners方法的ValueNotifier】
        score_request.dart  【曲谱网络请求的封装】
```
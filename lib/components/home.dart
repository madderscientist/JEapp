import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'bgimg.dart';
import '../config.dart';
import 'searchbar.dart';
import 'search.dart';
import '../utils/image.dart';
import '../utils/score_request.dart';
import 'package:toastification/toastification.dart';

class Home extends StatefulWidget {
  /// 外部控制滚动位置
  final ScrollController? scrollController;

  /// 是否显示“回到顶部”按钮
  final LazyNotifier<bool>? show2top;

  const Home({super.key, this.show2top, this.scrollController});

  @override
  State<Home> createState() => _HomeState();
}

// 有关Widget和变量的依赖关系，见home_val.drawio
class _HomeState extends State<Home> with TickerProviderStateMixin {
  final focusNode = FocusNode(); // 跨屏幕键盘
  bool _allowFocus = false; // 超级保险，不让搜索框获取焦点
  // 外部控制滚动位置
  late final scrollController = widget.scrollController ?? ScrollController();
  // 监听滚动位置 在_onScroll中更新
  final scrollOffsetNotifier = LazyNotifier<double>(0.0);

  // 以下是和屏幕尺寸有关，视为某个屏幕大小下的常量，在didChangeDependencies中更新
  late double _screenHeight;
  late double _statusBarHeight;
  late double _initialSearchBarTop;
  late double _initScoreListTop;
  late double _searchBarTravelDistance;
  late double _searchBarSpeedRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.of(context);
    _screenHeight = mediaQuery.size.height;
    _statusBarHeight = mediaQuery.padding.top;
    _initialSearchBarTop = _screenHeight * Config.initSearchBarTopRatio;
    _initScoreListTop =
        _screenHeight * Config.initScoreListTopRatio - _statusBarHeight;
    _searchBarTravelDistance = _initialSearchBarTop - _statusBarHeight;
    final listTravelDistance =
        _initScoreListTop - _statusBarHeight - Config.searchBarHeight;
    _searchBarSpeedRatio = _searchBarTravelDistance / listTravelDistance;
  }

  void _onScroll([int tryTimes = 0]) {
    // 通知父元素使用/取消“回到顶部”按钮 Notifier自带防抖
    widget.show2top?.value = scrollController.offset > _initScoreListTop;
    // 更新 搜索框(位置依赖scrollOffset)
    scrollOffsetNotifier.value = scrollController.offset;
    // 背景图片也依赖_scrollOffset 但被_bgImageNotifier管理
    _bgImageNotifier.notify();
    if (scrollController.position.pixels >
            scrollController.position.maxScrollExtent - 100 &&
        _issueRequester.isLoading == false) {
      _fetchScores(context).then((success) {
        if (tryTimes >= 2) return; // 最多尝试2次 tryTimes仅会在请求失败时增加
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // 若高度还是不够，继续请求 但要等到build完成
          // 失败则累加tryTimes
          _onScroll(success ? 0 : tryTimes + 1);
        });
      });
    }
  }

  static const String _localBgURL = 'assets/homebg.jpg';
  final LazyNotifier<ui.Image?> _bgImageNotifier = LazyNotifier(null);

  /// 尝试加载远程图片，如果失败则使用本地图片
  void setBG([String? neturl]) {
    bool netsetted = false;
    // 如果没有，说明是第一次，需要本地图片以防网络加载失败
    if (_bgImageNotifier.value == null) {
      ImageUtils.loadUIImage(const AssetImage(_localBgURL)).then((img) {
        if (netsetted) return; // 如果已经加载了网络图片，则不再设置本地图片
        _bgImageNotifier.value = img;
      });
    }
    if (Config.networkBanner == false) return;
    // 加载网络图片 由于有缓存，因此需要加上时间戳
    final String url = nocacheURL(neturl ?? Config.networkBannerURL);
    ImageUtils.loadUIImage(NetworkImage(url))
        .then((img) {
          netsetted = true;
          _bgImageNotifier.value?.dispose();
          _bgImageNotifier.value = img;
        })
        .catchError((_) {
          if (context.mounted) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.flatColored,
              title: const Text('网络图片加载失败了 ╥﹏╥'),
              alignment: Alignment.topCenter,
              autoCloseDuration: const Duration(seconds: 3),
              borderRadius: BorderRadius.circular(12.0),
              showProgressBar: false,
              dragToClose: true,
              applyBlurEffect: true,
            );
          }
        }); // 网络失败不处理，保持之前的图片
  }

  final _issueRequestClient = http.Client();
  late final IssueRequester _issueRequester = IssueRequester(
    perPage: 20,
    client: _issueRequestClient,
  );
  final LazyNotifier<List<RawScore>> _scores = LazyNotifier([]);
  // 返回值表示是否成功 用于_onScroll的重试机制
  Future<bool> _fetchScores(BuildContext context, {bool reset = false}) async {
    bool success = true;
    try {
      final p = _issueRequester.fetchIssues(reset: reset);
      _scores.notify();
      final result = await p;
      if (reset) _scores.value.clear();
      _scores.value.addAll(result);
    } catch (e) {
      success = false;
      if (context.mounted) {
        toastification.show(
          context: context,
          type: (e is StateError)
              ? ToastificationType.info
              : ToastificationType.error,
          style: ToastificationStyle.flatColored,
          title: Text(e.toString().split(':').last),
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 3),
          borderRadius: BorderRadius.circular(12.0),
          showProgressBar: false,
          dragToClose: true,
          applyBlurEffect: true,
        );
      }
    }
    _scores.notify();
    return success;
  }

  Future<void> _onRefresh(BuildContext context) async {
    setBG();
    await _fetchScores(context, reset: true);
    if (!context.mounted) return;
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      title: const Text('刷新完毕 (๑•̀ㅂ•́)و✧'),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 2),
      borderRadius: BorderRadius.circular(12.0),
      showProgressBar: false,
      dragToClose: true,
      applyBlurEffect: true,
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    focusNode.dispose();
    _bgImageNotifier.value?.dispose();
    _bgImageNotifier.dispose();
    _issueRequestClient.close();
    scrollOffsetNotifier.dispose();
    _scores.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setBG();
      _onScroll(); // 初始高度不足自动加载，而不是调用fetch
    });
    focusNode.addListener(() {
      if (_allowFocus == false) FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final heroSearchBar = Hero(
      tag: Config.searchBarHeroTag,
      child: MySearchBar(
        inputMode: false,
        focusNode: focusNode,
        onTap: () {
          _allowFocus = true;
          focusNode.requestFocus();
          searchPage(context).then((_) {
            FocusManager.instance.primaryFocus?.unfocus();
            _allowFocus = false;
          });
        },
      ),
    );
    // 处于Main的Staffold中
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // 背景图
        ValueListenableBuilder<ui.Image?>(
          valueListenable: _bgImageNotifier,
          builder: (context, image, child) {
            final bgscale = scrollOffsetNotifier.value > 0
                ? 1.0
                : (1.0 - scrollOffsetNotifier.value / _screenHeight);
            final scrollDistanceAvailable =
                _initScoreListTop - _statusBarHeight;
            final bgOpacity =
                ((scrollDistanceAvailable - scrollOffsetNotifier.value) /
                        scrollDistanceAvailable)
                    .clamp(0.0, 1.0);
            return Transform.scale(
              scale: bgscale,
              alignment: const Alignment(0, 0),
              child: BgImage(image: image, opacity: bgOpacity),
            );
          },
        ),
        // 刷新
        RefreshIndicator(
          onRefresh: () => _onRefresh(context),
          // 顶部渐隐遮罩，隐藏状态栏下方内容
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black],
                stops: [
                  _statusBarHeight / _screenHeight,
                  (_statusBarHeight + Config.searchBarHeight) / _screenHeight,
                ], // 渐变高度可调
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: CustomScrollView(
              controller: scrollController,
              physics: BouncingScrollPhysics(),
              slivers: [
                // 顶部空白区域
                SliverToBoxAdapter(child: SizedBox(height: _initScoreListTop)),
                // 列表
                ValueListenableBuilder(
                  valueListenable: _scores,
                  builder: (context, scores, child) {
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => scores[index].toTitleCard(context),
                        childCount: scores.length,
                      ),
                    );
                  },
                ),
                // 底部提示
                SliverToBoxAdapter(
                  child: ValueListenableBuilder(
                    valueListenable: _scores,
                    builder: (context, scores, child) {
                      if (_issueRequester.isLoading) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (_scores.value.isEmpty) {
                        return Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                _fetchScores(context, reset: true);
                              },
                              child: Image.asset(
                                'assets/error.png',
                                width: MediaQuery.of(context).size.width / 1.8,
                              ),
                            ),
                            const Text(
                              '啊哦，网络出问题了\n点击图片重试',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      }
                      if (_issueRequester.hasNext) {
                        return SizedBox(
                          height:
                              kBottomNavigationBarHeight +
                              Config.navBarTopPadding,
                          child: Text(
                            '加载更多 (ฅ´ω`ฅ)',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return SizedBox(
                        height:
                            kBottomNavigationBarHeight +
                            Config.navBarTopPadding,
                        child: Text(
                          '没有更多啦 ╮(๑•́ ₃•̀๑)╭',
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // 下载按钮
        Positioned(
          top: 40,
          left: 20,
          child: IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: () async {
              if (_bgImageNotifier.value == null) return;
              final result = await ImageUtils.saveImageToGallery(
                image: _bgImageNotifier.value,
              );
              if (!context.mounted) return;
              ImageUtils.uiResult(result, context);
            },
          ),
        ),
        // 搜索框 用遮罩挡起来
        ValueListenableBuilder<double>(
          valueListenable: scrollOffsetNotifier,
          builder: (context, value, child) {
            return Positioned(
              top:
                  _initialSearchBarTop -
                  (scrollOffsetNotifier.value * _searchBarSpeedRatio).clamp(
                    -double.infinity,
                    _searchBarTravelDistance,
                  ),
              left: 0,
              right: 0,
              child: child!,
            );
          },
          child: heroSearchBar,
        ),
      ],
    );
  }

  Future<void> searchPage(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: Duration(milliseconds: Config.home2searchDuration),
        reverseTransitionDuration: Duration(
          milliseconds: Config.home2searchDuration,
        ),
        transitionsBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child,
            ) {
              // 组合 SlideTransition + FadeTransition
              final offsetAnimation =
                  Tween<Offset>(
                    begin: const Offset(0, -0.1), // 上方进入
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                      reverseCurve: Curves.easeInOut,
                    ),
                  );
              final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.linear,
                  reverseCurve: Curves.linear,
                ),
              );
              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(opacity: fadeAnimation, child: child),
              );
            },
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return Search(focusNode: focusNode);
            },
      ),
    );
  }
}

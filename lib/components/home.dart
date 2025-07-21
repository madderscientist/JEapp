import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:async';
import 'bgimg.dart';
import '../config.dart';
import 'searchbar.dart';
import 'search.dart';
import '../utils/image.dart';
import '../utils/score_request.dart';
import 'package:toastification/toastification.dart';

class Home extends StatefulWidget {
  final ScrollController? scrollController;
  final void Function(bool)? ifToTop;
  const Home({super.key, this.ifToTop, this.scrollController});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  final focusNode = FocusNode(); // 跨屏幕键盘
  bool _allowFocus = false; // 超级保险，不让搜索框获取焦点
  // 外部控制滚动位置
  late ScrollController scrollController =
      widget.scrollController ?? ScrollController();
  double _scrollOffset = 0.0;
  bool _show2top = false;

  // 以下是和屏幕尺寸有关，视为某个屏幕大小下的常量，在didChangeDependencies中更新
  late double _screenHeight;
  late double _statusBarHeight;
  late double _initialSearchBarTop;
  late double _initScoreListTop;
  late double _searchBarTravelDistance;
  late double _listTravelDistance;
  late double _searchBarSpeedRatio;

  double get _searchBarTop =>
      _initialSearchBarTop -
      (_scrollOffset * _searchBarSpeedRatio).clamp(
        -double.infinity,
        _searchBarTravelDistance,
      );

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
    _listTravelDistance =
        _initScoreListTop - _statusBarHeight - Config.searchBarHeight;
    _searchBarSpeedRatio = _searchBarTravelDistance / _listTravelDistance;
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = scrollController.offset;
      final bool show2top = _scrollOffset > _initScoreListTop;
      if (_show2top != show2top) {
        _show2top = show2top;
        widget.ifToTop?.call(show2top);
      }
    });
    if (scrollController.position.pixels >
            scrollController.position.maxScrollExtent - 200 &&
        _issueRequester.isLoading == false) {
      _fetchScores(context);
    }
  }

  static const String _localBgURL = 'assets/homebg.jpg';
  final ValueNotifier<ui.Image?> _bgImageNotifier = ValueNotifier(null);
  double get _bgOpacity =>
      ((_initScoreListTop - _statusBarHeight - _scrollOffset) /
              (_initScoreListTop - _statusBarHeight))
          .clamp(0.0, 1.0);
  double get _bgscale =>
      _scrollOffset > 0 ? 1.0 : (1.0 - _scrollOffset / _screenHeight);

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
          _bgImageNotifier.value = img;
        })
        .catchError((_) {
          debugPrint('Failed to load remote image: $url');
        }); // 网络失败不处理，保持之前的图片
  }

  final IssueRequester _issueRequester = IssueRequester(perPage: 20);
  final List<RawScore> _scores = [];
  Future<void> _fetchScores(BuildContext context, {bool reset = false}) async {
    try {
      final result = await _issueRequester.fetchIssues(reset: reset);
      if (reset) _scores.clear();
      setState(() => _scores.addAll(result));
    } catch (e) {
      if (!context.mounted) return;
      setState(() {});
      toastification.show(
        context: context,
        type: ToastificationType.error,
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

  Widget get _buttomTip {
    if (_issueRequester.isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_scores.isEmpty) {
      return Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _fetchScores(context, reset: true);
              });
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
        height: kBottomNavigationBarHeight + Config.navBarTopPadding,
        child: Text('加载更多 (ฅ´ω`ฅ)', textAlign: TextAlign.center),
      );
    }
    return SizedBox(
      height: kBottomNavigationBarHeight + Config.navBarTopPadding,
      child: Text('没有更多啦 ╮(๑•́ ₃•̀๑)╭', textAlign: TextAlign.center),
    );
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
    _bgImageNotifier.dispose();
    _issueRequester.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setBG();
      _fetchScores(context, reset: true);
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
            return Transform.scale(
              scale: _bgscale,
              alignment: Alignment(0, 0),
              child: BgImage(image: image, opacity: _bgOpacity),
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
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) => false,
              child: CustomScrollView(
                controller: scrollController,
                physics: BouncingScrollPhysics(),
                slivers: [
                  // 顶部空白区域
                  SliverToBoxAdapter(
                    child: SizedBox(height: _initScoreListTop),
                  ),
                  // 列表
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _scores[index].toTitleCard(context),
                      childCount: _scores.length,
                    ),
                  ),
                  SliverToBoxAdapter(child: _buttomTip),
                ],
              ),
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
        Positioned(top: _searchBarTop, left: 0, right: 0, child: heroSearchBar),
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

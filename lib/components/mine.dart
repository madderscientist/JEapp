import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:path/path.dart' as p;
import '../config.dart';
import '../theme.dart';
import 'detail.dart';
import 'github_login.dart';
import 'settings.dart';
import '../utils/image.dart' show ImageUtils;

class Mine extends StatefulWidget {
  const Mine({super.key});

  @override
  State<Mine> createState() => _MineState();
}

class _MineState extends State<Mine> {
  final TextEditingController _controller = TextEditingController();
  List<File> get _allScores => Config.localScores.value;
  late final ValueNotifier<List<int>> filteredScores;

  @override
  void initState() {
    super.initState();
    filteredScores = ValueNotifier(List.generate(_allScores.length, (i) => i));
    _controller.addListener(_filter);
    Config.localScores.addListener(_filter);
  }

  @override
  void dispose() {
    _controller.dispose();
    Config.localScores.removeListener(_filter);
    filteredScores.dispose();
    super.dispose();
  }

  void _filter() {
    final keyword = _controller.text.trim().toLowerCase();
    final files = _allScores;
    filteredScores.value = List.generate(files.length, (i) => i).where((i) {
      final name = p.basenameWithoutExtension(files[i].path);
      return name.toLowerCase().contains(keyword);
    }).toList();
  }

  void _delete(File f, BuildContext context) {
    Config.deleteLocalScore(f)
        .then((_) {
          if (!context.mounted) return;
          ImageUtils.uiResult({
            'isSuccess': true,
            'title': '删除成功',
            'message': '《${p.basenameWithoutExtension(f.path)}》已删除',
          }, context);
        })
        .catchError((e) {
          if (!context.mounted) return;
          ImageUtils.uiResult({
            'isSuccess': false,
            'title': '删除失败',
            'message': '《${p.basenameWithoutExtension(f.path)}》删除失败: $e',
          }, context);
        });
  }

  void _share(File f, BuildContext context) async {
    final params = ShareParams(text: 'Great picture', files: [XFile(f.path)]);
    final result = await SharePlus.instance.share(params);
    if (result.status == ShareResultStatus.success) {
      if (context.mounted) {
        ImageUtils.uiResult({
          'isSuccess': true,
          'title': '分享成功',
          'message': '《${p.basename(f.path)}》已分享',
        }, context);
      }
    } else {
      if (context.mounted) {
        ImageUtils.uiResult({
          'isSuccess': false,
          'title': '分享失败',
          'message': '《${p.basename(f.path)}》分享失败',
        }, context);
      }
    }
  }

  void _issue(File f, BuildContext context) async {
    if (Config.githubToken.isEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            ImageUtils.uiResult({
              'isSuccess': null,
              'title': '你还未登录GitHub账号',
              'message': '进入登录流程！',
            }, context);
            return const GitHubLogin();
          },
        ),
      );
      if (!context.mounted) return;
    }
    final token = Config.githubToken;
    if (token.isEmpty) {
      ImageUtils.uiResult({
        'isSuccess': false,
        'title': '发布失败',
        'message': '请先登录GitHub账号',
      }, context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发布到谱库'),
        content: const Text('请确认曲谱没有重复'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('发布'),
          ),
        ],
      ),
    );
    if (confirmed == false) return;
    final title = p.basenameWithoutExtension(f.path);
    final body = await f.readAsString();
    if (!context.mounted) return;
    // 显示全屏加载动画
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    createIssue(token, title, body)
        .then((response) {
          if (!context.mounted) return;
          if (response.statusCode == 201) {
            ImageUtils.uiResult({
              'isSuccess': true,
              'title': '发布成功',
              'message': '《$title》已发布到谱库',
            }, context);
          } else {
            ImageUtils.uiResult({
              'isSuccess': false,
              'title': '发布失败',
              'message': '${response.statusCode} ${response.body}',
            }, context);
          }
        })
        .catchError((e) {
          if (!context.mounted) return;
          ImageUtils.uiResult({
            'isSuccess': false,
            'title': '发布失败',
            'message': e.toString(),
          }, context);
        })
        .whenComplete(() {
          if (!context.mounted) return;
          Navigator.of(context, rootNavigator: true).pop();
        });
  }

  @override
  Widget build(BuildContext context) {
    const double appBarHeight = 190; // AppBar的最大高度[不包括状态栏]
    const double extendHeight = 9; // Header的扩展高度
    const double appBarRealHeight = appBarHeight + extendHeight; // AppBar的实际高度
    const double avatarMax = 76;
    const double avatarMin = 36;
    const double deltaAvatar = avatarMax - avatarMin;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double toolBarHeight =
        kToolbarHeight + statusBarHeight; // [包含状态栏]最小高度
    const double threshold = 0.15;
    const double headIconSize = 36;
    const Color purple = AppTheme.color;
    final titleTheme = Theme.of(context).textTheme.bodyMedium;
    final dateTheme = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.grey);

    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: appBarRealHeight,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: LayoutBuilder(
            builder: (context, constraints) {
              // constraints.maxHeight [包含状态栏高度]
              final percent =
                  ((constraints.maxHeight - toolBarHeight) /
                          (appBarRealHeight + statusBarHeight - toolBarHeight))
                      .clamp(0.0, 1.0);
              final avatarSize = avatarMin + deltaAvatar * percent;
              // 保证在去掉状态栏后垂直居中 实际稍偏上
              final avatarTop =
                  statusBarHeight -
                  extendHeight +
                  (kToolbarHeight - avatarMin) / 2 +
                  percent * (appBarHeight - kToolbarHeight - deltaAvatar) / 2;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // 背景图视差 用cover实现
                  Image.asset('assets/minebg.jpg', fit: BoxFit.cover),
                  // 底部 Header 的侵入区域
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      height: extendHeight,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(extendHeight),
                          topRight: Radius.circular(extendHeight),
                        ),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 头像和文字
                  ValueListenableBuilder<UserInfo?>(
                    valueListenable: Config.userInfoNotifier,
                    builder: (context, userinfo, _) {
                      late final ImageProvider imageProvider;
                      late final String userName;
                      late final Widget smallInfo;
                      final smallStyle = Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey);
                      if (userinfo == null) {
                        imageProvider = const AssetImage('assets/icon.png');
                        userName = '未登录的JE酱';
                        smallInfo = GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const GitHubLogin(),
                              ),
                            );
                          },
                          child: Text('点我登录', style: smallStyle),
                        );
                      } else {
                        imageProvider = CachedNetworkImageProvider(
                          userinfo.avatarUrl,
                        );
                        userName = userinfo.name.isNotEmpty
                            ? userinfo.name
                            : userinfo.login;
                        smallInfo = Text(userinfo.login, style: smallStyle);
                      }
                      return Positioned(
                        left: 24,
                        top: avatarTop,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: avatarSize,
                              height: avatarSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            AnimatedSize(
                              duration: Duration(milliseconds: 330),
                              curve: Curves.easeInOut,
                              child: AnimatedSwitcher(
                                duration: Duration(milliseconds: 330),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                child: percent > threshold
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userName,
                                            key: ValueKey(userName),
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          smallInfo,
                                        ],
                                      )
                                    : Text(
                                        '我的曲谱',
                                        key: ValueKey('mine'),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // 设置按钮 颜色渐变
                  Positioned(
                    top:
                        statusBarHeight -
                        extendHeight +
                        (kToolbarHeight - headIconSize) / 2,
                    right: 18,
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        begin: Colors.white,
                        end: percent < threshold ? Colors.white : purple,
                      ),
                      duration: Duration(milliseconds: 330),
                      builder: (context, color, child) => SizedBox(
                        width: headIconSize,
                        height: headIconSize,
                        child: IconButton(
                          icon: Icon(Icons.settings, size: 28, color: color),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const Settings(),
                              ),
                            );
                          },
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
            maxExtent: headIconSize + extendHeight,
            minExtent: headIconSize + extendHeight,
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.only(
                bottom: extendHeight,
                left: extendHeight,
                right: extendHeight,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFDDDDDD), width: 0.3),
                ),
              ),
              child: Row(
                spacing: 6,
                children: [
                  // 刷新按钮
                  SizedBox(
                    width: headIconSize,
                    height: headIconSize,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: CircleBorder(),
                        side: BorderSide(color: purple, width: 1.2),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () async {
                        await Config.initLocalScores();
                        if (!context.mounted) return;
                        ImageUtils.uiResult({
                          'isSuccess': true,
                          'title': '刷新完毕 (๑•̀ㅂ•́)و✧',
                          'message': null,
                        }, context);
                      },
                      child: const Icon(Icons.refresh, color: purple, size: 22),
                    ),
                  ),
                  // 新建按钮
                  SizedBox(
                    width: headIconSize,
                    height: headIconSize,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: CircleBorder(),
                        side: BorderSide(color: purple, width: 1.2),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                Detail(title: '新建曲谱', raw: null, local: null),
                          ),
                        );
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      child: const Icon(Icons.add, color: purple, size: 22),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      decoration: InputDecoration(
                        border: AppTheme.headOutlineInputBorder,
                        focusedBorder: AppTheme.headOutlineInputBorder,
                        enabledBorder: AppTheme.headOutlineInputBorder,
                        hintText: '搜索本地曲谱',
                        hintStyle: TextStyle(color: purple.withAlpha(128)),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 3,
                          horizontal: 16,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.clear, color: purple),
                          onPressed: () {
                            _controller.clear();
                            _filter();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ValueListenableBuilder<List<int>>(
          valueListenable: filteredScores,
          builder: (context, indices, _) {
            if (indices.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Image.asset(
                    'assets/noresult.png',
                    width: MediaQuery.of(context).size.width / 1.8,
                  ),
                ),
              );
            }
            final files = _allScores;
            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final fileIdx = indices[index];
                final file = files[fileIdx];
                final name = p.basenameWithoutExtension(file.path);
                final date = file.statSync().modified;
                final slidableActions = [
                      SlidableAction(
                        padding: EdgeInsets.all(0),
                        onPressed: (context) {
                          _issue(file, context);
                        },
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.white,
                        icon: Icons.upload,
                        label: '上传',
                      ),
                      SlidableAction(
                        padding: EdgeInsets.all(0),
                        onPressed: (context) {
                          _share(file, context);
                        },
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        icon: Icons.share,
                        label: '分享',
                      ),
                      SlidableAction(
                        padding: EdgeInsets.all(0),
                        onPressed: (context) {
                          _delete(file, context);
                        },
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: '删除',
                      ),
                    ];
                final inner = Slidable(
                  key: ValueKey(file.path),
                  endActionPane: ActionPane(
                    motion: DrawerMotion(),
                    extentRatio: 0.2 * slidableActions.length,
                    children: slidableActions,
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(name, style: titleTheme),
                    subtitle: Text(
                      "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}",
                      style: dateTheme,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 0,
                    ),
                  ),
                );
                final opencontainer = OpenContainer(
                  transitionDuration: const Duration(milliseconds: 450),
                  transitionType: ContainerTransitionType.fade,
                  openBuilder: (context, _) =>
                      Detail(title: name, raw: null, local: file),
                  openElevation: 0,
                  closedElevation: 0,
                  closedShape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(0)),
                  ),
                  closedColor: Colors.white,
                  closedBuilder: (context, openContainer) => inner,
                );
                return Column(
                  children: [
                    opencontainer,
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 16,
                      endIndent: 16,
                    ),
                  ],
                );
              }, childCount: indices.length),
            );
          },
        ),
        // 底部占位
        SliverToBoxAdapter(
          child: SizedBox(
            height: kBottomNavigationBarHeight + Config.navBarTopPadding,
          ),
        ),
      ],
    );
  }
}

// SliverPersistentHeaderDelegate实现
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  @override
  final double minExtent;
  @override
  final double maxExtent;
  _HeaderDelegate({
    required this.child,
    this.minExtent = 64,
    this.maxExtent = 64,
  });
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) => false;
}

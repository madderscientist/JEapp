import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';

class MySearchBar extends StatelessWidget {
  final bool inputMode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onBack;
  final VoidCallback? onTap;
  final VoidCallback? onSearch;
  final void Function(PointerDownEvent)? onTapOutside;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  const MySearchBar({
    super.key,
    required this.inputMode,
    this.onChanged,
    this.onBack,
    this.onTap,
    this.onSearch,
    this.onTapOutside,
    this.controller,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double fontSize = Config.searchBarHeight / 3;
    final searchbar = SearchBar(
      onTapOutside: onTapOutside,
      controller: controller,
      focusNode: focusNode,
      autoFocus: inputMode, // 一定得打开，不然新页面无法聚焦
      hintText: '要找什么谱呢 |･ω･｀)',
      elevation: WidgetStateProperty.all(3),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      shadowColor: WidgetStateProperty.all(
        Theme.of(context).colorScheme.primary.withAlpha(100),
      ),
      constraints: const BoxConstraints(
        minHeight: Config.searchBarHeight,
        maxHeight: Config.searchBarHeight,
      ),
      leading: IconButton(
        icon: inputMode
            ? const Icon(Icons.chevron_left, color: Colors.grey)
            : const Icon(Icons.chevron_right, color: Colors.grey),
        visualDensity: VisualDensity.compact,
        onPressed: onBack,
      ),
      trailing: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.grey),
          visualDensity: VisualDensity.compact,
          onPressed: onSearch,
        ),
      ],
      onChanged: onChanged,
      onTap: onTap,
      onSubmitted: (_) => onSearch?.call(),
      backgroundColor: WidgetStateProperty.all(Colors.white),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: const BorderSide(color: Colors.purple, width: 2),
        ),
      ),
      textStyle: WidgetStateProperty.all(
        theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontSize: fontSize,
        ),
      ),
      hintStyle: WidgetStateProperty.all(
        theme.textTheme.bodyLarge?.copyWith(
          color: Colors.grey,
          fontSize: fontSize,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Config.searchBarPadding,
        vertical: 0,
      ),
      child: inputMode
          ? searchbar
          // 拦截点击事件
          : GestureDetector(
              onTap: onTap,
              child: AbsorbPointer(child: searchbar),
            ),
    );
  }
}

/// A widget that automatically resizes to the keyboard height
/// 当键盘弹出时关闭页面，键盘会先下降，导致退出动画跟着下降。所以需要一个占位
/// 需要配合 `resizeToAvoidBottomInset: false` 使用
class KeyboardSpacer extends StatefulWidget {
  const KeyboardSpacer({
    super.key,
    this.collapseRightNow = true,
    this.initExpanded = false,
    this.onCollapse,
    this.onExpand,
    this.onUpdate,
  });
  final bool collapseRightNow; // 是否立即相应键盘收起
  final bool initExpanded; // 是否初始展开
  final void Function()? onCollapse; // 键盘收起时的回调
  final void Function()? onExpand; // 键盘展开时的回调
  final void Function(double)? onUpdate; // 键盘高度更新时的回调

  @override
  State<KeyboardSpacer> createState() => _KeyboardSpacerState();
}

const double _minKeyboardHeight = 0.02; // 最小高度，避免被渲染优化搞成0

class _KeyboardSpacerState extends State<KeyboardSpacer>
    with WidgetsBindingObserver {
  double _lastBottomInset = 0;
  double _bottomHeight = 0;
  Timer? _timer; // 防抖

  // 收起键盘的判断
  int _downTimes = 0;
  static const int collapseTimes = 2; // 连续下降collapseTimes次则判断为收起键盘

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 如果初始展开，且高度为0（意味着Config没有值），则设置为屏幕的1/3
    // 当别的页面pop回来时，可能也会调用。所以还需要判断Config.keyboardHeight
    if (widget.initExpanded && _bottomHeight <= _minKeyboardHeight) {
      _bottomHeight = Config.keyboardHeight > _minKeyboardHeight
          ? Config.keyboardHeight
          : MediaQuery.of(context).size.height / 3;
    } else {
      _bottomHeight = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = View.of(context);
    final toBottom = view.viewInsets.bottom / view.devicePixelRatio;
    // final toBottom = MediaQuery.of(context).viewInsets.bottom; // 这个拿到的是上次的高度，因为Media还没更新
    if (_bottomHeight <= _minKeyboardHeight && toBottom > _minKeyboardHeight && _downTimes < collapseTimes) {
      // 说明刚开始展开，需要在展开前到位
      setState(() {
        _bottomHeight = Config.keyboardHeight;
      });
      widget.onExpand?.call();
    }
    // 说明有可能是键盘高度变化
    if (toBottom != _lastBottomInset) {
      // 检测是否是收起键盘 通过连续多次下降判断
      if (toBottom < _lastBottomInset && widget.collapseRightNow) {
        if (_downTimes <= collapseTimes) {
          _downTimes++; // 记录收起键盘的次数
        }
        if (_downTimes == collapseTimes) {
          setState(() {
            // 收起键盘 如果设置成0会有问题，可能会被渲染优化搞
            _bottomHeight = _minKeyboardHeight / 2;
          });
          widget.onCollapse?.call();
        }
      } else {
        _downTimes = 0;
      }
      _lastBottomInset = toBottom; // 更新上一次的底部间距
      // 防抖。回调函数在键盘动画结束后触发
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return; // 因为是异步的
        setState(() {
          _bottomHeight = _lastBottomInset;
          // 当展开完全时更新键盘高度
          if (_lastBottomInset > _minKeyboardHeight &&
              Config.keyboardHeight != _bottomHeight) {
            Config.keyboardHeight = _bottomHeight;
          }
          _downTimes = 0;
          widget.onUpdate?.call(_lastBottomInset);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: Config.keyboardAnimationDuration),
      curve: Curves.fastEaseInToSlowEaseOut,
      height: _bottomHeight,
    );
  }
}

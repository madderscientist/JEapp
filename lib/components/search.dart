import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'searchbar.dart';
import 'dart:async';
import '../config.dart';
import 'capsule_selector.dart';
import '../utils/score_request.dart';
import 'search_results.dart';

class Search extends StatefulWidget {
  final FocusNode? focusNode;
  const Search({super.key, this.focusNode});

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  final myFocus = FocusNode();
  final TextEditingController controller = TextEditingController();
  ValueNotifier<bool> collapseRightNow = ValueNotifier<bool>(true);
  ValueNotifier<int> selectedSourceIndex = ValueNotifier<int>(0);
  static const List<String> jeSources = ["Github", "Acgmuse"];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 这段代码很关键
    Future.microtask(() {
      if (mounted) {
        widget.focusNode?.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    myFocus.dispose();
    super.dispose();
  }

  Future<void> _search() {
    Config.addHistory(controller.text);
    FocusManager.instance.primaryFocus?.unfocus();
    final request = selectedSourceIndex.value == 0
        ? ScoreSearcher.github(controller.text)
        : ScoreSearcher.acgmuse(controller.text);
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SearchResultsList(request: request, title: controller.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroSearchBar = Hero(
      tag: Config.searchBarHeroTag,
      transitionOnUserGestures: true,
      child: MySearchBar(
        inputMode: true,
        controller: controller,
        focusNode: myFocus,
        // focusNode: widget.focusNode, // 不能用！用了就会导致焦点不出现
        onBack: () {
          collapseRightNow.value = false;
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.of(context).pop();
        },
        onSearch: () {
          if (controller.text.isEmpty) {
            toastification.show(
              context: context,
              type: ToastificationType.warning,
              style: ToastificationStyle.flatColored,
              title: Text('`(*>﹏<*)′'),
              description: Text('还没告诉JE酱要找什么呢'),
              alignment: Alignment.topCenter,
              autoCloseDuration: const Duration(seconds: 2),
              borderRadius: BorderRadius.circular(12.0),
              showProgressBar: false,
              dragToClose: true,
              applyBlurEffect: true,
            );
            return;
          }
          // KeyboardSpacer的didChangeDependencies会被再次触发，导致其弹起，所以需要focus让键盘跟进
          _search().then((_) {
            myFocus.requestFocus();
            Future.microtask(() {
              if (mounted) {
                myFocus.requestFocus();
              }
            });
          });
        },
      ),
    );
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder<List<String>>(
                valueListenable: Config.history,
                builder: (context, history, child) {
                  return SearchHistoryList(
                    history: history,
                    onSelect: (h) {
                      controller.text = h;
                      _search();
                    },
                    onEdit: (h) {
                      controller.text = h;
                      myFocus.requestFocus();
                    },
                    onDelete: (h) {
                      Config.deleteHistory(h);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Row(
                children: [
                  Text("谱库:  "),
                  ValueListenableBuilder<int>(
                    valueListenable: selectedSourceIndex,
                    builder: (context, value, child) {
                      return CapsuleSelector(
                        items: jeSources,
                        selectedIndex: value,
                        onChanged: (index) => selectedSourceIndex.value = index,
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: heroSearchBar,
            ),
            ValueListenableBuilder<bool>(
              valueListenable: collapseRightNow,
              builder: (context, value, child) {
                return KeyboardSpacer(
                  initExpanded: true,
                  collapseRightNow: value,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// @brief 显示在搜索框上方的历史记录列表
class SearchHistoryList extends StatelessWidget {
  const SearchHistoryList({
    super.key,
    required this.history,
    this.onEdit, // 点击了箭头
    this.onSelect, // 点击了历史本身
    this.onDelete, // 删除历史
  });

  final List<String> history;
  final void Function(String)? onEdit; // 点击箭头（编辑）
  final void Function(String)? onSelect; // 点击历史本身
  final void Function(String)? onDelete; // 删除历史

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const divider = Divider(
      height: 1,
      color: Color(0xFFE0E0E0),
      indent: 18,
      endIndent: 18,
    );
    return ListView.separated(
      padding: const EdgeInsets.only(top: 50),
      reverse: true, // 让列表反向显示，最近的在下方，因为搜索框在下方
      itemCount: history.length,
      itemBuilder: (context, index) {
        final h = history[index];
        return ListTile(
          dense: true, // 和Edge对齐
          title: GestureDetector(
            onTap: () => onSelect?.call(h),
            child: Text(
              h,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.south_west, color: theme.colorScheme.primary),
                visualDensity: VisualDensity.compact,
                onPressed: () => onEdit?.call(h),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => onDelete?.call(h),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (context, index) => divider,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toastification/toastification.dart';

/// 长按弹出气泡，点击其他地方关闭 模仿网易云音乐
class LongPressCopyBubble extends StatefulWidget {
  final String text;
  final TextStyle? textStyle;
  final TextStyle? bubbleTextStyle;
  final Color bubbleColor;
  final EdgeInsetsGeometry padding;
  final double? bubbleMaxWidth;

  const LongPressCopyBubble({
    super.key,
    required this.text,
    this.textStyle,
    this.bubbleTextStyle = const TextStyle(color: Colors.white, fontSize: 15),
    this.bubbleColor = Colors.black87,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.bubbleMaxWidth,
  });

  @override
  State<LongPressCopyBubble> createState() => _LongPressCopyBubbleState();
}

class _LongPressCopyBubbleState extends State<LongPressCopyBubble> {
  OverlayEntry? _overlayEntry;

  void _showBubble(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.of(context);
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;
    final double maxWidth = widget.bubbleMaxWidth ?? (screenWidth / 2);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            left: position.dx,
            top: position.dy + size.height + 8,
            child: Material(
              color: Colors.transparent,
              child: TapRegion(
                onTapOutside: (event) => _removeBubble(),
                child: Container(
                  constraints: BoxConstraints(minWidth: 0, maxWidth: maxWidth),
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    color: widget.bubbleColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 用最小宽度，超过最大宽度则自动换行
                      Flexible(
                        child: Text(
                          widget.text,
                          style: widget.bubbleTextStyle,
                          softWrap: true,
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.text),
                          );
                          if (context.mounted) {
                            toastification.show(
                              context: context,
                              style: ToastificationStyle.simple,
                              title: Text("已复制 (￣▽￣)V"),
                              backgroundColor: Colors.black87,
                              foregroundColor: Colors.white,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: const Duration(seconds: 2),
                              borderRadius: BorderRadius.circular(12.0),
                              showProgressBar: false,
                              dragToClose: true,
                              applyBlurEffect: false,
                            );
                          }
                          _removeBubble();
                        },
                        child: const Icon(
                          Icons.copy,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeBubble() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeBubble();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (childContext) => GestureDetector(
        onLongPress: () => _showBubble(childContext),
        child: Text(widget.text, style: widget.textStyle),
      ),
    );
  }
}

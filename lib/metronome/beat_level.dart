import 'package:flutter/material.dart';

/// 调节重拍
class BeatLevel extends StatefulWidget {
  final int id;
  final int level;
  final void Function(int)? onTap;
  final ValueNotifier<int> beatTick;

  const BeatLevel({
    super.key,
    required this.id,
    required this.level,
    this.onTap,
    required this.beatTick,
  });

  @override
  State<BeatLevel> createState() => _BeatLevelState();
}

class _BeatLevelState extends State<BeatLevel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 300),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    widget.beatTick.addListener(_onBeat);
  }

  void _onBeat() {
    if (widget.beatTick.value != widget.id) return;
    _controller.reverse(from: 1.0);
  }

  @override
  void dispose() {
    widget.beatTick.removeListener(_onBeat);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: GestureDetector(
        onTap: () => widget.onTap?.call((widget.level + 1) % 4),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 60),
          margin: const EdgeInsets.symmetric(horizontal: 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final filled = i >= 3 - widget.level;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final curve = Curves.easeOut.transform(_controller.value);
                  final color = filled
                      ? Color.lerp(
                          Theme.of(context).colorScheme.primary,
                          Colors.lightBlueAccent,
                          curve,
                        )
                      : Colors.transparent;
                  return Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

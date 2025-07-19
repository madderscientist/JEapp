import 'package:flutter/material.dart';
import '../config.dart';

class CapsuleSelector extends StatelessWidget {
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const CapsuleSelector({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryDark = Colors.purple;
    final primary = theme.colorScheme.primaryContainer;
    final textTheme = theme.textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(items.length, (i) {
        final bool selected = i == selectedIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.0),
          child: GestureDetector(
            onTap: () {
              if (i != selectedIndex) onChanged(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? primary : Colors.grey[300],
                border: Border.all(
                  color: selected ? primaryDark : Colors.grey[400]!,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                items[i],
                style: textTheme.headlineMedium?.copyWith(
                  color: selected ? primaryDark : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: Config.capsuleFontSize,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

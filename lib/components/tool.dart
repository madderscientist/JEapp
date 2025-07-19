import 'package:flutter/material.dart';
import '../mdEditor/panel.dart';

class Tool extends StatelessWidget {
  const Tool({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 6.0,
        mainAxisSpacing: 6.0,
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('转调器')),
                    resizeToAvoidBottomInset: false,
                    body: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: const Panel(),
                      ),
                    ),
                  ),
                ),
              ).then((_) {
                if (context.mounted) FocusScope.of(context).unfocus();
              });
            },
            child: const Text('转调器'),
          ),
          ElevatedButton(onPressed: () {}, child: const Text('调音器')),
          ElevatedButton(onPressed: () {}, child: const Text('节拍器')),
        ],
      ),
    );
  }
}

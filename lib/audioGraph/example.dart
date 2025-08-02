import 'package:flutter/material.dart';
import 'note.dart';
import '../utils/freq_table.dart';

void main() {
  runApp(MaterialApp(home: const TestPage()));
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  late final NoteManager n;
  final freqTable = FreqTable();
  int midiNote = 60; // 中央C
  Note? note;
  @override
  void initState() {
    super.initState();
    n = NoteManager();
    n.init();
  }

  @override
  void dispose() {
    n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Page')),
      body: Center(
        child: Column(
          children: [
            Listener(
              onPointerDown: (_) {
                note = n.play(f: freqTable[midiNote], last: 3);
                // play next note
                midiNote = (midiNote + 1) % freqTable.length;
              },
              onPointerUp: (_) {
                if (note != null) {
                  n.stop(note!);
                  note = null;
                }
              },
              child: const Text('Play Note'),
            ),
          ],
        ),
      ),
    );
  }
}

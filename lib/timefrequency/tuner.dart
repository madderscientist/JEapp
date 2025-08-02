import 'package:flutter/material.dart';
import 'package:je/utils/freq_table.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'time_frequency.dart';

class Tuner extends StatefulWidget {
  const Tuner({super.key});
  @override
  State<Tuner> createState() => _TunerState();
}

class _TunerState extends State<Tuner> {
  final ValueNotifier<double> freqNotifier = ValueNotifier(-1);
  final ValueNotifier<String> noteNotifier = ValueNotifier<String>('');
  final FreqTable freqTable = FreqTable();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    freqNotifier.dispose();
    noteNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<double>(
          valueListenable: freqNotifier,
          builder: (context, value, child) {
            if (value < 0) {
              return Text("??? Hz");
            }
            return Text('${value.toStringAsFixed(2)} Hz');
          },
        ),
        Expanded(
          child: Stack(
            children: [
              Center(
                child: ValueListenableBuilder(
                  valueListenable: noteNotifier,
                  builder: (context, value, child) {
                    return Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    );
                  },
                ),
              ),
              TimeFrequency(
                freqNotifier: freqNotifier,
                freqTable: freqTable,
              ),
            ],
          ),
        ),
        _buildHead(),
      ],
    );
  }

  Widget _buildHead() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(32),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      margin: EdgeInsets.only(top: 4),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Center(child: Text('调音器')),
    );
  }
}

import 'package:flutter/material.dart';

class TempTextArea extends StatefulWidget {
  final TextEditingController controller;
  final bool expands;
  final int? maxLines;
  final InputDecoration? decoration;
  final void Function() onDispose;
  final TextInputType keyboardType;
  final bool autofocus;
  const TempTextArea({
    super.key,
    required this.controller,
    required this.onDispose,
    this.expands = true,
    this.maxLines,
    this.decoration,
    this.keyboardType = TextInputType.multiline,
    this.autofocus = false,
  });

  @override
  State<TempTextArea> createState() => _TempTextAreaState();
}

class _TempTextAreaState extends State<TempTextArea> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: Theme.of(context).textTheme.bodyMedium,
      controller: widget.controller,
      decoration: widget.decoration,
      maxLines: widget.maxLines,
      expands: widget.expands,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: widget.keyboardType,
      autofocus: widget.autofocus,
    );
  }
}
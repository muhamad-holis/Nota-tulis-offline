import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class LiveField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onCommit;
  final bool multiline;
  final int rows;
  final String? placeholder;

  const LiveField({
    super.key,
    required this.value,
    required this.onCommit,
    this.multiline = false,
    this.rows = 2,
    this.placeholder,
  });

  @override
  State<LiveField> createState() => _LiveFieldState();
}

class _LiveFieldState extends State<LiveField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant LiveField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      widget.onCommit(_controller.text);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: widget.multiline ? widget.rows : 1,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        filled: true,
        fillColor: AppColors.slate50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      style: const TextStyle(fontSize: 13),
      onSubmitted: (v) => widget.onCommit(v),
    );
  }
}

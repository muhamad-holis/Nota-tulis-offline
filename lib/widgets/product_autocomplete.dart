import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../providers/nota_draft_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class ProductAutocomplete extends ConsumerStatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<Product> onSelectProduct;
  final VoidCallback onEnter;
  final bool autoFocus;
  final FocusNode? focusNode;

  const ProductAutocomplete({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onSelectProduct,
    required this.onEnter,
    this.autoFocus = false,
    this.focusNode,
  });

  @override
  ConsumerState<ProductAutocomplete> createState() => _ProductAutocompleteState();
}

class _ProductAutocompleteState extends ConsumerState<ProductAutocomplete> {
  final LayerLink _link = LayerLink();
  late final FocusNode _focusNode;
  late TextEditingController _controller;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant ProductAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = _controller.value.copyWith(text: widget.value);
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 120), _removeOverlay);
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 220,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(0, 44),
          child: Consumer(
            builder: (context, ref, _) {
              final query = _controller.text.trim();
              if (query.isEmpty) return const SizedBox.shrink();
              final suggestionsAsync = ref.watch(productSuggestionsProvider(query));
              return suggestionsAsync.when(
                data: (suggestions) {
                  if (suggestions.isEmpty) return const SizedBox.shrink();
                  return Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        children: [
                          for (final p in suggestions)
                            InkWell(
                              onTap: () {
                                widget.onSelectProduct(p);
                                _controller.text = p.name;
                                _focusNode.unfocus();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                        child: Text(p.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 13, color: AppColors.slate700))),
                                    Text(formatRupiah(p.price),
                                        style: TextStyle(fontSize: 13, color: AppColors.slate400)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autoFocus,
        decoration: const InputDecoration(
          hintText: 'Nama barang',
          border: InputBorder.none,
          isDense: true,
        ),
        style: TextStyle(fontSize: 13, color: AppColors.slate800),
        textInputAction: TextInputAction.next,
        onChanged: (v) {
          widget.onChanged(v);
          _showOverlay();
        },
        onSubmitted: (_) => widget.onEnter(),
      ),
    );
  }
}

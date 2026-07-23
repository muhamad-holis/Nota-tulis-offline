import 'package:flutter/material.dart';
import '../models/nota_item.dart';
import '../models/product.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import 'product_autocomplete.dart';

class NotaRow extends StatefulWidget {
  final NotaItem item;
  final void Function({String? name, double? price, double? qty, double? totalOverride, bool clearOverride}) onUpdate;
  final VoidCallback onRemove;
  final VoidCallback onEnterName;
  final VoidCallback onEnterQty;
  final bool autoFocus;
  final FocusNode? nameFocusNode;

  const NotaRow({
    super.key,
    required this.item,
    required this.onUpdate,
    required this.onRemove,
    required this.onEnterName,
    required this.onEnterQty,
    this.autoFocus = false,
    this.nameFocusNode,
  });

  @override
  State<NotaRow> createState() => _NotaRowState();
}

class _NotaRowState extends State<NotaRow> {
  late TextEditingController _priceCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _totalCtrl;
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _totalFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.item.price > 0 ? widget.item.price.round().toString() : '');
    _qtyCtrl = TextEditingController(text: widget.item.qty > 0 ? formatQty(widget.item.qty) : '');
    _totalCtrl = TextEditingController(
        text: widget.item.effectiveTotal > 0 ? widget.item.effectiveTotal.round().toString() : '');
  }

  @override
  void didUpdateWidget(covariant NotaRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTotal = widget.item.effectiveTotal;
    final textTotal = newTotal > 0 ? newTotal.round().toString() : '';
    if (!_totalFocus.hasFocus && _totalCtrl.text != textTotal) {
      _totalCtrl.text = textTotal;
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _totalCtrl.dispose();
    _priceFocus.dispose();
    _qtyFocus.dispose();
    _totalFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(widget.item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: AppColors.red500,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => widget.onRemove(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.slate50)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: ProductAutocomplete(
                value: widget.item.name,
                autoFocus: widget.autoFocus,
                focusNode: widget.nameFocusNode,
                onChanged: (v) => widget.onUpdate(name: v),
                onSelectProduct: (Product p) {
                  _priceCtrl.text = p.price.round().toString();
                  widget.onUpdate(name: p.name, price: p.price, clearOverride: true);
                },
                onEnter: () {
                  widget.onEnterName();
                  _priceFocus.requestFocus();
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: _numberField(
                controller: _priceCtrl,
                focusNode: _priceFocus,
                textAlign: TextAlign.right,
                onChanged: (v) => widget.onUpdate(price: parseRupiahInput(v).toDouble(), clearOverride: true),
                onSubmitted: (_) => _qtyFocus.requestFocus(),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 1,
              child: _numberField(
                controller: _qtyCtrl,
                focusNode: _qtyFocus,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => widget.onUpdate(qty: parseQtyInput(v), clearOverride: true),
                onSubmitted: (_) {
                  if (widget.item.qty <= 0) {
                    _qtyCtrl.text = '1';
                    widget.onUpdate(qty: 1);
                  }
                  widget.onEnterQty();
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: _numberField(
                controller: _totalCtrl,
                focusNode: _totalFocus,
                textAlign: TextAlign.right,
                isOverride: widget.item.totalOverride != null,
                onChanged: (v) => widget.onUpdate(totalOverride: parseRupiahInput(v).toDouble()),
                onSubmitted: (_) => widget.onEnterQty(),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: Icon(Icons.close, size: 16, color: AppColors.slate300),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required TextAlign textAlign,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onSubmitted,
    TextInputType keyboardType = TextInputType.number,
    bool isOverride = false,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isOverride ? AppColors.amber50 : AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textAlign: textAlign,
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '0'),
        style: TextStyle(fontSize: 13, color: isOverride ? AppColors.amber700 : AppColors.slate700),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
      ),
    );
  }
}

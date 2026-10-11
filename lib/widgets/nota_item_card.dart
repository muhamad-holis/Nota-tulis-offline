import 'package:flutter/material.dart';
import '../models/nota_item.dart';
import '../models/product.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import 'product_autocomplete.dart';

/// Kartu satu item di halaman Buat Nota (Nama item, Jumlah, Satuan, Harga Satuan).
class NotaItemCard extends StatefulWidget {
  final int index;
  final NotaItem item;
  final void Function({String? name, double? price, double? qty, String? unit, double? totalOverride, bool clearOverride}) onUpdate;
  final VoidCallback onRemove;
  final VoidCallback onEnterPrice;
  final FocusNode? nameFocusNode;

  const NotaItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.onUpdate,
    required this.onRemove,
    required this.onEnterPrice,
    this.nameFocusNode,
  });

  @override
  State<NotaItemCard> createState() => _NotaItemCardState();
}

class _NotaItemCardState extends State<NotaItemCard> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _unitCtrl;
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _unitFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.item.price > 0 ? widget.item.price.round().toString() : '');
    _qtyCtrl = TextEditingController(text: widget.item.qty > 0 ? formatQty(widget.item.qty) : '');
    _unitCtrl = TextEditingController(text: widget.item.unit);
  }

  @override
  void didUpdateWidget(covariant NotaItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final textPrice = widget.item.price > 0 ? widget.item.price.round().toString() : '';
    if (!_priceFocus.hasFocus && _priceCtrl.text != textPrice) _priceCtrl.text = textPrice;
    final textQty = widget.item.qty > 0 ? formatQty(widget.item.qty) : '';
    if (!_qtyFocus.hasFocus && _qtyCtrl.text != textQty) _qtyCtrl.text = textQty;
    if (!_unitFocus.hasFocus && _unitCtrl.text != widget.item.unit) _unitCtrl.text = widget.item.unit;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _priceFocus.dispose();
    _qtyFocus.dispose();
    _unitFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Item #${widget.index + 1}',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.brand600)),
              ),
              InkWell(
                onTap: widget.onRemove,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, size: 22, color: AppColors.slate400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _box(
            child: Row(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 22, color: AppColors.brand600),
                const SizedBox(width: 14),
                Expanded(
                  child: ProductAutocomplete(
                    value: widget.item.name,
                    focusNode: widget.nameFocusNode,
                    hintText: 'Nama item',
                    fontSize: 16,
                    onChanged: (v) => widget.onUpdate(name: v),
                    onSelectProduct: (Product p) {
                      _priceCtrl.text = p.price.round().toString();
                      if (p.lastUnit != null && p.lastUnit!.trim().isNotEmpty) {
                        _unitCtrl.text = p.lastUnit!;
                      }
                      widget.onUpdate(name: p.name, price: p.price, unit: p.lastUnit, clearOverride: true);
                    },
                    onEnter: () => _qtyFocus.requestFocus(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: _labeled(
                  'Jumlah',
                  required: true,
                  child: _box(
                    child: Row(
                      children: [
                        Text('#', style: TextStyle(fontSize: 20, fontStyle: FontStyle.italic, color: AppColors.brand600)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _input(
                            controller: _qtyCtrl,
                            focusNode: _qtyFocus,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            hint: '1',
                            onChanged: (v) => widget.onUpdate(qty: parseQtyInput(v), clearOverride: true),
                            onSubmitted: (_) {
                              if (widget.item.qty <= 0) {
                                _qtyCtrl.text = '1';
                                widget.onUpdate(qty: 1);
                              }
                              _unitFocus.requestFocus();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: _labeled(
                  'Satuan',
                  child: _box(
                    child: _input(
                      controller: _unitCtrl,
                      focusNode: _unitFocus,
                      hint: 'pcs',
                      onChanged: (v) => widget.onUpdate(unit: v),
                      onSubmitted: (_) => _priceFocus.requestFocus(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 11,
                child: _labeled(
                  'Harga Satuan',
                  required: true,
                  child: _box(
                    child: Row(
                      children: [
                        Text('Rp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.brand600)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _input(
                            controller: _priceCtrl,
                            focusNode: _priceFocus,
                            keyboardType: TextInputType.number,
                            hint: 'Harga',
                            action: TextInputAction.done,
                            onChanged: (v) =>
                                widget.onUpdate(price: parseRupiahInput(v).toDouble(), clearOverride: true),
                            onSubmitted: (_) => widget.onEnterPrice(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.item.effectiveTotal > 0) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Subtotal ${formatRupiah(widget.item.effectiveTotal)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate500)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _labeled(String label, {required Widget child, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: RichText(
            text: TextSpan(
              text: label,
              style: TextStyle(fontSize: 14, color: AppColors.slate500),
              children: [
                if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _box({required Widget child}) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _input({
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onSubmitted,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction action = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: action,
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 16, color: AppColors.slate300),
      ),
      style: TextStyle(fontSize: 16, color: AppColors.slate800),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
    );
  }
}

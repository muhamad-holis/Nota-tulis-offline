import 'package:flutter/material.dart';
import '../models/nota_item.dart';
import '../utils/app_colors.dart';
import 'nota_row.dart';

class NotaTable extends StatelessWidget {
  final List<NotaItem> items;
  final void Function(String id, {String? name, double? price, double? qty, double? totalOverride, bool clearOverride}) onUpdateItem;
  final ValueChanged<String> onRemoveItem;
  final VoidCallback onAddRow;
  final ValueChanged<String> onEnterName;
  final void Function(String id, bool isLast) onEnterQty;

  const NotaTable({
    super.key,
    required this.items,
    required this.onUpdateItem,
    required this.onRemoveItem,
    required this.onAddRow,
    required this.onEnterName,
    required this.onEnterQty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.slate100),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppColors.slate50,
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('Nama Barang', style: _headStyle())),
                Expanded(flex: 2, child: Text('Harga', textAlign: TextAlign.right, style: _headStyle())),
                Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: _headStyle())),
                Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: _headStyle())),
                const SizedBox(width: 28),
              ],
            ),
          ),
          for (int i = 0; i < items.length; i++)
            NotaRow(
              key: ValueKey(items[i].id),
              item: items[i],
              autoFocus: i == 0,
              onUpdate: ({name, price, qty, totalOverride, clearOverride = false}) => onUpdateItem(
                items[i].id,
                name: name,
                price: price,
                qty: qty,
                totalOverride: totalOverride,
                clearOverride: clearOverride,
              ),
              onRemove: () => onRemoveItem(items[i].id),
              onEnterName: () => onEnterName(items[i].id),
              onEnterQty: () => onEnterQty(items[i].id, i == items.length - 1),
            ),
          InkWell(
            onTap: onAddRow,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 16, color: AppColors.brand600),
                  const SizedBox(width: 6),
                  Text('Tambah Baris',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.brand600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _headStyle() => TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.slate500);
}

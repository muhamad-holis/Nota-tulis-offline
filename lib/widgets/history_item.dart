import 'package:flutter/material.dart';
import '../models/nota.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class HistoryItem extends StatelessWidget {
  final Nota nota;
  final VoidCallback onTap;

  const HistoryItem({super.key, required this.nota, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate50))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nota.number, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate800)),
                  Text(formatDateTime(nota.date), style: TextStyle(fontSize: 13, color: AppColors.slate400)),
                  Text('${nota.items.length} item', style: TextStyle(fontSize: 12, color: AppColors.slate400)),
                ],
              ),
            ),
            Row(
              children: [
                Text(formatRupiah(nota.total),
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.brand700)),
                Icon(Icons.chevron_right, size: 18, color: AppColors.slate300),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

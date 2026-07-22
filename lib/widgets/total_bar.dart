import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class TotalBar extends StatelessWidget {
  final double total;
  const TotalBar({super.key, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.brand600,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total', style: TextStyle(color: AppColors.brand100, fontWeight: FontWeight.w500, fontSize: 14)),
          Text(
            formatRupiah(total),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

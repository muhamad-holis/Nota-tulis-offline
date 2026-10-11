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
    final name = (nota.customerName ?? '').trim();
    final isQris = nota.paymentMethod == 'qris';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nota.number,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.brand600)),
                const SizedBox(height: 4),
                Text('${name.isEmpty ? 'Tanpa nama' : name} \u2022 ${formatDateShort(nota.date)}',
                    style: TextStyle(fontSize: 15, color: AppColors.slate500)),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.slate100),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isQris ? const Color(0xFFDDE5F8) : AppColors.green100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isQris ? Icons.qr_code_2 : Icons.payments_outlined,
                              size: 16, color: isQris ? AppColors.accent : AppColors.green700),
                          const SizedBox(width: 6),
                          Text(isQris ? 'QRIS' : 'Tunai',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isQris ? AppColors.accent : AppColors.green700)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(formatRupiah(nota.total),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.brand600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

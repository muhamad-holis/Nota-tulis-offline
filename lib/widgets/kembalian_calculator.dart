import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

class KembalianCalculator extends StatelessWidget {
  final double total;
  final String receivedText;
  final ValueChanged<String> onReceivedTextChange;

  const KembalianCalculator({
    super.key,
    required this.total,
    required this.receivedText,
    required this.onReceivedTextChange,
  });

  static const _quickNominals = [10000, 20000, 50000, 100000];

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    final received = parseRupiahInput(receivedText);
    final diff = received - total;
    final hasInput = receivedText.trim().isNotEmpty;

    void addNominal(int value) {
      onReceivedTextChange((received + value).toString());
    }

    void setExact() {
      onReceivedTextChange(total.round().toString());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.slate100),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 16, color: AppColors.brand600),
              const SizedBox(width: 8),
              Text('Kalkulator Kembalian',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.slate700)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text('Rp', style: TextStyle(color: AppColors.slate400, fontSize: 14)),
                Expanded(
                  child: TextField(
                    controller: TextEditingController.fromValue(
                      TextEditingValue(
                        text: receivedText,
                        selection: TextSelection.collapsed(offset: receivedText.length),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'Uang diterima',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: AppColors.slate400, fontSize: 13),
                    ),
                    style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.slate800),
                    onChanged: (v) => onReceivedTextChange(v.replaceAll(RegExp(r'[^0-9]'), '')),
                  ),
                ),
                if (hasInput)
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: AppColors.slate300),
                    onPressed: () => onReceivedTextChange(''),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in _quickNominals)
                _chip('+${formatRupiah(n).replaceFirst('Rp ', '')}', () => addNominal(n)),
              _chip('Uang Pas', setExact),
            ],
          ),
          if (hasInput) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: diff < 0 ? AppColors.red50 : AppColors.emerald50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(diff < 0 ? 'Kurang' : 'Kembali',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: diff < 0 ? AppColors.red600 : AppColors.emerald600)),
                  Text(formatRupiah(diff.abs()),
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: diff < 0 ? AppColors.red600 : AppColors.emerald600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate600)),
      ),
    );
  }
}

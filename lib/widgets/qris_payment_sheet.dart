import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

/// Tampilkan gambar QRIS + jumlah yang harus dibayar.
/// Mengembalikan true kalau kasir menekan "Sudah Dibayar".
Future<bool> showQrisPaymentSheet(
  BuildContext context, {
  required double total,
  String? qrisBase64,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (_) => _QrisPaymentSheet(total: total, qrisBase64: qrisBase64),
  );
  return result ?? false;
}

class _QrisPaymentSheet extends StatelessWidget {
  final double total;
  final String? qrisBase64;
  const _QrisPaymentSheet({required this.total, this.qrisBase64});

  @override
  Widget build(BuildContext context) {
    final maxImageHeight = MediaQuery.of(context).size.height * 0.42;

    Widget qrisBox;
    if (qrisBase64 == null) {
      qrisBox = Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          children: [
            Icon(Icons.qr_code_2, size: 56, color: AppColors.slate300),
            const SizedBox(height: 10),
            Text(
              'Gambar QRIS belum diatur.\nTambahkan di Pengaturan > Pembayaran QRIS.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.slate500, height: 1.4),
            ),
          ],
        ),
      );
    } else {
      qrisBox = Container(
        constraints: BoxConstraints(maxHeight: maxImageHeight),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Image.memory(
          base64Decode(qrisBase64!),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gambar QRIS tidak bisa ditampilkan.', style: TextStyle(color: AppColors.slate500)),
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Pembayaran QRIS',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.brand600)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Text('Jumlah yang harus dibayar', style: TextStyle(fontSize: 14, color: AppColors.slate600)),
                  const SizedBox(height: 4),
                  Text(formatRupiah(total),
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.brand600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            qrisBox,
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brand600,
                      minimumSize: const Size.fromHeight(56),
                      side: BorderSide(color: AppColors.slate300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Batal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Sudah Dibayar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import '../utils/formatters.dart';

String _cell(Object? v) {
  final s = (v ?? '').toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Ekspor seluruh nota ke file CSV (satu baris per item) lalu buka share sheet.
/// Mengembalikan jumlah nota yang diekspor.
Future<int> exportNotasCsv() async {
  final notas = await DatabaseHelper.instance.getAllNotas();
  if (notas.isEmpty) {
    throw Exception('Belum ada nota untuk diekspor.');
  }

  final buf = StringBuffer('\uFEFF'); // BOM supaya Excel membaca UTF-8 dengan benar
  buf.writeln('Nomor Nota,Tanggal,Jam,Pelanggan,Pembayaran,Item,Qty,Satuan,Harga Satuan,Subtotal Item,Total Nota');
  for (final n in notas) {
    for (final it in n.items) {
      buf.writeln([
        n.number,
        formatDate(n.date),
        formatTime(n.date),
        n.customerName ?? '',
        n.paymentMethod == 'qris' ? 'QRIS' : 'Tunai',
        it.name,
        formatQty(it.qty),
        it.unit,
        it.price.round(),
        it.effectiveTotal.round(),
        n.total.round(),
      ].map(_cell).join(','));
    }
  }

  final dir = await getTemporaryDirectory();
  final dateStr = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/nota-tulis-export-$dateStr.csv');
  await file.writeAsString(buf.toString(), flush: true);
  await Share.shareXFiles([XFile(file.path)], text: 'Export data nota');
  return notas.length;
}

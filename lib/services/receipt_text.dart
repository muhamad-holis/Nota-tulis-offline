import '../models/nota.dart';
import '../models/nota_item.dart';
import '../models/settings.dart';
import '../utils/formatters.dart';

class ReceiptLine {
  final String text;
  final String align; // "left" or "center"
  final bool bold;

  ReceiptLine(this.text, {this.align = 'left', this.bold = false});
}

/// Lebar baris dalam karakter. Kertas 80mm selalu 42 kolom (font normal printer).
/// Kertas 58mm normalnya 32 kolom, TAPI kalau "Font Kecil" diaktifkan, printer
/// diminta pakai font kondensasi (Font B) yang muat 42 karakter juga di kertas
/// yang sama fisiknya cuma 58mm.
int getCharWidth(Settings settings) {
  if (settings.paperSize == '80') return 42;
  return settings.smallFont ? 42 : 32;
}

List<String> wrapText(String text, int width) {
  if (text.isEmpty) return [''];
  final words = text.split(' ');
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (candidate.length > width) {
      if (current.isNotEmpty) lines.add(current);
      if (word.length > width) {
        var remaining = word;
        while (remaining.length > width) {
          lines.add(remaining.substring(0, width));
          remaining = remaining.substring(width);
        }
        current = remaining;
      } else {
        current = word;
      }
    } else {
      current = candidate;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}

class _ColumnWidths {
  final int nameWidth;
  final int hrgWidth;
  final int qtyWidth;
  final int totalWidth;
  _ColumnWidths(this.nameWidth, this.hrgWidth, this.qtyWidth, this.totalWidth);
}

const int _minNameWidth = 8;
const int _numColumns = 4; // Qty | Barang | Harga | Total
const int _columnGaps = _numColumns - 1; // 3 spasi pemisah eksplisit antar kolom

_ColumnWidths _computeColumnWidths(Nota nota, int charWidth) {
  int maxHrgLen = 'Hrg'.length;
  int maxQtyLen = 'Qty'.length;
  int maxTotalLen = 'Total'.length;

  for (final item in nota.items) {
    final priceStr = formatRupiah(item.price).replaceFirst('Rp ', '');
    final qtyStr = _qtyUnitStr(item);
    final totalStr = formatRupiah(item.effectiveTotal).replaceFirst('Rp ', '');
    maxHrgLen = maxHrgLen > priceStr.length ? maxHrgLen : priceStr.length;
    maxQtyLen = maxQtyLen > qtyStr.length ? maxQtyLen : qtyStr.length;
    maxTotalLen = maxTotalLen > totalStr.length ? maxTotalLen : totalStr.length;
  }

  // Lebar kolom Qty/Harga/Total pas-pasan sesuai isi terpanjangnya (tanpa gap
  // dibakar di dalam), karena spasi antar kolom nanti ditambah eksplisit saat
  // baris dirangkai. Dengan begitu kolom Qty bisa rata kanan dan tetap ada jarak
  // ke kolom Barang di sebelahnya (tidak nempel).
  int hrgWidth = maxHrgLen;
  int qtyWidth = maxQtyLen;
  int totalWidth = maxTotalLen;
  int nameWidth = charWidth - hrgWidth - qtyWidth - totalWidth - _columnGaps;

  // PENTING: kolom Harga & Total tidak boleh disusutkan sampai lebih kecil dari
  // panjang angka aslinya (maxHrgLen/maxTotalLen). Kolom ini tidak pernah dipotong
  // (beda dengan nama barang yang aman dipotong pakai "..."), jadi kalau nominal
  // uang tetap dipaksa mengecil, angkanya bisa salah baca/menyesatkan di struk.
  // Yang boleh mengalah lebih jauh hanya kolom Nama Barang (lihat floor di bawah).
  nameWidth = nameWidth > 4 ? nameWidth : 4;
  return _ColumnWidths(nameWidth, hrgWidth, qtyWidth, totalWidth);
}

String _fitLeft(String text, int width, {bool truncateMark = false}) {
  if (text.length > width) {
    if (truncateMark && width > 1) return '${text.substring(0, width - 1)}.';
    return text.substring(0, width);
  }
  return text.padRight(width, ' ');
}

String _fitRight(String text, int width) {
  return text.length >= width ? text : text.padLeft(width, ' ');
}

/// Format kolom Qty jadi "2 pcs", "1 dus", "3 renceng", dst.
String _qtyUnitStr(NotaItem item) {
  final unit = item.unit.trim();
  final qtyStr = formatQty(item.qty);
  return unit.isEmpty ? qtyStr : '$qtyStr $unit';
}

/// Bangun representasi nota sebagai daftar baris teks (align + bold),
/// dipakai bersama oleh preview layar & printer thermal supaya selalu identik.
List<ReceiptLine> buildReceiptLines(Nota nota, Settings settings) {
  final lines = <ReceiptLine>[];
  final charWidth = getCharWidth(settings);
  final divider = '-' * charWidth;
  void push(String text, {String align = 'left', bool bold = false}) {
    lines.add(ReceiptLine(text, align: align, bold: bold));
  }

  if (settings.storeName.isNotEmpty) {
    for (final l in wrapText(settings.storeName, charWidth)) {
      push(l, align: 'center', bold: true);
    }
  }
  if (settings.address.isNotEmpty) {
    for (final l in wrapText(settings.address, charWidth)) {
      push(l, align: 'center');
    }
  }
  if (settings.phone.isNotEmpty) {
    for (final l in wrapText(settings.phone, charWidth)) {
      push(l, align: 'center');
    }
  }

  push(divider, align: 'center');
  if (settings.headerText.isNotEmpty) {
    for (final l in settings.headerText.split('\n')) {
      for (final wrapped in wrapText(l, charWidth)) {
        push(wrapped, align: 'center');
      }
    }
    push(divider, align: 'center');
  }

  push('Tanggal: ${formatDateTime(nota.date)}');
  push('No. Nota: ${nota.number}');
  if (nota.customerName != null && nota.customerName!.isNotEmpty) {
    push('Pelanggan: ${nota.customerName}');
  }
  push(divider);

  final cw = _computeColumnWidths(nota, charWidth);

  push(
    '${_fitRight('Qty', cw.qtyWidth)} '
    '${_fitLeft('Barang', cw.nameWidth)} '
    '${_fitRight('Hrg', cw.hrgWidth)} '
    '${_fitRight('Total', cw.totalWidth)}',
  );
  push(divider);

  for (final item in nota.items) {
    final priceStr = formatRupiah(item.price).replaceFirst('Rp ', '');
    final qtyStr = _qtyUnitStr(item);
    final totalStr = formatRupiah(item.effectiveTotal).replaceFirst('Rp ', '');
    push(
      '${_fitRight(qtyStr, cw.qtyWidth)} '
      '${_fitLeft(item.name, cw.nameWidth, truncateMark: true)} '
      '${_fitRight(priceStr, cw.hrgWidth)} '
      '${_fitRight(totalStr, cw.totalWidth)}',
    );
  }

  push(divider);

  final totalValueStr = formatRupiah(nota.total).replaceFirst('Rp ', '');
  final totalLabelWidth = 'TOTAL'.length > (charWidth - totalValueStr.length)
      ? 'TOTAL'.length
      : charWidth - totalValueStr.length;
  push(
    _fitLeft('TOTAL', totalLabelWidth) + _fitRight(totalValueStr, charWidth - totalLabelWidth),
    bold: true,
  );
  push(divider);

  if (nota.bayarTunai != null && nota.bayarTunai! > 0) {
    final bayarStr = formatRupiah(nota.bayarTunai!).replaceFirst('Rp ', '');
    final bayarLabelWidth = 'Bayar Tunai'.length > (charWidth - bayarStr.length)
        ? 'Bayar Tunai'.length
        : charWidth - bayarStr.length;
    push(_fitLeft('Bayar Tunai', bayarLabelWidth) +
        _fitRight(bayarStr, charWidth - bayarLabelWidth));

    final selisih = nota.bayarTunai! - nota.total;
    final kembaliLabel = selisih < 0 ? 'Kurang' : 'Kembali';
    final kembaliStr = formatRupiah(selisih.abs()).replaceFirst('Rp ', '');
    final kembaliLabelWidth = kembaliLabel.length > (charWidth - kembaliStr.length)
        ? kembaliLabel.length
        : charWidth - kembaliStr.length;
    push(_fitLeft(kembaliLabel, kembaliLabelWidth) +
        _fitRight(kembaliStr, charWidth - kembaliLabelWidth));
    push(divider);
  }

  if (settings.footerText.isNotEmpty) {
    for (final l in settings.footerText.split('\n')) {
      for (final wrapped in wrapText(l, charWidth)) {
        push(wrapped, align: 'center');
      }
    }
  }

  return lines;
}

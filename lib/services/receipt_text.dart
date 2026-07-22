import '../models/nota.dart';
import '../models/settings.dart';
import '../utils/formatters.dart';

class ReceiptLine {
  final String text;
  final String align; // "left" or "center"
  final bool bold;

  ReceiptLine(this.text, {this.align = 'left', this.bold = false});
}

int getCharWidth(Settings settings) => settings.paperSize == '80' ? 42 : 32;

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
const int _columnGap = 1;

_ColumnWidths _computeColumnWidths(Nota nota, int charWidth) {
  int maxHrgLen = 'Hrg'.length;
  int maxQtyLen = 'Qty'.length;
  int maxTotalLen = 'Total'.length;

  for (final item in nota.items) {
    final priceStr = formatRupiah(item.price).replaceFirst('Rp ', '');
    final qtyStr = 'x${formatQty(item.qty)}';
    final totalStr = formatRupiah(item.effectiveTotal).replaceFirst('Rp ', '');
    maxHrgLen = maxHrgLen > priceStr.length ? maxHrgLen : priceStr.length;
    maxQtyLen = maxQtyLen > qtyStr.length ? maxQtyLen : qtyStr.length;
    maxTotalLen = maxTotalLen > totalStr.length ? maxTotalLen : totalStr.length;
  }

  int hrgWidth = maxHrgLen + _columnGap;
  int qtyWidth = maxQtyLen + _columnGap;
  int totalWidth = maxTotalLen + _columnGap;
  int nameWidth = charWidth - hrgWidth - qtyWidth - totalWidth;

  if (nameWidth < _minNameWidth) {
    hrgWidth = maxHrgLen;
    qtyWidth = maxQtyLen;
    totalWidth = maxTotalLen;
    nameWidth = charWidth - hrgWidth - qtyWidth - totalWidth;
  }

  while (nameWidth < _minNameWidth && (totalWidth > 4 || hrgWidth > 4)) {
    if (totalWidth > 4) {
      totalWidth -= 1;
    } else if (hrgWidth > 4) {
      hrgWidth -= 1;
    }
    nameWidth = charWidth - hrgWidth - qtyWidth - totalWidth;
  }

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
    _fitLeft('Barang', cw.nameWidth) +
        _fitRight('Hrg', cw.hrgWidth) +
        _fitRight('Qty', cw.qtyWidth) +
        _fitRight('Total', cw.totalWidth),
  );
  push(divider);

  for (final item in nota.items) {
    final priceStr = formatRupiah(item.price).replaceFirst('Rp ', '');
    final qtyStr = 'x${formatQty(item.qty)}';
    final totalStr = formatRupiah(item.effectiveTotal).replaceFirst('Rp ', '');
    push(
      _fitLeft(item.name, cw.nameWidth, truncateMark: true) +
          _fitRight(priceStr, cw.hrgWidth) +
          _fitRight(qtyStr, cw.qtyWidth) +
          _fitRight(totalStr, cw.totalWidth),
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

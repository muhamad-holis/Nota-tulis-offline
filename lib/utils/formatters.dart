import 'package:intl/intl.dart';

final NumberFormat _idNumberFormat = NumberFormat.decimalPattern('id_ID');
final DateFormat _idDateFormat = DateFormat('dd/MM/yyyy', 'id_ID');
final DateFormat _idTimeFormat = DateFormat('HH:mm', 'id_ID');

String formatRupiah(num value) {
  if (value.isNaN || value.isInfinite) return 'Rp 0';
  return 'Rp ${_idNumberFormat.format(value.round())}';
}

/// Parse input rupiah dari teks bebas (buang semua selain digit).
int parseRupiahInput(String value) {
  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
  return digitsOnly.isEmpty ? 0 : int.parse(digitsOnly);
}

/// Parse qty yang boleh desimal (mis. 0,5 kg). Menerima koma ATAU titik.
double parseQtyInput(String value) {
  final cleaned = value.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
  final n = double.tryParse(cleaned);
  if (n == null || n < 0) return 0;
  return (n * 100).round() / 100;
}

/// Format qty ala Indonesia (koma desimal), buang trailing zero.
String formatQty(num qty) {
  if (qty.isNaN || qty.isInfinite) return '0';
  final rounded = (qty * 100).round() / 100;
  var text = rounded.toStringAsFixed(2);
  text = text.replaceAll(RegExp(r'0+$'), '');
  text = text.replaceAll(RegExp(r'\.$'), '');
  if (text.isEmpty || text == '-') text = '0';
  return text.replaceAll('.', ',');
}

String formatDate(int timestampMs) {
  return _idDateFormat.format(DateTime.fromMillisecondsSinceEpoch(timestampMs));
}

String formatTime(int timestampMs) {
  return _idTimeFormat.format(DateTime.fromMillisecondsSinceEpoch(timestampMs));
}

String formatDateTime(int timestampMs) {
  return '${formatDate(timestampMs)} ${formatTime(timestampMs)}';
}

String generateItemId() {
  final rand = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'item_${DateTime.now().millisecondsSinceEpoch}_$rand';
}

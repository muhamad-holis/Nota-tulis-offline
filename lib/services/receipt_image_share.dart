import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/nota.dart';
import '../models/settings.dart';
import '../widgets/receipt_preview.dart';

/// Render sebuah widget menjadi PNG tanpa menampilkannya di layar:
/// widget disisipkan ke Overlay di posisi jauh di luar layar, dibungkus
/// RepaintBoundary, lalu di-capture setelah frame selesai digambar.
Future<Uint8List> _captureWidgetAsPng(
  BuildContext context,
  Widget child, {
  double pixelRatio = 3.0,
}) async {
  final repaintKey = GlobalKey();
  final overlayState = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -9999,
      top: 0,
      child: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(key: repaintKey, child: child),
      ),
    ),
  );
  overlayState.insert(entry);
  try {
    // Tunggu beberapa frame supaya layout, paint, dan gambar logo (kalau ada)
    // benar-benar selesai sebelum di-capture.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 50));

    final renderObject = repaintKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw Exception('Gagal merender preview nota untuk dibagikan.');
    }
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Gagal membuat gambar PNG dari preview nota.');
    }
    return byteData.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}

/// Bagikan nota sebagai GAMBAR (PNG) yang tampilannya identik dengan
/// preview struk di aplikasi (termasuk logo toko, ukuran kertas 58/80mm),
/// lewat share sheet Android (WhatsApp, dsb).
Future<void> shareNotaAsImage(BuildContext context, Nota nota, Settings settings) async {
  final bytes = await _captureWidgetAsPng(
    context,
    ReceiptPreview(nota: nota, settings: settings),
  );

  final dir = await getTemporaryDirectory();
  final safeName = nota.number.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final file = File('${dir.path}/nota_$safeName.png');
  await file.writeAsBytes(bytes, flush: true);

  await Share.shareXFiles([XFile(file.path)], text: 'Nota ${nota.number}');
}

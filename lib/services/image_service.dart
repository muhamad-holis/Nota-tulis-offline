import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class MonoRaster {
  final int widthPx;
  final int heightPx;
  final List<int> data;
  MonoRaster(this.widthPx, this.heightPx, this.data);
}

/// Crop gambar jadi persegi (crop tengah) lalu resize ke [size]x[size],
/// hasilnya base64 PNG (setara dataURL di versi web).
String cropImageToSquareBase64(Uint8List bytes, {int size = 240}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Gagal memuat gambar.');
  }
  final minSide = decoded.width < decoded.height ? decoded.width : decoded.height;
  final sx = ((decoded.width - minSide) / 2).round();
  final sy = ((decoded.height - minSide) / 2).round();
  final cropped = img.copyCrop(decoded, x: sx, y: sy, width: minSide, height: minSide);
  final resized = img.copyResize(cropped, width: size, height: size);
  final pngBytes = img.encodePng(resized);
  return base64Encode(pngBytes);
}

/// Konversi base64 PNG logo toko menjadi bitmap monokrom 1-bit, siap dibungkus
/// jadi perintah ESC/POS "GS v 0" untuk dicetak di printer thermal Bluetooth.
MonoRaster imageToMonoRaster(String base64Data, int maxWidthPx, {int maxHeightPx = 180}) {
  final bytes = base64Decode(base64Data);
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Gagal memuat gambar logo.');
  }

  int targetW = maxWidthPx < decoded.width ? maxWidthPx : decoded.width;
  int targetH = ((decoded.height / decoded.width) * targetW).round();
  if (targetH > maxHeightPx) {
    targetH = maxHeightPx;
    targetW = ((decoded.width / decoded.height) * targetH).round();
  }
  targetW = (targetW ~/ 8) * 8;
  if (targetW < 8) targetW = 8;

  final resized = img.copyResize(decoded, width: targetW, height: targetH);
  final canvas = img.Image(width: targetW, height: targetH, numChannels: 3);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(canvas, resized);

  final bytesPerRow = targetW ~/ 8;
  final data = List<int>.filled(bytesPerRow * targetH, 0);

  for (int y = 0; y < targetH; y++) {
    for (int x = 0; x < targetW; x++) {
      final pixel = canvas.getPixel(x, y);
      final r = pixel.r, g = pixel.g, b = pixel.b;
      final gray = r * 0.299 + g * 0.587 + b * 0.114;
      final isBlack = gray < 200;
      if (isBlack) {
        final byteIndex = y * bytesPerRow + (x >> 3);
        data[byteIndex] |= 0x80 >> (x % 8);
      }
    }
  }

  return MonoRaster(targetW, targetH, data);
}

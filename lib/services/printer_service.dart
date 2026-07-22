import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/nota.dart';
import '../models/settings.dart';
import 'receipt_text.dart';
import 'image_service.dart';

// ESC/POS command bytes (identik dengan versi web)
const int _esc = 0x1b;
const int _gs = 0x1d;

final List<int> _cmdInit = [_esc, 0x40];
final List<int> _cmdAlignLeft = [_esc, 0x61, 0x00];
final List<int> _cmdAlignCenter = [_esc, 0x61, 0x01];
final List<int> _cmdBoldOn = [_esc, 0x45, 0x01];
final List<int> _cmdBoldOff = [_esc, 0x45, 0x00];
final List<int> _cmdCut = [_gs, 0x56, 0x42, 0x00];

final Guid _printerServiceUuid = Guid('000018f0-0000-1000-8000-00805f9b34fb');
final Guid _printerCharUuid = Guid('00002af1-0000-1000-8000-00805f9b34fb');

const int _writeChunkSize = 100;
const Duration _writeChunkDelay = Duration(milliseconds: 12);
const Duration _connectTimeout = Duration(seconds: 8);

enum PrinterStatus { disconnected, connecting, connected, reconnecting }

class PrinterService {
  PrinterService._internal();
  static final PrinterService instance = PrinterService._internal();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  PrinterStatus _status = PrinterStatus.disconnected;
  final _statusController = StreamController<PrinterStatus>.broadcast();
  Future<void> _writeChain = Future.value();
  StreamSubscription<BluetoothConnectionState>? _connSub;

  Stream<PrinterStatus> get statusStream => _statusController.stream;
  PrinterStatus get status => _status;

  bool get isSupported => true; // Bluetooth Low Energy tersedia di semua Android modern

  bool get isConnected =>
      _device != null && _characteristic != null && _device!.isConnected;

  void _setStatus(PrinterStatus status) {
    _status = status;
    _statusController.add(status);
  }

  Future<BluetoothCharacteristic> _discoverWritableCharacteristic(
      BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid == _printerServiceUuid) {
        for (final c in service.characteristics) {
          if (c.uuid == _printerCharUuid) return c;
        }
      }
    }
    for (final service in services) {
      for (final c in service.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) return c;
      }
    }
    throw Exception('Tidak ditemukan layanan cetak pada printer ini.');
  }

  Future<Map<String, String>> _attachDevice(BluetoothDevice device) async {
    await device.connect(timeout: _connectTimeout).catchError((_) {});
    if (!device.isConnected) {
      await device.connect(timeout: _connectTimeout);
    }
    final characteristic = await _discoverWritableCharacteristic(device);

    await _connSub?.cancel();
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _characteristic = null;
        _setStatus(PrinterStatus.disconnected);
      }
    });

    _device = device;
    _characteristic = characteristic;
    _setStatus(PrinterStatus.connected);

    return {'id': device.remoteId.str, 'name': device.platformName.isNotEmpty ? device.platformName : 'Printer Bluetooth'};
  }

  /// Pastikan sudah tersambung sebelum mencetak; coba reconnect ke device terakhir.
  Future<void> ensureConnected() async {
    if (isConnected) return;
    if (_device == null) {
      throw Exception('Printer belum pernah disambungkan. Tekan "Cari Printer".');
    }
    _setStatus(PrinterStatus.reconnecting);
    try {
      await _attachDevice(_device!);
    } catch (_) {
      _setStatus(PrinterStatus.disconnected);
      throw Exception('Printer terputus. Tekan "Cari Printer" untuk menyambungkan ulang.');
    }
  }

  /// Scan & pilih perangkat Bluetooth. Mengembalikan stream hasil scan untuk ditampilkan di UI.
  Stream<List<ScanResult>> scanResults() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    return FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<Map<String, String>> connectTo(BluetoothDevice device) async {
    _setStatus(PrinterStatus.connecting);
    try {
      await stopScan();
      return await _attachDevice(device);
    } catch (err) {
      _setStatus(isConnected ? PrinterStatus.connected : PrinterStatus.disconnected);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _connSub?.cancel();
    await _device?.disconnect();
    _device = null;
    _characteristic = null;
    _setStatus(PrinterStatus.disconnected);
  }

  Future<void> _write(List<int> bytes) async {
    final run = _writeChain.then((_) => _writeInternal(bytes));
    _writeChain = run.catchError((_) {});
    return run;
  }

  Future<void> _writeInternal(List<int> bytes, {bool isRetry = false}) async {
    if (_characteristic == null) {
      throw Exception('Printer belum terhubung.');
    }
    try {
      for (int i = 0; i < bytes.length; i += _writeChunkSize) {
        final end = (i + _writeChunkSize < bytes.length) ? i + _writeChunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);
        await _characteristic!.write(chunk, withoutResponse: false);
        if (end < bytes.length) await Future.delayed(_writeChunkDelay);
      }
    } catch (err) {
      if (isRetry) rethrow;
      await ensureConnected();
      await _writeInternal(bytes, isRetry: true);
    }
  }

  List<int> _rasterImageCommand(int widthPx, int heightPx, List<int> data) {
    final bytesPerRow = widthPx ~/ 8;
    final xL = bytesPerRow & 0xff;
    final xH = (bytesPerRow >> 8) & 0xff;
    final yL = heightPx & 0xff;
    final yH = (heightPx >> 8) & 0xff;
    return [_gs, 0x76, 0x30, 0x00, xL, xH, yL, yH, ...data];
  }

  Future<List<int>> buildReceiptBytes(Nota nota, Settings settings) async {
    final bytes = <int>[];
    void push(List<int> arr) => bytes.addAll(arr);
    void line([String text = '']) => push(('$text\n').codeUnits);
    final isWide = settings.paperSize == '80';

    push(_cmdInit);

    if (settings.logo != null && settings.showLogo) {
      try {
        push(_cmdAlignCenter);
        final maxWidthPx = isWide ? 384 : 300;
        final raster = imageToMonoRaster(settings.logo!, maxWidthPx);
        push(_rasterImageCommand(raster.widthPx, raster.heightPx, raster.data));
        line();
      } catch (_) {
        // Kalau gagal konversi logo, lanjutkan cetak nota tanpa logo.
      }
    }

    final receiptLines = buildReceiptLines(nota, settings);
    String? currentAlign;
    bool currentBold = false;
    for (final rl in receiptLines) {
      if (rl.align != currentAlign) {
        push(rl.align == 'center' ? _cmdAlignCenter : _cmdAlignLeft);
        currentAlign = rl.align;
      }
      if (rl.bold != currentBold) {
        push(rl.bold ? _cmdBoldOn : _cmdBoldOff);
        currentBold = rl.bold;
      }
      line(rl.text);
    }
    if (currentBold) push(_cmdBoldOff);

    line();
    line();
    line();
    push(_cmdCut);

    return bytes;
  }

  Future<void> printReceipt(Nota nota, Settings settings) async {
    await ensureConnected();
    final bytes = await buildReceiptBytes(nota, settings);
    await _write(bytes);
  }

  Future<void> testPrint(Settings settings) async {
    await ensureConnected();
    final bytes = <int>[];
    void push(List<int> arr) => bytes.addAll(arr);
    void line([String text = '']) => push(('$text\n').codeUnits);

    push(_cmdInit);
    push(_cmdAlignCenter);
    push(_cmdBoldOn);
    line('TEST PRINT');
    push(_cmdBoldOff);
    line(settings.storeName.isNotEmpty ? settings.storeName : 'Nota Tulis');
    line('Printer terhubung dengan baik');
    line();
    line();
    push(_cmdCut);

    await _write(bytes);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/nota.dart';
import '../models/settings.dart';
import '../services/printer_service.dart';

class PrinterUiState {
  final bool connecting;
  final bool printing;
  final String? error;
  final PrinterStatus status;

  PrinterUiState({
    required this.connecting,
    required this.printing,
    required this.error,
    required this.status,
  });

  PrinterUiState copyWith({bool? connecting, bool? printing, String? error, PrinterStatus? status}) {
    return PrinterUiState(
      connecting: connecting ?? this.connecting,
      printing: printing ?? this.printing,
      error: error,
      status: status ?? this.status,
    );
  }
}

class PrinterNotifier extends Notifier<PrinterUiState> {
  @override
  PrinterUiState build() {
    ref.onDispose(() {});
    PrinterService.instance.statusStream.listen((status) {
      state = state.copyWith(status: status);
    });
    return PrinterUiState(
      connecting: false,
      printing: false,
      error: null,
      status: PrinterService.instance.status,
    );
  }

  Future<Map<String, String>?> connectTo(dynamic device) async {
    state = state.copyWith(connecting: true, error: null);
    try {
      final info = await PrinterService.instance.connectTo(device);
      state = state.copyWith(connecting: false);
      return info;
    } catch (err) {
      state = state.copyWith(connecting: false, error: err.toString());
      return null;
    }
  }

  Future<void> disconnect() async {
    await PrinterService.instance.disconnect();
  }

  Future<bool> print(Nota nota, Settings settings) async {
    state = state.copyWith(printing: true, error: null);
    try {
      await PrinterService.instance.printReceipt(nota, settings);
      state = state.copyWith(printing: false);
      return true;
    } catch (err) {
      state = state.copyWith(printing: false, error: err.toString());
      return false;
    }
  }

  Future<bool> testPrint(Settings settings) async {
    state = state.copyWith(printing: true, error: null);
    try {
      await PrinterService.instance.testPrint(settings);
      state = state.copyWith(printing: false);
      return true;
    } catch (err) {
      state = state.copyWith(printing: false, error: err.toString());
      return false;
    }
  }
}

final printerProvider = NotifierProvider<PrinterNotifier, PrinterUiState>(
  PrinterNotifier.new,
);

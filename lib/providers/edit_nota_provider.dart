import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/nota.dart';
import '../models/nota_item.dart';
import '../utils/formatters.dart';
import 'nota_draft_provider.dart';

NotaItem _emptyRow() => NotaItem(id: generateItemId(), name: '', price: 0, qty: 1);

class EditNotaState {
  final Nota? original;
  final List<NotaItem> items;
  final String customerName;
  final String receivedText;

  EditNotaState({
    required this.original,
    required this.items,
    required this.customerName,
    this.receivedText = '',
  });

  double get total => items.fold<double>(0.0, (sum, item) => sum + item.effectiveTotal);

  List<NotaItem> get validItems =>
      items.where((i) => i.name.trim().isNotEmpty && (i.price > 0 || i.qty > 0)).toList();

  EditNotaState copyWith({List<NotaItem>? items, String? customerName, String? receivedText}) {
    return EditNotaState(
      original: original,
      items: items ?? this.items,
      customerName: customerName ?? this.customerName,
      receivedText: receivedText ?? this.receivedText,
    );
  }
}

class EditNotaNotifier extends Notifier<EditNotaState> {
  @override
  EditNotaState build() {
    return EditNotaState(original: null, items: [], customerName: '');
  }

  /// Muat ulang draft setiap kali nota yang sedang dibuka berganti.
  void load(Nota nota) {
    if (state.original?.id == nota.id) return;
    state = EditNotaState(
      original: nota,
      items: nota.items.isNotEmpty
          ? nota.items.map((e) => e.copyWith()).toList()
          : [_emptyRow()],
      customerName: nota.customerName ?? '',
      receivedText: (nota.bayarTunai != null && nota.bayarTunai! > 0)
          ? nota.bayarTunai!.round().toString()
          : '',
    );
  }

  void setCustomerName(String name) {
    state = state.copyWith(customerName: name);
  }

  void setReceivedText(String value) {
    state = state.copyWith(receivedText: value);
  }

  void updateItem(String id, {String? name, double? price, double? qty, double? totalOverride, bool clearOverride = false}) {
    state = state.copyWith(
      items: state.items
          .map((item) => item.id == id
              ? item.copyWith(name: name, price: price, qty: qty, totalOverride: totalOverride, clearOverride: clearOverride)
              : item)
          .toList(),
    );
  }

  void removeItem(String id) {
    final filtered = state.items.where((item) => item.id != id).toList();
    state = state.copyWith(items: filtered.isEmpty ? [_emptyRow()] : filtered);
  }

  void addRow() {
    state = state.copyWith(items: [...state.items, _emptyRow()]);
  }

  void ensureTrailingRow() {
    final last = state.items.isNotEmpty ? state.items.last : null;
    if (last != null && last.name.trim().isEmpty) return;
    state = state.copyWith(items: [...state.items, _emptyRow()]);
  }

  /// Simpan perubahan ke nota yang sama (nomor & tanggal asli tidak berubah).
  Future<Nota> saveChanges() async {
    final original = state.original;
    if (original?.id == null) throw Exception('Nota tidak ditemukan.');
    final validItems = state.validItems;
    if (validItems.isEmpty) throw Exception('Nota tidak boleh kosong.');

    final bayarTunai = parseRupiahInput(state.receivedText).toDouble();
    final updated = original!.copyWith(
      customerName: state.customerName.trim().isEmpty ? null : state.customerName.trim(),
      items: validItems,
      total: validItems.fold<double>(0.0, (sum, item) => sum + item.effectiveTotal),
      bayarTunai: bayarTunai,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseHelper.instance.updateNota(original.id!, updated);
    await learnProductsFromItems(validItems);
    state = EditNotaState(
      original: updated,
      items: state.items,
      customerName: state.customerName,
      receivedText: state.receivedText,
    );
    return updated;
  }
}

final editNotaProvider = NotifierProvider<EditNotaNotifier, EditNotaState>(
  EditNotaNotifier.new,
);

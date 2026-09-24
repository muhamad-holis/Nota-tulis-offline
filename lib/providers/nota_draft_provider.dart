import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../db/database_helper.dart';
import '../models/nota.dart';
import '../models/nota_item.dart';
import '../models/product.dart';
import '../utils/formatters.dart';

const _uuid = Uuid();

NotaItem _emptyRow() => NotaItem(id: generateItemId(), name: '', price: 0, qty: 1);

class NotaDraftState {
  final List<NotaItem> items;
  final String customerName;

  NotaDraftState({required this.items, required this.customerName});

  double get total =>
      items.fold<double>(0.0, (sum, item) => sum + item.effectiveTotal);

  List<NotaItem> get validItems =>
      items.where((i) => i.name.trim().isNotEmpty && (i.price > 0 || i.qty > 0)).toList();

  NotaDraftState copyWith({List<NotaItem>? items, String? customerName}) {
    return NotaDraftState(
      items: items ?? this.items,
      customerName: customerName ?? this.customerName,
    );
  }
}

class NotaDraftNotifier extends Notifier<NotaDraftState> {
  @override
  NotaDraftState build() {
    return NotaDraftState(items: [_emptyRow()], customerName: '');
  }

  void setCustomerName(String name) {
    state = state.copyWith(customerName: name);
  }

  void updateItem(String id, {String? name, double? price, double? qty, String? unit, double? totalOverride, bool clearOverride = false}) {
    state = state.copyWith(
      items: state.items
          .map((item) => item.id == id
              ? item.copyWith(name: name, price: price, qty: qty, unit: unit, totalOverride: totalOverride, clearOverride: clearOverride)
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

  void reset() {
    state = NotaDraftState(items: [_emptyRow()], customerName: '');
  }

  /// Tambah produk dari katalog ke draft nota.
  /// - Kalau barang dengan nama sama sudah ada di nota, qty-nya +1.
  /// - Kalau belum ada, isi baris kosong pertama (atau buat baris baru).
  void addProductFromCatalog(Product p) {
    final key = p.name.trim().toLowerCase();
    final items = [...state.items];

    final existingIdx = items.indexWhere((i) => i.name.trim().toLowerCase() == key);
    if (existingIdx >= 0) {
      final it = items[existingIdx];
      items[existingIdx] = it.copyWith(qty: (it.qty > 0 ? it.qty : 0) + 1, clearOverride: true);
      state = state.copyWith(items: items);
      return;
    }

    final unit = p.lastUnit ?? 'pcs';
    final emptyIdx = items.indexWhere((i) => i.name.trim().isEmpty && i.price <= 0);
    if (emptyIdx >= 0) {
      items[emptyIdx] = items[emptyIdx].copyWith(
        name: p.name,
        price: p.price,
        qty: 1,
        unit: unit,
        clearOverride: true,
      );
    } else {
      items.add(NotaItem(id: generateItemId(), name: p.name, price: p.price, qty: 1, unit: unit));
    }
    state = state.copyWith(items: items);
    ensureTrailingRow();
  }

  /// Simpan draft nota baru ke database, dan "pelajari" nama/harga barang.
  Future<Nota> saveNota({double? bayarTunai}) async {
    final validItems = state.validItems;
    if (validItems.isEmpty) {
      throw Exception('Nota masih kosong.');
    }
    final db = DatabaseHelper.instance;
    final number = await db.nextNotaNumber();
    final now = DateTime.now().millisecondsSinceEpoch;
    final nota = Nota(
      uuid: _uuid.v4(),
      number: number,
      customerName: state.customerName.trim().isEmpty ? null : state.customerName.trim(),
      date: now,
      items: validItems,
      total: validItems.fold<double>(0.0, (sum, item) => sum + item.effectiveTotal),
      bayarTunai: (bayarTunai != null && bayarTunai > 0) ? bayarTunai : null,
      updatedAt: now,
    );
    final saved = await db.insertNota(nota);
    await learnProductsFromItems(validItems);
    return saved;
  }
}

final notaDraftProvider = NotifierProvider<NotaDraftNotifier, NotaDraftState>(
  NotaDraftNotifier.new,
);

/// "Belajar" nama & harga barang dari nota yang baru disimpan/diedit, supaya lain kali
/// mengetik nama yang sama, harganya otomatis tersaran (autocomplete).
Future<void> learnProductsFromItems(List<NotaItem> items) async {
  final db = DatabaseHelper.instance;
  final now = DateTime.now().millisecondsSinceEpoch;
  for (final item in items) {
    final name = item.name.trim();
    if (name.isEmpty || !(item.price > 0)) continue;
    final unit = item.unit.trim();

    final existing = await db.findProductByName(name);
    if (existing != null) {
      if (existing.price == item.price && existing.lastUnit == unit) continue;
      await db.upsertProduct(existing.copyWith(price: item.price, lastUnit: unit, updatedAt: now));
    } else {
      await db.upsertProduct(Product(
        uuid: _uuid.v4(),
        name: name,
        price: item.price,
        lastUnit: unit,
        createdAt: now,
        updatedAt: now,
      ));
    }
  }
}

/// Seluruh produk di katalog (boleh difilter dengan kata kunci pencarian).
final catalogProductsProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, query) async {
  return DatabaseHelper.instance.listProducts(query: query);
});

final productSuggestionsProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, query) async {
  return DatabaseHelper.instance.searchProducts(query);
});

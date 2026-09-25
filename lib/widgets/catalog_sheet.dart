import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/product.dart';
import '../providers/nota_draft_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

/// Buka katalog produk (bottom sheet) dari layar Nota Baru.
Future<void> showCatalogSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const CatalogSheet(),
  );
}

class CatalogSheet extends ConsumerStatefulWidget {
  const CatalogSheet({super.key});

  @override
  ConsumerState<CatalogSheet> createState() => _CatalogSheetState();
}

class _CatalogSheetState extends ConsumerState<CatalogSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _query = v.trim());
    });
  }

  Future<bool> _confirmDelete(BuildContext context, Product p) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text(
          '"${p.name}" akan dihapus dari katalog. Nota yang sudah tersimpan tidak berubah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _priceLabel(Product p) {
    final unit = (p.lastUnit ?? '').trim();
    return unit.isEmpty ? formatRupiah(p.price) : '${formatRupiah(p.price)} / $unit';
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(notaDraftProvider);
    final productsAsync = ref.watch(catalogProductsProvider(_query));

    // Jumlah tiap barang yang sudah masuk ke nota (kunci: nama huruf kecil).
    final qtyInNota = <String, double>{};
    for (final it in draft.items) {
      final key = it.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      qtyInNota[key] = (qtyInNota[key] ?? 0) + it.qty;
    }

    final inset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: maxHeight,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Cari produk...',
                  prefixIcon: Icon(Icons.search, color: AppColors.slate400),
                  filled: true,
                  fillColor: AppColors.slate50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.slate200),
                  ),
                ),
              ),
            ),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Gagal memuat katalog: $e')),
                data: (products) {
                  if (products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _query.isEmpty
                              ? 'Katalog masih kosong.\nProduk akan muncul otomatis setelah kamu menyimpan nota.'
                              : 'Produk "$_query" tidak ditemukan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.slate500, height: 1.4),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.slate100),
                    itemBuilder: (context, i) {
                      final p = products[i];
                      final qty = qtyInNota[p.name.trim().toLowerCase()] ?? 0;
                      return Dismissible(
                        key: ValueKey('product_${p.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red.shade400,
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        confirmDismiss: (_) => _confirmDelete(context, p),
                        onDismissed: (_) async {
                          await DatabaseHelper.instance.deleteProduct(p.id!);
                          ref.invalidate(catalogProductsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('"${p.name}" dihapus dari katalog')),
                            );
                          }
                        },
                        child: ListTile(
                          onTap: () =>
                              ref.read(notaDraftProvider.notifier).addProductFromCatalog(p),
                          leading: qty > 0
                              ? Container(
                                  constraints: const BoxConstraints(minWidth: 32),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand600,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '×${formatQty(qty)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                )
                              : Icon(Icons.add_circle_outline, color: AppColors.brand600),
                          title: Text(p.name,
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.slate800)),
                          subtitle: Text(_priceLabel(p),
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate500)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Selesai',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

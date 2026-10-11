import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../db/database_helper.dart';
import '../models/product.dart';
import '../providers/nota_draft_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/toast.dart';

/// "Produk Saya": kelola daftar produk, harga, dan satuan.
class ProdukScreen extends ConsumerStatefulWidget {
  const ProdukScreen({super.key});

  @override
  ConsumerState<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends ConsumerState<ProdukScreen> {
  String _query = '';

  Future<void> _showEditor([Product? product]) async {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final priceCtrl = TextEditingController(
        text: (product != null && product.price > 0) ? product.price.round().toString() : '');
    final unitCtrl = TextEditingController(text: product?.lastUnit ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product == null ? 'Tambah Produk' : 'Edit Produk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama produk'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga satuan', prefixText: 'Rp '),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(labelText: 'Satuan (mis. pcs, kg, bks)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );

    final name = nameCtrl.text.trim();
    final price = parseRupiahInput(priceCtrl.text).toDouble();
    final unit = unitCtrl.text.trim();
    nameCtrl.dispose();
    priceCtrl.dispose();
    unitCtrl.dispose();

    if (saved != true) return;
    if (name.isEmpty) {
      showToast('Nama produk tidak boleh kosong.', ToastType.error);
      return;
    }

    final db = DatabaseHelper.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = product ?? await db.findProductByName(name);
    if (existing != null) {
      await db.upsertProduct(existing.copyWith(name: name, price: price, lastUnit: unit, updatedAt: now));
    } else {
      await db.upsertProduct(Product(
        uuid: const Uuid().v4(),
        name: name,
        price: price,
        lastUnit: unit,
        createdAt: now,
        updatedAt: now,
      ));
    }
    ref.invalidate(catalogProductsProvider);
    showToast('Produk disimpan', ToastType.success);
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text('"${p.name}" akan dihapus dari daftar. Nota yang sudah tersimpan tidak berubah.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || p.id == null) return;
    await DatabaseHelper.instance.deleteProduct(p.id!);
    ref.invalidate(catalogProductsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(catalogProductsProvider(_query));

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: const AppHeader(title: 'Produk Saya', showSettings: false),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: AppColors.brand600),
                hintText: 'Cari produk...',
                hintStyle: TextStyle(color: AppColors.slate400),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: AppColors.slate200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: AppColors.slate200)),
              ),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat produk: $e')),
              data: (products) {
                if (products.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: _query.isEmpty ? 'Belum ada produk' : 'Produk tidak ditemukan',
                    description: _query.isEmpty
                        ? 'Tekan "Tambah Produk" atau simpan nota, produk akan tercatat otomatis.'
                        : 'Coba kata kunci lain.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final p = products[i];
                    final unit = (p.lastUnit ?? '').trim();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: ListTile(
                        onTap: () => _showEditor(p),
                        contentPadding: const EdgeInsets.fromLTRB(18, 4, 8, 4),
                        title: Text(p.name,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.slate800)),
                        subtitle: Text(unit.isEmpty ? formatRupiah(p.price) : '${formatRupiah(p.price)} / $unit',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate500)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: AppColors.slate400),
                          onPressed: () => _delete(p),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        backgroundColor: AppColors.brand600,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Tambah Produk', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

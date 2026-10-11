import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/edit_nota_provider.dart';
import '../providers/history_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/kembalian_calculator.dart';
import '../widgets/nota_table.dart';
import '../widgets/toast.dart';
import '../widgets/total_bar.dart';

/// Halaman edit nota. Data dimuat lewat editNotaProvider.load() sebelum halaman dibuka.
/// Saat selesai menyimpan, halaman menutup dan mengembalikan Nota terbaru.
class EditNotaScreen extends ConsumerStatefulWidget {
  const EditNotaScreen({super.key});

  @override
  ConsumerState<EditNotaScreen> createState() => _EditNotaScreenState();
}

class _EditNotaScreenState extends ConsumerState<EditNotaScreen> {
  final TextEditingController _customerCtrl = TextEditingController();
  final Map<String, FocusNode> _nameFocusNodes = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _customerCtrl.text = ref.read(editNotaProvider).customerName;
  }

  FocusNode _nameFocusNodeFor(String id) => _nameFocusNodes.putIfAbsent(id, () => FocusNode());

  @override
  void dispose() {
    _customerCtrl.dispose();
    for (final node in _nameFocusNodes.values) {
      node.dispose();
    }
    _nameFocusNodes.clear();
    super.dispose();
  }

  Future<void> _save({bool reprint = false}) async {
    setState(() => _busy = true);
    try {
      ref.read(editNotaProvider.notifier).setCustomerName(_customerCtrl.text);
      final updated = await ref.read(editNotaProvider.notifier).saveChanges();
      ref.read(historyRefreshProvider.notifier).state++;
      if (reprint) {
        final settings = ref.read(settingsProvider).value;
        if (settings != null) {
          final ok = await ref.read(printerProvider.notifier).print(updated, settings);
          showToast(ok ? 'Perubahan disimpan & nota dicetak ulang' : 'Perubahan disimpan, tapi gagal mencetak',
              ok ? ToastType.success : ToastType.error);
        }
      } else {
        showToast('Perubahan nota disimpan', ToastType.success);
      }
      if (mounted) Navigator.of(context).pop(updated);
    } catch (err) {
      showToast(err.toString().replaceFirst('Exception: ', ''), ToastType.error);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(editNotaProvider);
    final notifier = ref.read(editNotaProvider.notifier);
    final isQris = editState.original?.paymentMethod == 'qris';

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: const AppHeader(title: 'Edit Nota', showSettings: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Ubah qty, harga, atau tambah baris baru kalau pelanggan minta tambahan belanja. Nomor nota & tanggal asli tidak berubah.',
              style: TextStyle(fontSize: 12, color: AppColors.slate400)),
          const SizedBox(height: 12),
          Text('Nama Pembeli',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate600)),
          const SizedBox(height: 4),
          TextField(
            controller: _customerCtrl,
            decoration: InputDecoration(
              hintText: 'Contoh: Bu Siti',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          NotaTable(
            items: editState.items,
            onUpdateItem: (id, {name, price, qty, unit, totalOverride, clearOverride = false}) => notifier
                .updateItem(id, name: name, price: price, qty: qty, unit: unit, totalOverride: totalOverride, clearOverride: clearOverride),
            onRemoveItem: (id) {
              notifier.removeItem(id);
              _nameFocusNodes.remove(id)?.dispose();
            },
            onAddRow: notifier.addRow,
            onEnterName: (_) {},
            nameFocusNode: _nameFocusNodeFor,
            onEnterQty: (id, isLast) {
              if (isLast) notifier.ensureTrailingRow();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final items = ref.read(editNotaProvider).items;
                final idx = items.indexWhere((it) => it.id == id);
                if (idx >= 0 && idx + 1 < items.length) {
                  _nameFocusNodeFor(items[idx + 1].id).requestFocus();
                }
              });
            },
          ),
          const SizedBox(height: 12),
          TotalBar(total: editState.total),
          if (!isQris) ...[
            const SizedBox(height: 12),
            KembalianCalculator(
              total: editState.total,
              receivedText: editState.receivedText,
              onReceivedTextChange: notifier.setReceivedText,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _save(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.slate100,
                    foregroundColor: AppColors.slate700,
                  ),
                  child: const Text('Simpan'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _save(reprint: true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.brand600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Simpan & Cetak'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

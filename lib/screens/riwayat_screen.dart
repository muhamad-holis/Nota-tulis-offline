import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/nota.dart';
import '../providers/history_provider.dart';
import '../providers/edit_nota_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/printer_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/history_item.dart';
import '../widgets/receipt_preview.dart';
import '../widgets/nota_table.dart';
import '../widgets/total_bar.dart';
import '../widgets/toast.dart';

class RiwayatScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenSettings;
  const RiwayatScreen({super.key, required this.onOpenSettings});

  @override
  ConsumerState<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends ConsumerState<RiwayatScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = DateTime(picked.year, picked.month, picked.day);
        ref.read(historyFilterProvider.notifier).setDateFrom(_dateFrom!.millisecondsSinceEpoch);
      } else {
        _dateTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        ref.read(historyFilterProvider.notifier).setDateTo(_dateTo!.millisecondsSinceEpoch);
      }
    });
  }

  void _openNota(Nota nota) {
    ref.read(editNotaProvider.notifier).load(nota);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotaDetailSheet(initialNota: nota),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notasAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppHeader(title: 'Riwayat', onSettingsTap: widget.onOpenSettings),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Cari nomor nota atau barang...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.slate200)),
                  ),
                  onChanged: (v) => ref.read(historyFilterProvider.notifier).setSearch(v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _dateButton('Dari Tanggal', _dateFrom, () => _pickDate(isFrom: true))),
                    const SizedBox(width: 8),
                    Expanded(child: _dateButton('Sampai Tanggal', _dateTo, () => _pickDate(isFrom: false))),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: notasAsync.when(
              data: (notas) => notas.isEmpty
                  ? const EmptyState(
                      icon: Icons.history,
                      title: 'Belum ada riwayat nota',
                      description: 'Nota yang disimpan akan muncul di sini.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.slate100),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Column(
                            children: [
                              for (final n in notas) HistoryItem(nota: n, onTap: () => _openNota(n)),
                            ],
                          ),
                        ),
                      ],
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat riwayat: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateButton(String label, DateTime? value, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.slate600,
        side: BorderSide(color: AppColors.slate200),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(
        value == null ? label : '${value.day}/${value.month}/${value.year}',
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _NotaDetailSheet extends ConsumerStatefulWidget {
  final Nota initialNota;
  const _NotaDetailSheet({required this.initialNota});

  @override
  ConsumerState<_NotaDetailSheet> createState() => _NotaDetailSheetState();
}

class _NotaDetailSheetState extends ConsumerState<_NotaDetailSheet> {
  bool _editMode = false;
  bool _busy = false;
  final TextEditingController _customerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customerCtrl.text = widget.initialNota.customerName ?? '';
  }

  Future<void> _delete() async {
    if (widget.initialNota.id == null) return;
    await deleteNotaAndRefresh(ref, widget.initialNota.id!);
    if (mounted) {
      Navigator.of(context).pop();
      showToast('Nota dihapus dari riwayat', ToastType.info);
    }
  }

  Future<void> _reprint(Nota nota) async {
    final settings = ref.read(settingsProvider).value;
    if (settings == null) return;
    final ok = await ref.read(printerProvider.notifier).print(nota, settings);
    showToast(ok ? 'Nota berhasil dicetak ulang' : 'Gagal mencetak nota', ok ? ToastType.success : ToastType.error);
  }

  Future<void> _saveEdit({bool reprint = false}) async {
    setState(() => _busy = true);
    try {
      ref.read(editNotaProvider.notifier).setCustomerName(_customerCtrl.text);
      final updated = await ref.read(editNotaProvider.notifier).saveChanges();
      ref.read(historyRefreshProvider.notifier).state++;
      setState(() => _editMode = false);
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
    } catch (err) {
      showToast(err.toString(), ToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(editNotaProvider);
    final settings = ref.watch(settingsProvider).value;
    final currentNota = editState.original ?? widget.initialNota;
    final printerUi = ref.watch(printerProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_editMode ? 'Edit ${currentNota.number}' : currentNota.number,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (!_editMode && settings != null) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ReceiptPreview(nota: currentNota, settings: settings),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _delete,
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              child: const Column(children: [Icon(Icons.delete_outline, size: 16), Text('Hapus', style: TextStyle(fontSize: 12))]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _editMode = true),
                              child: const Column(children: [Icon(Icons.edit_outlined, size: 16), Text('Edit / Tambah', style: TextStyle(fontSize: 12))]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: printerUi.printing ? null : () => _reprint(currentNota),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand600, foregroundColor: Colors.white),
                              child: const Column(children: [Icon(Icons.print_outlined, size: 16), Text('Cetak Ulang', style: TextStyle(fontSize: 12))]),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_editMode) ...[
                      Text(
                        'Ubah qty, harga, atau tambah baris baru kalau pelanggan minta tambahan belanja. Nomor nota & tanggal asli tidak berubah.',
                        style: TextStyle(fontSize: 12, color: AppColors.slate400),
                      ),
                      const SizedBox(height: 12),
                      Text('Nama Pelanggan (opsional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate600)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _customerCtrl,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Bu Siti',
                          filled: true,
                          fillColor: AppColors.slate50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      NotaTable(
                        items: editState.items,
                        onUpdateItem: (id, {name, price, qty, totalOverride, clearOverride = false}) => ref
                            .read(editNotaProvider.notifier)
                            .updateItem(id, name: name, price: price, qty: qty, totalOverride: totalOverride, clearOverride: clearOverride),
                        onRemoveItem: (id) => ref.read(editNotaProvider.notifier).removeItem(id),
                        onAddRow: () => ref.read(editNotaProvider.notifier).addRow(),
                        onEnterName: (_) {},
                        onEnterQty: (id, isLast) {
                          if (isLast) ref.read(editNotaProvider.notifier).ensureTrailingRow();
                        },
                      ),
                      const SizedBox(height: 12),
                      TotalBar(total: editState.total),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : () => setState(() => _editMode = false),
                              child: const Column(children: [Icon(Icons.close, size: 16), Text('Batal', style: TextStyle(fontSize: 12))]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _busy ? null : () => _saveEdit(),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate100, foregroundColor: AppColors.slate700),
                              child: const Column(children: [Icon(Icons.save_outlined, size: 16), Text('Simpan', style: TextStyle(fontSize: 12))]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _busy ? null : () => _saveEdit(reprint: true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand600, foregroundColor: Colors.white),
                              child: const Column(children: [Icon(Icons.print_outlined, size: 16), Text('Simpan & Cetak', style: TextStyle(fontSize: 12))]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

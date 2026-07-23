import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/nota_draft_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/history_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_header.dart';
import '../widgets/nota_table.dart';
import '../widgets/total_bar.dart';
import '../widgets/kembalian_calculator.dart';
import '../widgets/action_buttons.dart';
import '../widgets/toast.dart';

class NotaScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenSettings;
  const NotaScreen({super.key, required this.onOpenSettings});

  @override
  ConsumerState<NotaScreen> createState() => _NotaScreenState();
}

class _NotaScreenState extends ConsumerState<NotaScreen> {
  final TextEditingController _customerCtrl = TextEditingController();
  final Map<String, FocusNode> _nameFocusNodes = {};
  String _receivedText = '';
  bool _saving = false;
  bool _busy = false;

  FocusNode _nameFocusNodeFor(String id) =>
      _nameFocusNodes.putIfAbsent(id, () => FocusNode());

  @override
  void dispose() {
    _customerCtrl.dispose();
    for (final node in _nameFocusNodes.values) {
      node.dispose();
    }
    _nameFocusNodes.clear();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_busy) return;
    _busy = true;
    setState(() => _saving = true);
    try {
      await ref.read(notaDraftProvider.notifier).saveNota(bayarTunai: parseRupiahInput(_receivedText).toDouble());
      ref.read(historyRefreshProvider.notifier).state++;
      showToast('Nota berhasil disimpan', ToastType.success);
      ref.read(notaDraftProvider.notifier).reset();
      _customerCtrl.clear();
      _clearNameFocusNodes();
      setState(() => _receivedText = '');
    } catch (err) {
      showToast(err.toString(), ToastType.error);
    } finally {
      setState(() => _saving = false);
      _busy = false;
    }
  }

  Future<void> _handlePrint() async {
    final settingsAsync = ref.read(settingsProvider);
    final settings = settingsAsync.value;
    if (settings == null) return;
    if (_busy) return;
    _busy = true;
    try {
      final saved = await ref.read(notaDraftProvider.notifier).saveNota(
            bayarTunai: parseRupiahInput(_receivedText).toDouble(),
          );
      ref.read(historyRefreshProvider.notifier).state++;
      final ok = await ref.read(printerProvider.notifier).print(saved, settings);
      if (ok) {
        showToast('Nota berhasil dicetak', ToastType.success);
        ref.read(notaDraftProvider.notifier).reset();
        _customerCtrl.clear();
        _clearNameFocusNodes();
        setState(() => _receivedText = '');
      } else {
        showToast('Gagal mencetak. Cek koneksi printer.', ToastType.error);
      }
    } catch (err) {
      showToast(err.toString(), ToastType.error);
    } finally {
      _busy = false;
    }
  }

  void _handleNewNota() {
    ref.read(notaDraftProvider.notifier).reset();
    _customerCtrl.clear();
    _clearNameFocusNodes();
    setState(() => _receivedText = '');
    showToast('Nota baru dibuat', ToastType.info);
  }

  void _clearNameFocusNodes() {
    for (final node in _nameFocusNodes.values) {
      node.dispose();
    }
    _nameFocusNodes.clear();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(notaDraftProvider);
    final printerUi = ref.watch(printerProvider);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppHeader(title: 'Nota Tulis', onSettingsTap: widget.onOpenSettings),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                Text('Nama Pelanggan (opsional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate600)),
                const SizedBox(height: 4),
                TextField(
                  controller: _customerCtrl,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Bu Siti',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.slate200)),
                  ),
                  onChanged: (v) => ref.read(notaDraftProvider.notifier).setCustomerName(v),
                ),
                const SizedBox(height: 16),
                NotaTable(
                  items: draft.items,
                  onUpdateItem: (id, {name, price, qty, totalOverride, clearOverride = false}) => ref
                      .read(notaDraftProvider.notifier)
                      .updateItem(id, name: name, price: price, qty: qty, totalOverride: totalOverride, clearOverride: clearOverride),
                  onRemoveItem: (id) {
                    ref.read(notaDraftProvider.notifier).removeItem(id);
                    _nameFocusNodes.remove(id)?.dispose();
                  },
                  onAddRow: () => ref.read(notaDraftProvider.notifier).addRow(),
                  onEnterName: (_) {},
                  nameFocusNode: _nameFocusNodeFor,
                  onEnterQty: (id, isLast) {
                    final notifier = ref.read(notaDraftProvider.notifier);
                    if (isLast) notifier.ensureTrailingRow();
                    // Pindah fokus ke kolom "Nama Barang" pada baris berikutnya,
                    // langsung setelah frame ini selesai (baris baru sudah ada di tree).
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      final items = ref.read(notaDraftProvider).items;
                      final idx = items.indexWhere((it) => it.id == id);
                      if (idx >= 0 && idx + 1 < items.length) {
                        _nameFocusNodeFor(items[idx + 1].id).requestFocus();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                TotalBar(total: draft.total),
                const SizedBox(height: 16),
                KembalianCalculator(
                  total: draft.total,
                  receivedText: _receivedText,
                  onReceivedTextChange: (v) => setState(() => _receivedText = v),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: AppColors.slate50.withOpacity(0.95),
              border: Border(top: BorderSide(color: AppColors.slate100)),
            ),
            child: ActionButtons(
              onSave: _handleSave,
              onPrint: _handlePrint,
              onNewNota: _handleNewNota,
              saving: _saving || printerUi.printing,
              printing: printerUi.printing || _saving,
            ),
          ),
        ],
      ),
    );
  }
}
